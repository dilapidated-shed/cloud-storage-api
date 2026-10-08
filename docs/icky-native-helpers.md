# Icky native storage helpers

The three maintained native helpers use literal ← assignments and ×
multiplication. Pointer declarations and member access retain their C meaning.
The downloader maps a `transfer_progress` value to a `transfer_segment` and
classifies partial-file byte counts separately from append, fsync and rename.
The callback parser maps immutable encoded spans to query steps before decoding
and accumulating owned callback fields. The ZIP parser returns typed
`member_coordinates` rather than mutating four caller output parameters.

The public command grammar, output records, provider ownership, fixed-width
limits and existing error policy remain unchanged. Grease still owns provider
identity, HTTP and OAuth state. Native helpers own binary parsing, callback
reception and durable local file transitions.

`qualification/Makefile` is the fixed build-tool interface. Its compiler target
builds actual ICK at commit 143e29580c2644ea0f345fe609fa5673d036865d together
with ICK's own libgcc and libatomic. Host GCC/G++ only bootstrap that compiler.
The pinned Python 2.7.18 Buster image is shared with the existing Grease tests;
glibc headers, scalar libc/libm and loader remain declared image dependencies.
Maintained C is never compiled by the bootstrap compiler. The compiler and
binary hashes are retained with each exact-head artifact.

The native value tests cover transfer offsets above 4 GiB and at UINT64_MAX,
plus empty query pairs, embedded equals signs, trailing delimiters and field
decoding. Deterministic ZIP fixtures execute both current and frozen original
source through the same actual ICK compiler. Existing Grease tests use the
resulting helper binaries for fake OAuth/Drive and restartable-download/ranged
inventory contracts. Their POSIX fixture orchestration remains compatibility
scaffolding; it does not substitute for Grease product execution.

The frozen comparison checkout and compiler/Grease reference trees retain their
original syntax and provenance. Their roles are listed in
`qualification/c-source.tsv`. These checks do not establish live OAuth, live
Drive mutations, Takeout extraction or physical Android behavior.
