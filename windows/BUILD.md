# Building the Windows package

Requirements: Visual Studio 2022 Build Tools (C++ workload), CUDA Toolkit 12.9, Rust (rustup, MSVC toolchain), Git.
Layout: `CommonFoundry` (branch `fork` = upstream 8e57bf0 + `patches/*`) and `cutlass` (v3.9.2, commit ad7b2f5e) side by side with these scripts.

```powershell
.\build-replay.ps1 -Archs all -Out .\out-all\cmfd-v4-replay.exe   # CUDA worker, sm_70..sm_120, static cudart
.\build-miner.ps1                                                  # cmfd-miner.exe, static CRT
```

Package = `cmfd-miner.exe`, `cmfd-v4-replay.exe`, `start.bat`, `start.ps1`, `README-WINDOWS.txt`, `MANUAL.md`,
`PREPARE-V4-INPUTS.ps1` and the three input manifests (upstream `packaging/production-v4-testnet/windows` and
`packaging/production-v4-pool/shared`), `production-mainnet/` and the licenses, zipped in a folder `freeforgeminer`.
