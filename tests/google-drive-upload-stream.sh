#!/bin/sh
set -eu

root=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
temporary=$(mktemp -d)
trap 'rm -rf "$temporary"' EXIT HUP INT TERM
fake_bin=$temporary/bin
mkdir -p "$fake_bin"

cat > "$fake_bin/source" <<'EOF_SOURCE'
#!/bin/sh
set -eu
offset=$GOOGLE_DRIVE_SOURCE_OFFSET
length=$GOOGLE_DRIVE_SOURCE_LENGTH
printf 'source\t%s\t%s\t%s\n' "$FAKE_SOURCE_MODE" "$offset" "$length" >> "$FAKE_LOG"
if [ "$FAKE_SOURCE_MODE" = short ]; then length=$((length - 1)); fi
if [ "$length" -gt 0 ]; then dd if=/dev/zero bs=1 count="$length" status=none; fi
EOF_SOURCE
chmod +x "$fake_bin/source"

cat > "$fake_bin/curl" <<'EOF_CURL'
#!/bin/sh
set -eu
scenario=$FAKE_SCENARIO
state=$FAKE_STATE
log=$FAKE_LOG
total=$FAKE_TOTAL
request=GET
url=
headers_file=
output_file=
content_range=
while [ "$#" -gt 0 ]; do
    case $1 in
        --request) request=$2; shift 2 ;;
        --dump-header) headers_file=$2; shift 2 ;;
        --output) output_file=$2; shift 2 ;;
        --header)
            case $2 in
                Content-Range:*) content_range=$(printf '%s\n' "$2" | sed 's/^Content-Range: //') ;;
            esac
            shift 2
            ;;
        *) url=$1; shift ;;
    esac
done
printf '%s\t%s\t%s\n' "$request" "$url" "$content_range" >> "$log"
[ -z "$headers_file" ] || : > "$headers_file"
[ -z "$output_file" ] || : > "$output_file"
write_response() {
    [ -z "$headers_file" ] || printf 'HTTP/1.1 %s\r\n\r\n' "$1" > "$headers_file"
}

case $url in
    *uploadType=resumable*)
        printf 'HTTP/1.1 200 OK\r\nLocation: https://upload.example/session/TEST\r\n\r\n' > "$headers_file"
        exit 0 ;;
    *'/drive/v3/files/OBJ'*)
        write_response 200
        case $scenario in final-size-mismatch) size=999 ;; *) size=$total ;; esac
        checksum=$FAKE_SHA256
        [ "$scenario" = final-checksum-missing ] && checksum=
        [ "$scenario" = final-checksum-mismatch ] && checksum=0000000000000000000000000000000000000000000000000000000000000000
        if [ -n "$checksum" ]; then
            printf '{"id":"OBJ","name":"archive","size":"%s","sha256Checksum":"%s"}\n' "$size" "$checksum" > "$output_file"
        else
            printf '{"id":"OBJ","name":"archive","size":"%s"}\n' "$size" > "$output_file"
        fi
        exit 0 ;;
esac

if [ "$content_range" = "bytes */$total" ]; then
    if [ "$scenario" = zero ]; then
        write_response 200
        printf '{"id":"OBJ"}\n' > "$output_file"
        exit 0
    fi
    if [ "$scenario" = session-expired ]; then write_response 410; exit 0; fi
    if [ "$scenario" = interrupt-before-commit ] && [ ! -e "$state" ]; then : > "$state"; exit 7; fi
    acknowledged=$(sed -n 's/^ack=//p' "$state" | tail -n 1)
    write_response 308
    if [ -n "$acknowledged" ] && [ "$acknowledged" != 0 ]; then
        printf 'Range: bytes=0-%s\r\n' "$((acknowledged - 1))" >> "$headers_file"
    fi
    exit 0
fi

case $scenario in
    malformed-range) write_response 308; printf 'Range: bytes=bad\r\n' >> "$headers_file"; exit 0 ;;
    noncontiguous-range) write_response 308; printf 'Range: bytes=0-524288\r\n' >> "$headers_file"; exit 0 ;;
esac

