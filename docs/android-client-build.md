# Android client bundle producer

`build/android-client.grease` takes a verified NDK r27c directory, an explicit
ABI and a new absolute output directory. It builds the four existing C helpers
against Android/Bionic, packages the current Grease commands and pinned method
table, and emits source/ABI/API receipts and SHA-256 digests. API 21 is the helper
floor, not a device profile. Both arm64-v8a and armeabi-v7a are distinct bundles;
the IB authorization APK itself has no native payload.

The official Linux NDK r27c archive is 663987688 bytes, SHA-1
090e8083a715fdb1a3e402d0763c388abb03fb4e and verified SHA-256
59c2f6dc96743b5daf5d1626684640b20a6bd2b1d85b13156b90333741bad5cc.
Download/extraction is a separate host preparation action. The builder performs
no installation or download and refuses dirty tracked source or an existing
output. The NDK supplies C99 fixed-width arithmetic, POSIX file/socket calls,
and Bionic linkage. No qualified ICK Android/Bionic helper lane is currently
recorded, so this is the explicit NDK route rather than a claim about ICK.

This replaces the former GNU/Linux ARMv7 static upload-helper artifact. ELF
architecture and Android interpreter checks are build evidence only. Cat Food
issue 117 owns digest admission, runtime dependency acquisition (Grease, jq,
curl >=8.4, hash tools and OpenSSH), installed commands and device records.
No bundle receipt implies installation, C67 execution, physical OAuth, or an
SDF transfer. The ZIP inventory helper must be on the registered executable
path; the other helpers are found adjacent to the packaged commands.
