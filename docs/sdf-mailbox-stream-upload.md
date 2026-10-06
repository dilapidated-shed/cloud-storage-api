# SDF mailbox stream upload

This workflow archives the raw SDF mbox as one ordinary Google Drive file:

SDF → system OpenSSH → bounded remote byte range → Drive resumable upload

It does not parse mbox or MIME, and it does not materialize the complete mailbox
on the phone or SD card.

## Authorization

Use a private credential with the narrow write scope needed by this client:

https://www.googleapis.com/auth/drive.readonly
https://www.googleapis.com/auth/drive.file

The repository auth command accepts --stream-upload for this scope set. The
existing read-only credential cannot create the archive.

## Termux invocation

This is a command interface description, not a prepared mobile paste procedure.
Cat Food issue 117 must deliver the commands and qualified fixed-width helpers;
Kitchen owns the target-verified procedure. Set GOOGLE_DRIVE_CREDENTIAL_FILE to
the mode-0600 credential and GREASE to the exact installed Grease runtime. A
phone source checkout and phone compilation are not prerequisites.

GREASE=/absolute/path/to/grease
GOOGLE_DRIVE_CREDENTIAL_FILE=/absolute/private/google-drive.credentials
GOOGLE_DRIVE_UPLOAD_STATE=/absolute/path/to/google-drive-upload-state
export GREASE GOOGLE_DRIVE_CREDENTIAL_FILE GOOGLE_DRIVE_UPLOAD_STATE
"$GREASE" /absolute/path/to/installed/sdf-mailbox-stream-upload.grease \
  --session-file /absolute/private/sdf-mailbox.upload.session \
  --receipt-file /absolute/private/sdf-mailbox.archive.receipt \
  --name sdf-mailbox-archive

The command uses isomorphisms@tty.sdf.org:/var/mail/isomorphisms by default and
requires OpenSSH batch/public-key authentication. It captures T before upload,
permits later appends beyond T, and rejects a replaced or shortened source. The
session file contains the bearer-capability URI and must remain mode 0600;
diagnostics and receipts do not print or copy that URI.

The final receipt records the source identity and length, archival start time,
Drive session-file location, requested destination name/parent, object ID/name,
destination size, source SHA-256 and provider SHA-256. Completion requires exact
size and a matching provider SHA-256. A missing checksum refuses exact-byte
acceptance. Before cached completion is returned, the command checks source,
destination, session and chunk identity. A legacy receipt missing these fields
requires explicit reconciliation and is not silently accepted.

No command in this repository starts the 4.4-GB transfer merely because the
fake transport tests pass. Physical SDF access and live Drive write acceptance
must be exercised separately.

The current sidecar helper synchronizes session/receipt bytes and their parent
directory before publication. Source device/inode/length checks run before and
after each bounded range. They do not qualify SDF cluster-node continuity or a
delivery-lock/frozen generation protocol. Pre/post hashes and the provider digest
do not prevent a same-inode edit-and-restore race. Actual source behavior remains
a live gate. mbox occurrence parsing and SPEC-LIST refiling consume a retained
generation later and never authorize archival source mutation.
