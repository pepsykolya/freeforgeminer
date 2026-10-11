#!/usr/bin/env python3
"""Build the GitHub release description for a FreeForgeMiner version.

Every release carries the same launch and setup guide (HiveOS, all pools, plain Linux,
overclocking, fee, checksum) plus the version-specific "What is new" text.

usage: release_notes.py VERSION SHA256 WHATSNEW.md [--windows-zip NAME --windows-sha SHA]
"""
import argparse
import pathlib

REPO = "https://github.com/pepsykolya/freeforgeminer"
FEE_WALLET = "a6b0915b0620997b2606574726fcf05628da6dc9ae9f2ff5bffe6d0a33ea9f2c"
POOLS = [
    ("Aria / AriaBrain", "pool.ariabrain.com/cmfd.html, largest share of the network hashrate", "3 %",
     "cmfd+tls://159.69.194.46:29445?pin=9dfb51083f287726117f689f87bc7a878792efcca58ca8b6f6e7c05ac5d152e9"),
    ("cmfd-pool.online", "community pool, PPLNS, auto-payout from 10 CMFD", "3 %",
     "cmfd+tls://109.199.124.187:29465?pin=ebe88f5e05f3a222208d551d05b6d39057b64ce8239ba7a708d487e15ac711be"),
    ("NurseryPool", "cmfd.nurserypool.com", "1 %",
     "cmfd+tls://162.19.84.16:29445?pin=f61b1a26bebc257d95dad2e770ac15f229659ad85597f65c78293a3c1259c6a6"),
    ("Kavatar", "kavatar.kasplay.online, our pool, PPLNS, auto-payout from 2 CMFD; temporarily offline", "1 %",
     "cmfd+tls://188.35.20.44:29445?pin=71ab1d2e36cd20226ac16184b91dda5527126fa8b29ee1de2b6f5cd8b7028041"),
]


def build(version, sha, whatsnew, windows_zip=None, windows_sha=None):
    url = f"{REPO}/releases/download/v{version}/freeforgeminer-{version}.tar.gz"
    pools = "\n".join(f"| **{n}** ({d}) | {f} | `{u}` |" for n, d, f, u in POOLS)
    windows = ""
    if windows_zip:
        windows = f"""
### Windows 10/11 (no WSL needed)
1. Download `{windows_zip}` below and unpack it to a folder **without spaces or Cyrillic** in the path, e.g. `C:\\FreeForgeMiner`.
2. Right-click `start.bat` → *Edit*: set `WALLET`, `POOL` (one URL from the table above) and `WORKER`. Optional: `GPUS` (e.g. `0,1`), `BATCH`, `MODE` (`speed` or `eco`).
3. Run `start.bat`. The first start downloads and verifies the 6.4 GB model once; then one miner window line per GPU.
4. If Windows Defender / SmartScreen blocks it: *More info → Run anyway*, or add the folder to exclusions. Compare the archive with the SHA-256 below.
"""
    sums = f"* `freeforgeminer-{version}.tar.gz` (Linux / HiveOS): `{sha}`"
    if windows_zip:
        sums += f"\n* `{windows_zip}` (Windows): `{windows_sha}`"
    return f"""**FreeForgeMiner {version}** — honest, fast and reliable CMFD (ForgeMatrix V4) miner for NVIDIA GPUs, **best on RTX 30 series**. Open source (MIT), 1 % dev fee.

📖 **Full manual: [English]({REPO}/blob/main/MANUAL.md#english) · [Русский]({REPO}/blob/main/MANUAL.md#русский) · [中文]({REPO}/blob/main/MANUAL.md#中文)** — HiveOS step by step, every pool, overclocking, reading the log, troubleshooting.

### What is new in {version}
{whatsnew.strip()}

### HiveOS (Flight Sheet → Miner: Custom → Setup Miner Config)
| Field | Value |
|---|---|
| Miner name | `freeforgeminer` |
| Installation URL | `{url}` |
| Hash algorithm | `forgematrix_v4` |
| Wallet and worker template | `%WAL%.%WORKER_NAME%` |
| Pool URL | one full `cmfd+tls://…` URL from the table below |
| Pass | empty |
| Extra config arguments | empty, or `{{"mode":"eco"}}` for eco mode; more keys (`batch`, `per_gpu_workers`, `gpus`) in manual §6 |

Wallet: your CMFD address (64 hex characters), Pool: *Configure in miner*. Apply the flight sheet; the first start verifies or downloads the 6.4 GB model once. **Updating:** just change the Installation URL to the new version.

### Speed / eco mode
| | Default (`speed`) | How to turn on `eco` |
|---|---|---|
| HiveOS | nothing to set | Flight sheet → Setup Miner Config → **Extra config arguments**: `{{"mode":"eco"}}` |
| Windows | `set "MODE=speed"` in `start.bat` | edit `start.bat`: `set "MODE=eco"` |
| Linux | no variable | start the miner as `CMFD_MODE=eco ./cmfd-miner pool ...` |

**RTX 30:** `eco` uses about 13 % less power for about 2 % less hashrate (RTX 3070: 19.9 FW/s @ 156 W vs 20.3 FW/s @ 179 W), and it is the faster mode when the card runs at its power limit. **RTX 40/50:** both modes run the same kernel, nothing to choose. The mode takes effect at the next miner start.

### Pools
| Pool | Fee | Pool URL |
|---|---|---|
{pools}
{windows}
### Linux without HiveOS
```bash
tar xzf freeforgeminer-{version}.tar.gz && cd freeforgeminer
./cmfd-miner pool --pool 'cmfd+tls://IP:PORT?pin=...' --miner YOUR_ADDRESS --worker rig01 --gpu 0 \\
  --production-v4-bank /path/to/MODEL-V2.bank --production-v4-replay-worker "$PWD/cmfd-v4-replay" \\
  --production-v4-scratch /tmp/ffm-gpu0 --stats-seconds 5
```
One process per GPU (`--gpu N`). Eco mode: `CMFD_MODE=eco ./cmfd-miner pool ...`. Details in manual §11.

### Overclocking
**RTX 30:** lock the core clock and use a core offset, memory stock: start with **1560 MHz + offset 175**. Raise the offset in steps of 25 only while the log shows `INTEGRITY | ok` and no rejected/invalid shares. If a card shows `INTEGRITY ERROR` or crashes, lower its offset by 50. At a power limit choose `mode` `eco`.
**RTX 40:** lock the core clock and set the power limit a little above what the card draws there, memory stock (RTX 4070 Ti: **2250 MHz + 190 W** = 37.3 FW/s, **2400 MHz + 220 W** = 39.5 FW/s). Core and memory offsets change nothing with a locked clock.
Never change clocks while the miner runs. Full tables: manual, section 7.

### Dev fee: 1 %
36 s per hour per GPU to `{FEE_WALLET}` on the same pool (worker `ffm-fee`). Fully visible in the source (`patches/0003-*`).

### SHA-256
{sums}
"""


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("version")
    parser.add_argument("sha256")
    parser.add_argument("whatsnew")
    parser.add_argument("--windows-zip")
    parser.add_argument("--windows-sha")
    args = parser.parse_args()
    print(build(args.version, args.sha256, pathlib.Path(args.whatsnew).read_text(encoding="utf-8"),
                args.windows_zip, args.windows_sha))


if __name__ == "__main__":
    main()
