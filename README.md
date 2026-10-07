# FreeForgeMiner

**Honest, fast and reliable miner for Common Foundry (CMFD, ForgeMatrix V4) on NVIDIA GPUs.**

FreeForgeMiner is an open-source fork of the official Common Foundry miner (MIT).
It runs the same consensus code and the same 6.4 GB model, it only does the GPU work faster.
Every change against upstream is published in [`patches/`](patches) — including the dev-fee code.

> **Free** = free and open source. **Fee** = 1 %, disclosed below and printed in the miner log.

## Why it is faster

| Change | Effect |
|---|---|
| NVIDIA Ampere (RTX 30xx) uses the Sm80 int8 Tensor Core pipeline (`m16n8k32` + async copy). Upstream ran Ampere on the Turing `m8n8k16` path. | **~+40 %** on RTX 3070 |
| The BLAKE3 final-activation digest is computed **on the GPU**. Each forward returns 32 bytes instead of 2 MiB. | **~+15 %** on PCIe x1 risers, no CPU hashing |
| One process per GPU | HiveOS shows hashrate, temperature and shares of **every card** |
| Integrity watchdog: every 128th batch is recomputed on the classic path and compared | An unstable GPU is reported in the log (`INTEGRITY \| ERROR`) instead of silently mining nothing |

Measured on one RTX 3070 (PCIe x1), batch 32, full cycle, stock clocks: upstream 10.3 FW/s → FreeForgeMiner 16.4–16.9 FW/s.
Results are bit-for-bit identical to upstream (verified by output hashes and by pool-accepted shares).

## Dev fee — 1 %

* 36 seconds out of every hour, per GPU, the miner mines to the developer wallet
  `a6b0915b0620997b2606574726fcf05628da6dc9ae9f2ff5bffe6d0a33ea9f2c`
  on **the same pool you selected**, worker name `ffm-fee`.
* The slot inside the hour is random for every GPU, so a rig never reconnects all cards at once.
* The miner prints `DEV FEE | ...` when the slice starts and ends.
* If the pool refuses the fee session, it is skipped — you are never charged extra time.
* Code: [`patches/0003-*`](patches).

## HiveOS

Flight sheet → Miner: **Custom** → Setup Miner Config:

| Field | Value |
|---|---|
| Miner name | `freeforgeminer` |
| Installation URL | `https://github.com/pepsykolya/freeforgeminer/releases/download/v1.0.2/freeforgeminer-1.0.2.tar.gz` |
| Hash algorithm | `forgematrix_v4` |
| Wallet and worker template | `YOUR_64_HEX_CMFD_ADDRESS.%WORKER_NAME%` |
| Pool URL | `cmfd+tls://IP:PORT?pin=64HEX` (numeric IPv4 + certificate pin, as published by your pool) |
| Extra config (optional) | `{"gpus":[0,1],"worker":"name","per_gpu_workers":false,"model_dir":"/hive/miners/custom/cmfd-model"}` |

* Requires NVIDIA driver R575+ (CUDA 12.9 runtime is bundled).
* The model is reused from `/hive/miners/custom/cmfd-model` when present (hash-verified), otherwise downloaded once
  from the official Common Foundry CDN.
* The whole rig is **one worker** on the pool (the pool adds up all cards); HiveOS still shows every card separately.
  Set `"per_gpu_workers": true` to get `<worker>.gpuN` per card on the pool.
* **Do not change GPU clocks while the miner is running** — set OC first, then start the miner.
* **Undervolting is dangerous here.** The Tensor Core path loads the GPU much harder than older miners; an offset/undervolt
  profile that looks stable elsewhere can return silently wrong results (no shares) or crash with Xid 13.
  Prefer stock clocks or a plain power limit, and watch for `INTEGRITY | ok` in the log.

## Build from source

```bash
./build.sh          # clones upstream at the pinned commit, applies patches/, builds miner + GPU worker
```
Needs: Rust (stable), CUDA Toolkit 12.9, git, python3. Build inside an Ubuntu 22.04 container (glibc 2.35) so the binaries run on HiveOS.

## License

MIT. Original work © Common Foundry contributors (`LICENSE-CommonFoundry`), changes © FreeForgeMiner contributors.

---

### Кратко по-русски

FreeForgeMiner — открытый форк официального майнера Common Foundry (CMFD). Тот же консенсус и та же модель,
быстрее на GPU: на RTX 3070 ~+40 % (тензорные ядра Ampere) и ещё ~+15 % на райзерах x1 (хеш считается на видеокарте).
Комиссия 1 %: 36 секунд в час на кошелёк разработчика на том же пуле, видна в логе (`DEV FEE`), код — в `patches/`.
HiveOS: Custom miner, ссылка на релиз выше, мощность видна по каждой карте.
