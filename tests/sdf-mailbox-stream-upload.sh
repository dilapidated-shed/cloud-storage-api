#!/bin/sh
set -eu

root=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
temporary=$(mktemp -d)
trap 'rm -rf "$temporary"' EXIT HUP INT TERM
fake_bin=$temporary/bin
mkdir -p "$fake_bin"

cat > "$fake_bin/ssh" <<'EOF_SSH'
#!/bin/sh
set -eu
state=$FAKE_SDF_STATE
if [ "$#" -ge 4 ] && [ "$4" = stat ]; then
    case $state in
        append) printf '%s\n' '7 11 1000100' ;;
        shorter) printf '%s\n' '7 11 999999' ;;
        replaced) printf '%s\n' '7 12 1000000' ;;
        *) printf '%s\n' '7 11 1000000' ;;
    esac
    exit 0
fi
if [ "$#" -ge 4 ] && [ "$4" = test ]; then exit 0; fi
command=$4
length=$(printf '%s\n' "$command" | sed -n 's/.*dd bs=1 skip=[0-9][0-9]* count=\([0-9][0-9]*\).*/\1/p')
if [ -z "$length" ]; then exit 2; fi
dd if=/dev/zero bs=1 count="$length" status=none
EOF_SSH
chmod +x "$fake_bin/ssh"

producer=$root/commands/sdf-mailbox-range.grease
helper=${GOOGLE_DRIVE_UPLOAD_STATE:-/tmp/google-drive-upload-state}
runner=${GREASE:-sh}
run_range() {
    state=$1
    FAKE_SDF_STATE=$state PATH=$fake_bin:$PATH GOOGLE_DRIVE_UPLOAD_STATE=$helper \
    SDF_MAILBOX_TARGET=isomorphisms@tty.sdf.org SDF_MAILBOX_PATH=/var/mail/isomorphisms \
    SDF_MAILBOX_DEVICE=7 SDF_MAILBOX_INODE=11 GOOGLE_DRIVE_SOURCE_TOTAL=1000000 \
    GOOGLE_DRIVE_SOURCE_OFFSET=524288 GOOGLE_DRIVE_SOURCE_LENGTH=262144 \
        "$runner" "$producer" >/dev/null
}
run_range exact
run_range append
if run_range shorter; then exit 1; fi
if run_range replaced; then exit 1; fi
printf '%s\n' 'SDF bounded source-generation contract passes'