if [ "$request" = PUT ]; then
    if [ "$scenario" = session-expired ]; then
        write_response 410
        exit 0
    fi
    case $scenario in
        interrupt-before-commit)
            if [ ! -e "$state" ]; then : > "$state"; exit 7; fi ;;
        lost-response-after-commit)
            if ! grep -F committed "$state" >/dev/null 2>&1; then printf 'ack=4\ncommitted\n' > "$state"; exit 7; fi ;;
        fewer-ack)
            if ! grep -F partial "$state" >/dev/null 2>&1; then
                printf 'partial\n' > "$state"; write_response 308
                printf 'Range: bytes=0-3\r\n' >> "$headers_file"; exit 0
            fi ;;
    esac
    if [ "$scenario" = zero ]; then write_response 200; printf '{"id":"OBJ"}\n' > "$output_file"; exit 0; fi
    range_count=$(grep -c 'bytes ' "$log" || true)
    if [ "$total" -gt 524288 ] && [ "$range_count" -eq 1 ]; then
        write_response 308; printf 'Range: bytes=0-524287\r\n' >> "$headers_file"; exit 0
    fi
    write_response 200; printf '{"id":"OBJ"}\n' > "$output_file"; exit 0
fi
exit 90
EOF_CURL
chmod +x "$fake_bin/curl"

metadata=$temporary/metadata.json
printf '%s\n' '{"name":"archive"}' > "$metadata"
client=$root/commands/google-drive-api.grease
producer=$fake_bin/source
helper=${GOOGLE_DRIVE_UPLOAD_STATE:-/tmp/google-drive-upload-state}
runner=${GREASE:-sh}

run_upload() {
    scenario=$1
    total=$2
    state=$temporary/$scenario.state
    log=$temporary/$scenario.log
    session=$temporary/$scenario.session
    receipt=$temporary/$scenario.receipt
    source_mode=${FAKE_SOURCE_MODE:-normal}
    [ "$scenario" = short ] && source_mode=short
    FAKE_SCENARIO=$scenario FAKE_TOTAL=$total FAKE_STATE=$state FAKE_LOG=$log \
    FAKE_SHA256=$(dd if=/dev/zero bs=1 count="$total" 2>/dev/null | sha256sum | cut -d ' ' -f 1) \
    FAKE_SOURCE_MODE=$source_mode PATH=$fake_bin:$PATH GOOGLE_ACCESS_TOKEN=token GOOGLE_DRIVE_UPLOAD_STATE=$helper \
        "$runner" "$client" files.create --body "$metadata" --source-program "$producer" \
        --media-size "$total" --chunk-size 524288 --session-file "$session" \
        --receipt-file "$receipt"
}

run_upload zero 0 >/dev/null
run_upload one-partial 700000 >/dev/null
[ "$(grep -c 'bytes ' "$temporary/one-partial.log")" -ge 2 ]
before_rerun=$(wc -l < "$temporary/one-partial.log")
run_upload one-partial 700000 >/dev/null
[ "$(wc -l < "$temporary/one-partial.log")" = "$before_rerun" ]

if run_upload malformed-range 700000 >/dev/null 2>&1; then
    printf '%s\n' 'malformed range unexpectedly passed' >&2
    exit 1
fi
if run_upload noncontiguous-range 700000 >/dev/null 2>&1; then
    printf '%s\n' 'noncontiguous range unexpectedly passed' >&2
    exit 1
fi
for scenario in session-expired final-size-mismatch final-checksum-mismatch final-checksum-missing; do
    if run_upload "$scenario" 700000 >/dev/null 2>&1; then
        printf 'scenario unexpectedly passed: %s\n' "$scenario" >&2
        exit 1
    fi
done
if run_upload short 700000 >/dev/null 2>&1; then
    printf '%s\n' 'short source unexpectedly passed' >&2
    exit 1
fi

if FAKE_SCENARIO=interrupt-before-commit FAKE_TOTAL=700000 FAKE_SHA256= FAKE_STATE="$temporary/before.state" FAKE_LOG="$temporary/before.log" FAKE_SOURCE_MODE=normal \
PATH=$fake_bin:$PATH GOOGLE_ACCESS_TOKEN=token GOOGLE_DRIVE_UPLOAD_STATE=$helper \
    "$runner" "$client" files.create --body "$metadata" --source-program "$producer" --media-size 700000 \
    --chunk-size 524288 --session-file "$temporary/before.session" --receipt-file "$temporary/before.receipt" >/dev/null 2>&1; then exit 1; fi
[ -f "$temporary/before.session" ]
run_upload interrupt-before-commit 700000 >/dev/null
run_upload lost-response-after-commit 700000 >/dev/null
run_upload fewer-ack 700000 >/dev/null

big_plan=$($helper plan 4294967297 4294967296 67108864)
printf '%s\n' "$big_plan" | grep -F '4294967296' >/dev/null
printf '%s\n' 'google-drive resumable stream deterministic contract passes'
trap - EXIT HUP INT TERM
rm -rf "$temporary"
exit 0
