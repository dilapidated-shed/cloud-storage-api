/*
 * Fixed-width arithmetic and response validation for resumable uploads.
 * Grease owns Drive HTTP and source orchestration; this helper owns offsets
 * that must remain correct on 32-bit hosts.
 */
#define _FILE_OFFSET_BITS 64
#define _POSIX_C_SOURCE 200809L

#include <errno.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <unistd.h>

static void die(const char *message) {
    fprintf(stderr, "%s\n", message);
    exit(2);
}

static uint64_t parse_u64(const char *text, const char *name) {
    if (!*text) {
        fprintf(stderr, "invalid %s: %s\n", name, text);
        exit(2);
    }
    for (const unsigned char *p = (const unsigned char *)text; *p; ++p) {
        if (*p < '0' || *p > '9') {
            fprintf(stderr, "invalid %s: %s\n", name, text);
            exit(2);
        }
    }
    errno = 0;
    char *end = NULL;
    unsigned long long value = strtoull(text, &end, 10);
    if (errno || !end || *end || value > UINT64_MAX) {
        fprintf(stderr, "invalid %s: %s\n", name, text);
        exit(2);
    }
    return (uint64_t)value;
}

static uint64_t checked_add(uint64_t left, uint64_t right, const char *what) {
    if (right > UINT64_MAX - left) die(what);
    return left + right;
}

static uint64_t parse_range_end(const char *range) {
    static const char prefix[] = "bytes=0-";
    size_t prefix_length = sizeof(prefix) - 1;
    if (strncmp(range, prefix, prefix_length) != 0)
        die("Range must be bytes=0-END");
    return parse_u64(range + prefix_length, "Range end");
}

static void command_plan(int argc, char **argv) {
    if (argc != 5) die("usage: google-drive-upload-state plan TOTAL OFFSET CHUNK_SIZE");
    uint64_t total = parse_u64(argv[2], "total size");
    uint64_t offset = parse_u64(argv[3], "offset");
    uint64_t chunk = parse_u64(argv[4], "chunk size");
    if (!chunk) die("chunk size must be positive");
    if (offset > total) die("offset exceeds total size");
    if (offset == total) {
        puts("complete");
        return;
    }
    uint64_t remaining = total - offset;
    uint64_t length = remaining < chunk ? remaining : chunk;
    uint64_t end = checked_add(offset, length - 1, "upload range overflows 64 bits");
    uint64_t next = checked_add(end, 1, "next upload offset overflows 64 bits");
    printf("range\t%llu\t%llu\t%llu\t%llu\n",
           (unsigned long long)offset,
           (unsigned long long)end,
           (unsigned long long)length,
           (unsigned long long)next);
}

static void command_next(int argc, char **argv) {
    if (argc != 3) die("usage: google-drive-upload-state next END");
    uint64_t end = parse_u64(argv[2], "range end");
    printf("%llu\n", (unsigned long long)checked_add(
        end, 1, "next upload offset overflows 64 bits"));
}

static void command_ack(int argc, char **argv) {
    if (argc != 4) die("usage: google-drive-upload-state ack TOTAL RANGE");
    uint64_t total = parse_u64(argv[2], "total size");
    uint64_t end = parse_range_end(argv[3]);
    if (end >= total && total != 0) die("provider Range exceeds total size");
    if (total == 0) die("a zero-byte upload cannot acknowledge a Range");
    printf("%llu\n", (unsigned long long)checked_add(
        end, 1, "acknowledged byte count overflows 64 bits"));
}

static void command_bounds(int argc, char **argv) {
    if (argc != 5)
        die("usage: google-drive-upload-state bounds ACKNOWLEDGED START END");
    uint64_t acknowledged = parse_u64(argv[2], "acknowledged byte count");
    uint64_t start = parse_u64(argv[3], "attempted start");
    uint64_t end = parse_u64(argv[4], "attempted end");
    if (acknowledged < start)
        die("provider acknowledged a noncontiguous range before this chunk");
    if (end != UINT64_MAX && acknowledged > end + 1)
        die("provider acknowledged bytes beyond the attempted chunk");
    puts("ok");
}

static void command_source_plan(int argc, char **argv) {
    if (argc != 5)
        die("usage: google-drive-upload-state source-plan OFFSET LENGTH BLOCK_SIZE");
    uint64_t offset = parse_u64(argv[2], "source offset");
    uint64_t length = parse_u64(argv[3], "source length");
    uint64_t block_size = parse_u64(argv[4], "source block size");
    if (!length) die("source length must be positive");
    if (!block_size) die("source block size must be positive");
    uint64_t within = offset % block_size;
    uint64_t block_start = offset / block_size;
    uint64_t needed = checked_add(within, length, "source range overflows 64 bits");
    uint64_t blocks = (needed - 1) / block_size + 1;
    printf("%llu\t%llu\t%llu\n",
           (unsigned long long)block_start,
           (unsigned long long)within,
           (unsigned long long)blocks);
}

static void command_size(int argc, char **argv) {
    if (argc != 3) die("usage: google-drive-upload-state size FILE");
    struct stat status;
    if (stat(argv[2], &status) != 0) {
        perror(argv[2]);
        exit(2);
    }
    if (status.st_size < 0) die("file has a negative size");
    printf("%llu\n", (unsigned long long)(uint64_t)status.st_size);
}

/* Commit a private sidecar after its bytes, then its containing directory,
 * have been synchronized. The caller writes the temporary beside DEST. */
static void command_commit(int argc, char **argv) {
    if (argc != 4) die("usage: google-drive-upload-state commit TEMP DEST");
    char *parent = strdup(argv[3]);
    if (!parent) die("out of memory");
    char *slash = strrchr(parent, '/');
    if (!slash) strcpy(parent, ".");
    else if (slash == parent) slash[1] = '\0';
    else *slash = '\0';
    int directory = open(parent, O_RDONLY);
    if (directory < 0) die("cannot open sidecar directory");
    int file = open(argv[2], O_RDONLY);
    if (file < 0 || fsync(file) != 0) die("cannot synchronize sidecar bytes");
    if (close(file) != 0 || rename(argv[2], argv[3]) != 0)
        die("cannot publish sidecar");
    if (fsync(directory) != 0 || close(directory) != 0)
        die("cannot synchronize sidecar directory");
    free(parent);
}

int main(int argc, char **argv) {
    if (argc < 2)
        die("usage: google-drive-upload-state plan|next|ack|bounds|source-plan|size ...");
    if (strcmp(argv[1], "plan") == 0) command_plan(argc, argv);
    else if (strcmp(argv[1], "next") == 0) command_next(argc, argv);
    else if (strcmp(argv[1], "ack") == 0) command_ack(argc, argv);
    else if (strcmp(argv[1], "bounds") == 0) command_bounds(argc, argv);
    else if (strcmp(argv[1], "source-plan") == 0) command_source_plan(argc, argv);
    else if (strcmp(argv[1], "size") == 0) command_size(argc, argv);
    else if (strcmp(argv[1], "commit") == 0) command_commit(argc, argv);
    else die("unknown google-drive-upload-state action");
    return 0;
}
