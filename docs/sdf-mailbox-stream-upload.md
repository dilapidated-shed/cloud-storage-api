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

Set GOOGLE_DRIVE_CREDENTIAL_FILE to the mode-0600 credential and set GREASE to
the exact Grease/Osh executable on the phone. Then run from the checked-out
repository, with explicit durable paths for the session and receipt:

GREASE=/absolute/path/to/grease/bin/osh
GOOGLE_DRIVE_CREDENTIAL_FILE=/absolute/private/google-drive.credentials
GOOGLE_DRIVE_UPLOAD_STATE=/absolute/path/to/google-drive-upload-state
export GREASE GOOGLE_DRIVE_CREDENTIAL_FILE GOOGLE_DRIVE_UPLOAD_STATE
"$GREASE" /absolute/path/to/cloud-storage-api/commands/sdf-mailbox-stream-upload.grease \
  --session-file /absolute/private/sdf-mailbox.upload.session \
  --receipt-file /absolute/private/sdf-mailbox.archive.receipt \
  --name sdf-mailbox-archive

The command uses isomorphisms@tty.sdf.org:/var/mail/isomorphisms by default and
requires OpenSSH batch/public-key authentication. It captures T before upload,
permits later appends beyond T, and rejects a replaced or shortened source. The
session file contains the bearer-capability URI and must remain mode 0600;
diagnostics and receipts do not print or copy that URI.

The final receipt records the source identity and length, archival start time,
Drive session-file location, object ID/name, destination size, source SHA-256,
and provider SHA-256 when Drive supplies one. Completion means Drive returned
completed object metadata, exact destination size matched T, and the SHA-256
comparison succeeded. A missing provider SHA-256 leaves the transfer
unverified and retains the session; it cannot produce COMPLETE_AND_VERIFIED.
Session and receipt publication synchronize the file and containing directory.

The source contract requires an append-only or independently frozen source
generation. Device/inode/length checks run before and after each range; a final
full bounded hash pass compares the source to the provider checksum. These
checks detect observed replacement, truncation and persistent prefix edits.
They do not establish an SDF delivery-lock protocol or prevent an adversarial
same-inode edit-and-restore race. Qualifying the real source's generation/lock
behavior remains a live gate. Appends beyond T are allowed. Neither raw archival
nor that gate requires mbox parsing, SPEC-LIST filing, or source mutation.

The independent filing work in `isomorphisms/mbox` consumes retained byte
generations later. Its parser/move receipts do not qualify this SSH/Drive path,
and an archival receipt never authorizes refiling or deletion.

No command in this repository starts the 4.4-GB transfer merely because the
fake transport tests pass. Physical SDF access and live Drive write acceptance
must be exercised separately.
