# Release checklist

1. Build both binaries in the ubuntu:22.04 container (glibc <= 2.34); bump `FFM_VERSION` and `CUSTOM_VERSION`.
2. Patches: `git am patches/*` on upstream 8e57bf0 must reproduce branch `fork` exactly.
2a. Regression: `tests/upstream-1.0.16/fixture_check.py <cmfd-v4-replay> <MODEL-V2.bank>` must print
   `FIXTURE PASS` on an RTX 30 and an RTX 40 card (speed and eco), and on the Windows build.
3. MANUAL.md (all three sections: English, Русский, 中文) and README.md: install URL, changelog, performance numbers.
4. Write `tools/notes/<version>.md` (what is new), then build the release description:
   `python3 tools/release_notes.py <version> <tar.gz sha256> tools/notes/<version>.md > body.md`
   The description always contains the full launch and setup guide (HiveOS, all pools, Linux, Windows when
   shipped, overclocking, fee, SHA-256) — never only the changelog.
5. Upload `freeforgeminer-<version>.tar.gz` and `freeforgeminer-<version>.tar.gz.sha256`; download the asset and
   compare its sha256.
