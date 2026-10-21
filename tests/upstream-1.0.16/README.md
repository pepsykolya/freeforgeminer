# Official Common Foundry 1.0.16 fixture

`mainnet-template-nonce0.bin` (a mainnet block template) and `mainnet-template-nonce0-count32.coefficients.bin`
(the coefficients of nonces 0-31) come unchanged from the Common Foundry 1.0.16 AMD HIP package
(`common-foundry-amd-hip-v1.0.16-linux-x86_64.tar.gz`, `share/common-foundry/amd-hip/fixtures/`), MIT,
Copyright (c) 2026 Common Foundry AMD HIP contributors — see `LICENSE-fixtures`. The expected output SHA-256
`fe67b80af4671210cd33306d0976c7dbb285dd55203d8eff733866cd7ef4a7a7` is the one their
`benchmarks/run_batch32_qualification.sh` requires (qualified on an RX 7900 XTX).

```bash
python3 fixture_check.py /path/to/cmfd-v4-replay /path/to/MODEL-V2.bank        # Linux / HiveOS
CMFD_MODE=eco python3 fixture_check.py ...                                      # the eco kernel
python fixture_check.py C:\FreeForgeMiner\cmfd-v4-replay.exe C:\...\MODEL-V2.bank   # Windows
```

It runs `RUNBATCH 32` several times (output must equal the reference every time) and `RUNBATCHDIGEST 32`
(the GPU BLAKE3 digests must equal BLAKE3 of the reference output; needs `pip install blake3`).
