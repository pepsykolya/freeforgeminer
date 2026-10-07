# Release checklist

1. Build both binaries in the ubuntu:22.04 container (glibc <= 2.34); bump `FFM_VERSION` and `CUSTOM_VERSION`.
2. Patches: `git am patches/*` on upstream 8e57bf0 must reproduce branch `fork` exactly.
3. MANUAL.md (EN + RU) and README.md: install URL, changelog, performance numbers.
4. Write `tools/notes/<version>.md` (what is new), then build the release description:
   `python3 tools/release_notes.py <version> <tar.gz sha256> tools/notes/<version>.md > body.md`
   The description always contains the full launch and setup guide (HiveOS, all pools, Linux, Windows when
   shipped, overclocking, fee, SHA-256) — never only the changelog.
5. Upload `freeforgeminer-<version>.tar.gz` and `freeforgeminer-<version>.tar.gz.sha256`; download the asset and
   compare its sha256.
