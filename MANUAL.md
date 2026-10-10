# FreeForgeMiner — Manual

* [English](#english)
* [Русский](#русский)

---

## English

### 1. What it is

FreeForgeMiner is an open-source miner for **Common Foundry (CMFD, ForgeMatrix V4)** on NVIDIA GPUs.
It is a fork of the official Common Foundry miner (MIT): same consensus code, same 6.4 GB model, faster GPU work.
Every change against upstream is in [`patches/`](patches), including the dev-fee code.

**Best for NVIDIA RTX 30 series (Ampere).** The official code runs RTX 30 cards on the old Turing Tensor Core path;
FreeForgeMiner switches them to the Ampere path and computes the final BLAKE3 digest on the GPU.

| GPU series | What FreeForgeMiner adds | Status |
|---|---|---|
| RTX 30xx (Ampere, sm_86) | Ampere Tensor Core path + GPU digest + fused GEMM+reduce kernel (1.2.0) | **main target, tested: ~20 FW/s on RTX 3070** |
| RTX 40xx (Ada, sm_89) | GPU digest + fused GEMM+reduce kernel (1.2.0) | tested on RTX 4070 Ti: ~30.5 FW/s on the pool (32.4 in GPU benchmark) |
| RTX 20xx (Turing), RTX 50xx (Blackwell), Volta, Hopper | GPU digest | built, not yet tested by us |

### 2. Measured performance

All numbers are real measurements, with the conditions stated.

| Test | Official / other miner | FreeForgeMiner |
|---|---|---|
| 1× RTX 3070, PCIe x1, stock clocks, full cycle (bench, 2026-10-07) | official Common Foundry code: **10.3 FW/s** | **16.4–16.9 FW/s** (1.1.x); **~20 FW/s** with 1.2.0 (GPU benchmark 14.9 → 20.0) |
| Rig 8× RTX 3070, core lock 1560 MHz, hashrate reported to cmfd-pool.online (2026-10-07) | CMFD GPU miner r13 (lucasan123): **113.2 FW/s** | **116.7 FW/s** |

Results are bit-for-bit identical to upstream and shares are accepted by the pools
(cmfd-pool.online, Aria) with 0 invalid proofs. The pool's *effective* hashrate is computed from shares over time;
compare effective hashrate over several hours, not minutes.

### 3. Requirements

* NVIDIA GPU with **8 GB VRAM or more**.
* NVIDIA driver **R575 or newer** (CUDA 12.9 runtime is bundled).
* HiveOS (Ubuntu 22.04 based), any Linux x86_64 with glibc 2.34+, or **Windows 10/11 x64** (section 12).
* ~6.5 GB free disk for the model (shared between miners, downloaded once).

### 4. HiveOS setup (step by step)

1. **Wallets** → add your CMFD wallet (64 hex characters).
2. **Flight Sheets** → *Create Flight Sheet*:
   * Coin: `CMFD` (or any name), Wallet: your CMFD wallet.
   * Pool: **Configure in miner**.
   * Miner: **Custom** → **Setup Miner Config**:

| Field | Value |
|---|---|
| Miner name | `freeforgeminer` |
| Installation URL | link to the latest release archive, e.g. `https://github.com/pepsykolya/freeforgeminer/releases/download/vX.Y.Z/freeforgeminer-X.Y.Z.tar.gz` |
| Hash algorithm | `forgematrix_v4` |
| Wallet and worker template | `%WAL%.%WORKER_NAME%` (or `YOUR_ADDRESS.rigname`) |
| Pool URL | full `cmfd+tls://IP:PORT?pin=...` from the table in section 5 |
| Pass | leave empty |
| Extra config arguments | leave empty, or JSON from section 6 |

3. **Apply** the flight sheet to the rig. On the first start the miner checks the model hash (~1 minute,
   or downloads 6.4 GB once), then starts one process per GPU.
4. In HiveOS every card shows its own hashrate, temperature and accepted/rejected shares.
   On the pool the whole rig is **one worker** (`rigname`).

> **Updating:** change the Installation URL to the new version. HiveOS reinstalls only when the version changes.

### 5. Pools

The miner needs a **numeric IPv4 address, port and certificate pin** (a domain name is not accepted).
The pin is the SHA-256 of the pool's TLS certificate: the miner refuses any other server.

| Pool | Fee | Pool URL (copy the whole line) |
|---|---|---|
| **cmfd-pool.online** (community pool, PPLNS, auto-payout from 10 CMFD) | 3 % | `cmfd+tls://109.199.124.187:29465?pin=ebe88f5e05f3a222208d551d05b6d39057b64ce8239ba7a708d487e15ac711be` |
| **Aria / AriaBrain** (pool.ariabrain.com/cmfd.html) | 3 % (`operator_fee_bps=300` in its API) | `cmfd+tls://159.69.194.46:29445?pin=9dfb51083f287726117f689f87bc7a878792efcca58ca8b6f6e7c05ac5d152e9` |
| **NurseryPool** (cmfd.nurserypool.com) | 1 % | `cmfd+tls://162.19.84.16:29445?pin=f61b1a26bebc257d95dad2e770ac15f229659ad85597f65c78293a3c1259c6a6` |

Pins and fees were checked on 2026-10-07. Verify a pin yourself:
```bash
openssl s_client -connect 109.199.124.187:29465 </dev/null 2>/dev/null | openssl x509 -outform DER | sha256sum
```

**Pool bans.** cmfd-pool.online temporarily bans the **IP address** (about one hour) after a flood of rejected shares.
All rigs behind the same IP are affected. Rejected shares almost always mean an unstable overclock (section 7).

### 6. Extra config (optional JSON)

```json
{"gpus":[0,1,2], "worker":"rig01", "per_gpu_workers":false, "batch":64, "model_dir":"/hive/miners/custom/cmfd-model"}
```
| Key | Meaning |
|---|---|
| `gpus` | mine only on these GPU indices (default: all) |
| `worker` | worker name on the pool (default: from the wallet template or the rig name) |
| `per_gpu_workers` | `true` = each card is a separate worker `rig.gpuN` on the pool; default `false` = one worker per rig |
| `model_dir` | where the 6.4 GB model lives (default `/hive/miners/custom/cmfd-model`, shared with other CMFD miners) |
| `batch` | forwards per GPU pass, 1–64. Omit = automatic: 64 on 11 GB+ cards, 32 on 8 GB cards. Measured on RTX 4070 Ti: 4→23.2, 32→23.9, 64→24.1 FW/s (GPU time); on RTX 3070 the difference is within 1 % |

### 7. Overclocking (RTX 30)

The Tensor Core path loads the GPU much harder than older miners. A profile that is stable elsewhere can make the GPU
**return wrong results silently** — the miner then finds no valid shares or the pool rejects them.

* Lock the core clock and use a core offset, memory stock. Start with **core lock 1560 MHz + offset 175**
  (RTX 3070: ~20 FW/s with 1.2.x; was ~14.6 FW/s with 1.1). Raise the offset in steps of 25 only while the log shows `INTEGRITY | ok`
  and **no** `SHARE REJECTED`. On our cards +275 and +225 caused errors on some GPUs, +175 was stable.
  Each card is different: in HiveOS you can set a value per card (`175 175 275 ...`).
* **Never change clocks while the miner is running.** Set OC, then (re)start the miner.
* **1.2.0 note:** the fused kernel loads the GPU more densely. After updating, check the log for `INTEGRITY | ok` and no rejected/invalid shares. If a heavily undervolted card shows `INTEGRITY ERROR` or crashes, lower its core offset by 50.
* Stock clocks are always safe (~16.5 FW/s, ~250 W per RTX 3070).

### 8. Reading the log

| Line | Meaning |
|---|---|
| `MINER STATS | GPU n ... hashrate X FW/s | accepted A | rejected R | stale S ...` | per-GPU status every 5 s |
| `INTEGRITY | ok` | every 128th batch was recomputed on the classic path and matched |
| `INTEGRITY | ERROR ...` | **the GPU computes wrong results** — lower the offset/clocks for that card |
| `SHARE STALE` | the block changed before the share arrived — harmless, not counted as rejected |
| `SHARE NOT CREDITED` | pool-side condition (e.g. `backend_unavailable`) — not a GPU problem |
| `SHARE RETRY \| code=worker_busy` | the pool was busy with another share of the same worker (one worker per rig); the share is resent automatically |
| `SHARE REJECTED | code=...` | the pool rejected the share; repeated rejects = unstable GPU |
| `DEV FEE | mining 36 s ...` / `DEV FEE | done` | the 1 % developer fee slice |

HiveOS logs: `/var/log/miner/freeforgeminer/miner.log` and one file per GPU next to it.

### 9. Dev fee — 1 %

36 seconds out of every hour, per GPU, the miner mines to
`a6b0915b0620997b2606574726fcf05628da6dc9ae9f2ff5bffe6d0a33ea9f2c` on the same pool (worker `ffm-fee`).
The slot is random per GPU (a rig never reconnects all cards at once); if the pool refuses it, it is skipped.
Code: `patches/0003-*`.

### 10. Troubleshooting

| Symptom | Fix |
|---|---|
| `GLIBC_2.xx not found` | use release 1.0.1 or newer (built for Ubuntu 22.04) |
| High CPU load / CPU temperature with 1.2.0 or older | update to 1.2.1 (Installation URL with the new version) |
| HiveOS says `Already installed` and nothing changes | the Installation URL must point to a new version |
| `worker temporarily banned` | your IP is banned by the pool for rejected shares: stop all miners on that IP for ~1 hour, fix OC, start one rig first |
| `INTEGRITY | ERROR` or many `SHARE REJECTED` | lower the core offset of that GPU, restart the miner |
| model download fails | check DNS/internet on the rig; the model comes from the official Common Foundry CDN |
| Windows: hashrate 0.5-2 FW/s instead of ~20 | the 6.4 GB model does not fit into free VRAM and Windows moves part of it to RAM: close programs that use the GPU (local AI models, games, browser hardware acceleration); `start.bat` warns when less than ~7000 MiB are free |
| Windows: archive or `.exe` blocked by Defender / SmartScreen | *More info → Run anyway*, or add the miner folder to Defender exclusions; check the archive SHA-256 from the release page |

### 11. Linux without HiveOS

```bash
tar xzf freeforgeminer-X.Y.Z.tar.gz && cd freeforgeminer
./cmfd-miner pool --pool 'cmfd+tls://IP:PORT?pin=...' --miner YOUR_ADDRESS --worker rig01 --gpu 0 [--batch 32] \
  --production-v4-bank /path/to/MODEL-V2.bank --production-v4-replay-worker "$PWD/cmfd-v4-replay" \
  --production-v4-scratch /tmp/ffm-gpu0 --stats-seconds 5
```
Run one process per GPU (`--gpu N`). The first run needs the model and the launch files (`production-mainnet/`) from the archive.

### 12. Windows 10/11

Native Windows build — no WSL, no CUDA installation, no Python. Only the NVIDIA driver is needed
(tested on driver 572.70, RTX 4070 Laptop: ~20 FW/s, bit-exact with the Linux build).

1. Download **`freeforgeminer-1.2.1-windows-x64.zip`** from the release page:
   `https://github.com/pepsykolya/freeforgeminer/releases/download/v1.2.1/freeforgeminer-1.2.1-windows-x64.zip`
2. Unpack it to a folder **without spaces or non-English letters**, e.g. `C:\FreeForgeMiner`.
3. Right-click **`start.bat`** → *Edit* and set:

| Setting | Value |
|---|---|
| `WALLET` | your CMFD address (64 hex characters) |
| `POOL` | one full `cmfd+tls://…` URL from section 5 (default: cmfd-pool.online) |
| `WORKER` | rig name, default = computer name |
| `GPUS` | empty = all NVIDIA GPUs, or a list like `0,1` (indexes from `nvidia-smi`) |
| `BATCH` | empty = automatic, or 1-64 |
| `PER_GPU_WORKERS` | `0` = the PC is one worker on the pool, `1` = one worker per GPU |

4. Double-click **`start.bat`**. The first start downloads the 6.4 GB model once (16 parallel parts, every part
   SHA-256-verified, ~10-30 min depending on the connection). Later starts only re-check it (~1 min).
5. One miner process runs per GPU; their lines are shown in one window as `[GPU0] …`, `[GPU1] …` and saved to
   `logs\gpuN.log`. A process that exits is restarted automatically after 15 s. `Ctrl+C` stops everything.

* **VRAM:** the model takes ~6.7 GB of video memory. On 8 GB cards close everything else that uses the GPU — if it
  does not fit, Windows silently moves part of it to system RAM and the hashrate drops to ~0.5 FW/s.
* **Overclocking:** use MSI Afterburner (core lock via the curve editor + core offset, memory stock); the rules from
  section 7 apply unchanged. Laptops: plug in the charger and choose the maximum performance mode.
* Autostart: put a shortcut to `start.bat` into `shell:startup`.

---

### Changelog

* **1.2.1** - the miner no longer keeps one CPU core at 100 % per GPU while waiting for the GPU (CUDA blocking sync): on rigs with small CPUs (e.g. 4-core i5 with 6–8 GPUs) CPU load and temperature drop sharply. Hashrate and results unchanged.
* **1.2.0 Windows** - native Windows 10/11 x64 build of 1.2.0 (no WSL): `start.bat` launcher, one process per GPU, automatic model download and restart. Same code and results as the Linux build.
* **1.2.0** - new fused GEMM+reduce GPU kernel (int8 tensor cores, layer reduce in registers): RTX 3070 14.9 -> 20.0 FW/s (+34 %), RTX 4070 Ti 26.1 -> 32.4 FW/s (+24 %) in the GPU benchmark; on the pool 4070 Ti 25.6 -> 30.5 FW/s. Bit-exact with the reference (determinism and digest checks), uses ~4x less GPU memory. Works on RTX 30/40/50 (sm_80+); older GPUs use the previous path. `CMFD_FUSED=-1` restores the old kernel.
* **1.1.1** - log banner shows the real release version.
* **1.1.0** - persistent search buffers and no dead stores of per-layer activations/preactivations. RTX 4070 Ti: 23.7 -> 25.7 FW/s (+9 %, ~185 W); RTX 3070: 14.56 -> 14.69 FW/s (+1 %). Bit-exact (determinism and digest verified), 0 rejected / 0 invalid on the pool.
* **1.0.6** - correct hashrate with batch 64 (12 GB+ cards).

## Русский

### 1. Что это

FreeForgeMiner — майнер с открытым кодом для **Common Foundry (CMFD, ForgeMatrix V4)** на видеокартах NVIDIA.
Это форк официального майнера Common Foundry (лицензия MIT): тот же консенсус, та же модель 6,4 ГБ, но быстрее на GPU.
Все изменения относительно официального кода лежат в [`patches/`](patches), включая код комиссии.

**Лучше всего подходит для RTX 30-й серии (Ampere).** Официальный код гоняет 30-ю серию по старому пути тензорных ядер
(как у Turing); FreeForgeMiner переводит её на путь Ampere и считает финальный хеш BLAKE3 прямо на видеокарте.

| Серия | Что даёт FreeForgeMiner | Статус |
|---|---|---|
| RTX 30xx (Ampere) | путь Ampere на тензорных ядрах + хеш на GPU + объединённое ядро GEMM+reduce (1.2.0) | **основная цель, проверено: ~20 FW/s на RTX 3070** |
| RTX 40xx (Ada) | хеш на GPU + объединённое ядро GEMM+reduce (1.2.0) | проверено на RTX 4070 Ti: ~30,5 FW/s на пуле (32,4 в тесте GPU) |
| RTX 20xx, RTX 50xx, Volta, Hopper | хеш на GPU | собрано, нами пока не проверялось |

### 2. Измеренная производительность

Только реальные замеры, с условиями.

| Замер | Официальный / другой майнер | FreeForgeMiner |
|---|---|---|
| 1× RTX 3070, PCIe x1, сток, полный цикл (стенд, 07.10.2026) | официальный код Common Foundry: **10,3 FW/s** | **16,4–16,9 FW/s** (1.1.x); **~20 FW/s** с 1.2.0 (тест GPU 14,9 → 20,0) |
| Риг 8× RTX 3070, фиксация ядра 1560 МГц, мощность на cmfd-pool.online (07.10.2026) | CMFD GPU miner r13 (lucasan123): **113,2 FW/s** | **116,7 FW/s** |

Результаты побитово совпадают с официальными, пулы (cmfd-pool.online, Aria) принимают шары, ошибочных доказательств 0.
Эффективную мощность пул считает по шарам за время — сравнивайте её за несколько часов, а не минут.

### 3. Требования

* Видеокарта NVIDIA с **8 ГБ памяти и больше**.
* Драйвер NVIDIA **R575 или новее** (среда CUDA 12.9 уже внутри архива).
* HiveOS (на базе Ubuntu 22.04), любой Linux x86_64 с glibc 2.34+ или **Windows 10/11 x64** (раздел 12).
* ~6,5 ГБ на диске под модель (общая для майнеров, качается один раз).

### 4. Настройка в HiveOS (по шагам)

1. **Wallets** → добавьте свой CMFD-кошелёк (64 шестнадцатеричных символа).
2. **Flight Sheets** → *Create Flight Sheet*:
   * Coin: `CMFD` (или любое имя), Wallet: ваш CMFD-кошелёк.
   * Pool: **Configure in miner**.
   * Miner: **Custom** → **Setup Miner Config**:

| Поле | Значение |
|---|---|
| Miner name | `freeforgeminer` |
| Installation URL | ссылка на архив последнего релиза, например `https://github.com/pepsykolya/freeforgeminer/releases/download/vX.Y.Z/freeforgeminer-X.Y.Z.tar.gz` |
| Hash algorithm | `forgematrix_v4` |
| Wallet and worker template | `%WAL%.%WORKER_NAME%` (или `ВАШ_АДРЕС.имя_рига`) |
| Pool URL | строка `cmfd+tls://IP:PORT?pin=...` целиком из таблицы в разделе 5 |
| Pass | пусто |
| Extra config arguments | пусто или JSON из раздела 6 |

3. **Примените** полётник к ригу. При первом запуске майнер сверяет хеш модели (~1 минута, либо один раз качает 6,4 ГБ),
   затем запускает по процессу на каждую карту.
4. В HiveOS у каждой карты своя мощность, температура и шары. На пуле весь риг — **один воркер** (`имя_рига`).

> **Обновление:** замените Installation URL на новую версию — HiveOS переустанавливает майнер только при смене версии.

### 5. Пулы

Майнеру нужен **числовой IPv4-адрес, порт и pin сертификата** (доменное имя не принимается).
Pin — это SHA-256 TLS-сертификата пула: к другому серверу майнер не подключится.

| Пул | Комиссия | Pool URL (копировать строку целиком) |
|---|---|---|
| **cmfd-pool.online** (комьюнити-пул, PPLNS, автовыплата от 10 CMFD) | 3 % | `cmfd+tls://109.199.124.187:29465?pin=ebe88f5e05f3a222208d551d05b6d39057b64ce8239ba7a708d487e15ac711be` |
| **Aria / AriaBrain** (pool.ariabrain.com/cmfd.html) | 3 % (`operator_fee_bps=300` в их API) | `cmfd+tls://159.69.194.46:29445?pin=9dfb51083f287726117f689f87bc7a878792efcca58ca8b6f6e7c05ac5d152e9` |
| **NurseryPool** (cmfd.nurserypool.com) | 1 % | `cmfd+tls://162.19.84.16:29445?pin=f61b1a26bebc257d95dad2e770ac15f229659ad85597f65c78293a3c1259c6a6` |

Pin и комиссии проверены 07.10.2026. Проверить pin самому:
```bash
openssl s_client -connect 109.199.124.187:29465 </dev/null 2>/dev/null | openssl x509 -outform DER | sha256sum
```

**Баны пула.** cmfd-pool.online временно (примерно на час) банит **IP-адрес** после потока отклонённых шар —
под бан попадают все риги за этим IP. Отклонённые шары почти всегда означают нестабильный разгон (раздел 7).

### 6. Extra config (необязательный JSON)

```json
{"gpus":[0,1,2], "worker":"rig01", "per_gpu_workers":false, "batch":64, "model_dir":"/hive/miners/custom/cmfd-model"}
```
| Ключ | Что делает |
|---|---|
| `gpus` | майнить только на этих картах (по умолчанию — на всех) |
| `worker` | имя воркера на пуле (по умолчанию — из шаблона кошелька или имя рига) |
| `per_gpu_workers` | `true` — каждая карта отдельным воркером `rig.gpuN` на пуле; по умолчанию `false` — один воркер на риг |
| `model_dir` | где лежит модель 6,4 ГБ (по умолчанию `/hive/miners/custom/cmfd-model`, общая с другими CMFD-майнерами) |
| `batch` | проходов на карту за раз, 1–64. Не указан — автоматически: 64 для карт от 11 ГБ, 32 для 8 ГБ. Замер на RTX 4070 Ti: 4→23,2, 32→23,9, 64→24,1 FW/s (время GPU); на RTX 3070 разница в пределах 1 % |

### 7. Разгон (RTX 30)

Путь тензорных ядер нагружает карту сильнее, чем старые майнеры. Профиль, стабильный в другом майнере, может заставить
карту **молча считать неправильно** — тогда майнер не находит верных шар или пул их отклоняет.

* Фиксация частоты ядра + смещение, память — сток. Начинайте с **фиксации 1560 МГц и смещения +175**
  (RTX 3070: ~20 FW/s на 1.2.x; на 1.1 было ~14,6 FW/s). Повышайте смещение шагами по 25, только пока в логе `INTEGRITY | ok`
  и **нет** `SHARE REJECTED`. На наших картах +275 и +225 давали ошибки на части GPU, +175 — стабильно.
  Каждая карта своя: в HiveOS можно задать значение для каждой карты (`175 175 275 ...`).
* **Не меняйте частоты при работающем майнере.** Сначала разгон, потом (пере)запуск майнера.
* **Заметка к 1.2.0:** новое ядро нагружает карту плотнее. После обновления проверьте в логе `INTEGRITY | ok` и отсутствие rejected/invalid шар. Если сильно андервольтнутая карта показывает `INTEGRITY ERROR` или падает, уменьшите смещение ядра на 50.
* Сток безопасен всегда (~16,5 FW/s, ~250 Вт на RTX 3070).

### 8. Как читать лог

| Строка | Что значит |
|---|---|
| `MINER STATS | GPU n ... hashrate X FW/s | accepted A | rejected R | stale S ...` | состояние карты каждые 5 с |
| `INTEGRITY | ok` | каждая 128-я пачка пересчитана классическим способом и совпала |
| `INTEGRITY | ERROR ...` | **карта считает с ошибками** — снизьте смещение/частоты этой карте |
| `SHARE STALE` | блок сменился, пока шара летела, — безобидно, в «rejected» не считается |
| `SHARE NOT CREDITED` | проблема на стороне пула (например, `backend_unavailable`) — карта ни при чём |
| `SHARE RETRY \| code=worker_busy` | пул был занят другой шарой этого же воркера (один воркер на риг); шара автоматически отправлена повторно |
| `SHARE REJECTED | code=...` | пул отклонил шару; повторяется — карта нестабильна |
| `DEV FEE | mining 36 s ...` / `DEV FEE | done` | окно комиссии разработчика 1 % |

Логи в HiveOS: `/var/log/miner/freeforgeminer/miner.log` и рядом по файлу на каждую карту.

### 9. Комиссия — 1 %

36 секунд из каждого часа, на каждой карте, майнер работает на кошелёк
`a6b0915b0620997b2606574726fcf05628da6dc9ae9f2ff5bffe6d0a33ea9f2c` на том же пуле (воркер `ffm-fee`).
Момент внутри часа у каждой карты случайный (риг не переподключает все карты разом); если пул отказал — окно пропускается.
Код: `patches/0003-*`.

### 10. Проблемы и решения

| Симптом | Решение |
|---|---|
| `GLIBC_2.xx not found` | используйте релиз 1.0.1 или новее (собран под Ubuntu 22.04) |
| Высокая загрузка / температура CPU на 1.2.0 и старше | обновитесь до 1.2.1 (Installation URL с новой версией) |
| HiveOS пишет `Already installed`, ничего не меняется | в Installation URL должна быть новая версия |
| `worker temporarily banned` | ваш IP забанен пулом за отклонённые шары: остановите все майнеры за этим IP примерно на час, исправьте разгон, запускайте сначала один риг |
| `INTEGRITY | ERROR` или много `SHARE REJECTED` | снизьте смещение этой карте, перезапустите майнер |
| не качается модель | проверьте DNS/интернет на риге; модель берётся с официального CDN Common Foundry |
| Windows: хешрейт 0,5–2 FW/s вместо ~20 | модель 6,4 ГБ не помещается в свободную видеопамять, и Windows выносит её часть в ОЗУ: закройте программы, занимающие видеокарту (локальные нейросети, игры, аппаратное ускорение браузера); `start.bat` предупреждает, если свободно меньше ~7000 МиБ |
| Windows: архив или `.exe` блокирует Defender / SmartScreen | *Подробнее → Выполнить в любом случае* или добавьте папку майнера в исключения Defender; сверьте SHA-256 архива со страницей релиза |

### 11. Linux без HiveOS

```bash
tar xzf freeforgeminer-X.Y.Z.tar.gz && cd freeforgeminer
./cmfd-miner pool --pool 'cmfd+tls://IP:PORT?pin=...' --miner ВАШ_АДРЕС --worker rig01 --gpu 0 [--batch 32] \
  --production-v4-bank /путь/к/MODEL-V2.bank --production-v4-replay-worker "$PWD/cmfd-v4-replay" \
  --production-v4-scratch /tmp/ffm-gpu0 --stats-seconds 5
```
По процессу на каждую карту (`--gpu N`). Для первого запуска нужны модель и файлы запуска сети (`production-mainnet/`) из архива.

### 12. Windows 10/11

Нативная сборка под Windows — без WSL, без установки CUDA и Python. Нужен только драйвер NVIDIA
(проверено на драйвере 572.70, RTX 4070 Laptop: ~20 FW/s, результат побитово как у Linux-сборки).

1. Скачайте **`freeforgeminer-1.2.1-windows-x64.zip`** со страницы релиза:
   `https://github.com/pepsykolya/freeforgeminer/releases/download/v1.2.1/freeforgeminer-1.2.1-windows-x64.zip`
2. Распакуйте в папку **без пробелов и русских букв**, например `C:\FreeForgeMiner`.
3. Правой кнопкой по **`start.bat`** → *Изменить* и задайте:

| Параметр | Значение |
|---|---|
| `WALLET` | ваш CMFD-адрес (64 шестнадцатеричных символа) |
| `POOL` | одна строка `cmfd+tls://…` целиком из раздела 5 (по умолчанию cmfd-pool.online) |
| `WORKER` | имя рига, по умолчанию — имя компьютера |
| `GPUS` | пусто = все карты NVIDIA, или список вида `0,1` (номера из `nvidia-smi`) |
| `BATCH` | пусто = автоматически, или 1–64 |
| `PER_GPU_WORKERS` | `0` = весь ПК один воркер на пуле, `1` = отдельный воркер на каждую карту |

4. Запустите **`start.bat`** двойным щелчком. При первом запуске модель 6,4 ГБ скачивается один раз (16 частей
   параллельно, каждая проверяется по SHA-256, ~10–30 минут в зависимости от интернета). Дальше при запуске она только
   перепроверяется (~1 минута).
5. На каждую карту — свой процесс майнера; их строки видны в одном окне как `[GPU0] …`, `[GPU1] …` и пишутся в
   `logs\gpuN.log`. Упавший процесс перезапускается автоматически через 15 с. `Ctrl+C` останавливает всё.

* **Видеопамять:** модель занимает ~6,7 ГБ. На картах 8 ГБ закройте всё, что использует видеокарту, — если модель
  не поместится, Windows молча вынесет её часть в оперативную память и хешрейт упадёт до ~0,5 FW/s.
* **Разгон:** MSI Afterburner (фиксация частоты через редактор кривой + смещение ядра, память сток); правила из
  раздела 7 те же. Ноутбуки: подключите зарядку и включите режим максимальной производительности.
* Автозапуск: положите ярлык `start.bat` в `shell:startup`.

### Список изменений

* **1.2.1** - майнер больше не держит по ядру процессора на 100 % на каждую видеокарту, пока ждёт GPU (блокирующее ожидание CUDA): на ригах со слабым процессором (например, 4-ядерный i5 и 6–8 карт) нагрузка и температура CPU резко падают. Хешрейт и результаты не меняются.
* **1.2.0 Windows** - нативная сборка 1.2.0 под Windows 10/11 x64 (без WSL): запуск через `start.bat`, процесс на каждую карту, автоматическая загрузка модели и перезапуск. Код и результаты те же, что у Linux-сборки.
* **1.2.0** - новое объединённое ядро GEMM+reduce (int8 тензорные ядра, свёртка слоя в регистрах): RTX 3070 14,9 -> 20,0 FW/s (+34 %), RTX 4070 Ti 26,1 -> 32,4 FW/s (+24 %) в тесте GPU; на пуле 4070 Ti 25,6 -> 30,5 FW/s. Побитово совпадает с эталоном (проверки детерминизма и дайджеста), памяти GPU нужно примерно в 4 раза меньше. Работает на RTX 30/40/50 (sm_80+); старые карты идут по прежнему пути. `CMFD_FUSED=-1` возвращает старое ядро.
* **1.1.1** - баннер в логе показывает реальную версию релиза.
* **1.1.0** - постоянные буферы поиска, убраны лишние записи активаций и преактиваций по слоям. RTX 4070 Ti: 23,7 -> 25,7 FW/s (+9 %, ~185 Вт); RTX 3070: 14,56 -> 14,69 FW/s (+1 %). Результат побитово тот же (детерминизм и дайджест проверены), на пуле 0 отклонённых / 0 ошибочных.
* **1.0.6** - корректный хешрейт при batch 64 (карты от 12 ГБ).

## 中文

### 1. 这是什么

FreeForgeMiner 是面向 NVIDIA 显卡的 **Common Foundry (CMFD, ForgeMatrix V4)** 开源矿工。
它是官方 Common Foundry 矿工（MIT）的分支：共识代码相同、6.4 GB 模型相同，但 GPU 计算更快。
相对上游的所有改动都在 [`patches/`](patches) 中，包括开发者抽水（dev fee）代码。

**最适合 NVIDIA RTX 30 系列（Ampere）。** 官方代码在 RTX 30 显卡上走的是旧的 Turing Tensor Core 路径；
FreeForgeMiner 将其切换为 Ampere 路径，并在 GPU 上计算最终的 BLAKE3 摘要。

| 显卡系列 | FreeForgeMiner 的改进 | 状态 |
|---|---|---|
| RTX 30xx (Ampere, sm_86) | Ampere Tensor Core 路径 + GPU 摘要 + 融合 GEMM+reduce 内核 (1.2.0) | **主要目标，已测试：RTX 3070 约 20 FW/s** |
| RTX 40xx (Ada, sm_89) | GPU 摘要 + 融合 GEMM+reduce 内核 (1.2.0) | 已在 RTX 4070 Ti 上测试：矿池上约 30.5 FW/s（GPU 基准测试 32.4） |
| RTX 20xx (Turing), RTX 50xx (Blackwell), Volta, Hopper | GPU 摘要 | 已编译，我们尚未测试 |

### 2. 实测性能

所有数据均为真实测量，并注明了测试条件。

| 测试 | 官方 / 其他矿工 | FreeForgeMiner |
|---|---|---|
| 1× RTX 3070，PCIe x1，默认频率，完整周期（基准测试，2026-10-07） | 官方 Common Foundry 代码：**10.3 FW/s** | **16.4–16.9 FW/s**（1.1.x）；1.2.0 约 **20 FW/s**（GPU 基准测试 14.9 → 20.0） |
| 8× RTX 3070 矿机，核心锁频 1560 MHz，上报给 cmfd-pool.online 的算力（2026-10-07） | CMFD GPU miner r13 (lucasan123)：**113.2 FW/s** | **116.7 FW/s** |

结果与上游逐位完全一致，提交的份额（share）被矿池（cmfd-pool.online、Aria）接受，无效证明为 0。
矿池显示的*有效*算力是根据一段时间内的份额计算的；
请对比数小时的有效算力，而不是几分钟。

### 3. 系统要求

* **显存 8 GB 或以上**的 NVIDIA 显卡。
* NVIDIA 驱动 **R575 或更新版本**（已内置 CUDA 12.9 运行库）。
* HiveOS（基于 Ubuntu 22.04）、任意 glibc 2.34+ 的 Linux x86_64，或 **Windows 10/11 x64**（第 12 节）。
* 约 6.5 GB 可用磁盘空间用于模型（各矿工共享，仅下载一次）。

### 4. HiveOS 设置（分步说明）

1. **Wallets**（钱包）→ 添加你的 CMFD 钱包（64 位十六进制字符）。
2. **Flight Sheets**（飞行表）→ *Create Flight Sheet*：
   * Coin：`CMFD`（或任意名称），Wallet：你的 CMFD 钱包。
   * Pool：**Configure in miner**。
   * Miner：**Custom** → **Setup Miner Config**：

| 字段 | 值 |
|---|---|
| Miner name | `freeforgeminer` |
| Installation URL | 最新版本压缩包的链接，例如 `https://github.com/pepsykolya/freeforgeminer/releases/download/vX.Y.Z/freeforgeminer-X.Y.Z.tar.gz` |
| Hash algorithm | `forgematrix_v4` |
| Wallet and worker template | `%WAL%.%WORKER_NAME%`（或 `YOUR_ADDRESS.rigname`） |
| Pool URL | 第 5 节表格中完整的 `cmfd+tls://IP:PORT?pin=...` |
| Pass | 留空 |
| Extra config arguments | 留空，或填入第 6 节的 JSON |

3. 将 Flight Sheet **应用（Apply）**到矿机。首次启动时，矿工会校验模型哈希（约 1 分钟，
   或一次性下载 6.4 GB），然后为每块显卡启动一个进程。
4. 在 HiveOS 中，每块显卡都会显示各自的算力、温度和已接受/被拒绝的份额。
   在矿池上，整台矿机是**一个矿工名**（`rigname`）。

> **更新：** 将 Installation URL 改为新版本即可。只有版本变化时 HiveOS 才会重新安装。

### 5. 矿池

矿工需要**数字 IPv4 地址、端口和证书指纹（pin）**（不接受域名）。
pin 是矿池 TLS 证书的 SHA-256：矿工会拒绝连接任何其他服务器。

| 矿池 | 费率 | 矿池 URL（复制整行） |
|---|---|---|
| **cmfd-pool.online**（社区矿池，PPLNS，满 10 CMFD 自动支付） | 3 % | `cmfd+tls://109.199.124.187:29465?pin=ebe88f5e05f3a222208d551d05b6d39057b64ce8239ba7a708d487e15ac711be` |
| **Aria / AriaBrain** (pool.ariabrain.com/cmfd.html) | 3 %（其 API 中 `operator_fee_bps=300`） | `cmfd+tls://159.69.194.46:29445?pin=9dfb51083f287726117f689f87bc7a878792efcca58ca8b6f6e7c05ac5d152e9` |
| **NurseryPool** (cmfd.nurserypool.com) | 1 % | `cmfd+tls://162.19.84.16:29445?pin=f61b1a26bebc257d95dad2e770ac15f229659ad85597f65c78293a3c1259c6a6` |

pin 和费率于 2026-10-07 核实。你可以自行验证 pin：
```bash
openssl s_client -connect 109.199.124.187:29465 </dev/null 2>/dev/null | openssl x509 -outform DER | sha256sum
```

**矿池封禁。** 在大量提交被拒份额后，cmfd-pool.online 会临时封禁**IP 地址**（约一小时）。
同一 IP 下的所有矿机都会受影响。份额被拒几乎总是意味着超频不稳定（第 7 节）。

### 6. 额外配置（可选 JSON）

```json
{"gpus":[0,1,2], "worker":"rig01", "per_gpu_workers":false, "batch":64, "model_dir":"/hive/miners/custom/cmfd-model"}
```
| 键 | 含义 |
|---|---|
| `gpus` | 仅在这些 GPU 编号上挖矿（默认：全部） |
| `worker` | 矿池上的矿工名（默认：取自钱包模板或矿机名称） |
| `per_gpu_workers` | `true` = 每块显卡在矿池上是独立的矿工 `rig.gpuN`；默认 `false` = 每台矿机一个矿工 |
| `model_dir` | 6.4 GB 模型的存放位置（默认 `/hive/miners/custom/cmfd-model`，与其他 CMFD 矿工共享） |
| `batch` | 每次 GPU 运行的前向计算数，1–64。省略 = 自动：11 GB 以上显卡为 64，8 GB 显卡为 32。在 RTX 4070 Ti 上实测：4→23.2，32→23.9，64→24.1 FW/s（GPU 时间）；在 RTX 3070 上差异在 1 % 以内 |

### 7. 超频（RTX 30）

Tensor Core 路径对 GPU 的负载远高于旧式矿工。在其他场景下稳定的参数，在这里可能导致 GPU
**悄悄返回错误结果**——此时矿工找不到有效份额，或矿池拒绝这些份额。

* 锁定核心频率并使用核心偏移，显存保持默认。建议从 **核心锁频 1560 MHz + 偏移 175** 开始
  （RTX 3070：1.2.x 约 20 FW/s；1.1 时约 14.6 FW/s）。只有在日志显示 `INTEGRITY | ok` 且
  **没有** `SHARE REJECTED` 时，才以 25 为步长提高偏移。在我们的显卡上，+275 和 +225 在部分 GPU 上出现错误，+175 稳定。
  每张卡都不一样：在 HiveOS 中可以为每张卡单独设置数值（`175 175 275 ...`）。
* **矿工运行时切勿更改频率。** 先设置超频，再（重新）启动矿工。
* **1.2.0 提示：** 融合内核对 GPU 的负载更密集。更新后请检查日志中是否有 `INTEGRITY | ok`，且没有被拒绝/无效的份额。如果某块大幅降压的显卡出现 `INTEGRITY ERROR` 或崩溃，请将其核心偏移降低 50。
* 默认频率始终安全（每块 RTX 3070 约 16.5 FW/s，约 250 W）。

### 8. 如何阅读日志

| 日志行 | 含义 |
|---|---|
| `MINER STATS | GPU n ... hashrate X FW/s | accepted A | rejected R | stale S ...` | 每 5 秒输出一次各 GPU 状态 |
| `INTEGRITY | ok` | 每第 128 个批次会用经典路径重新计算，结果一致 |
| `INTEGRITY | ERROR ...` | **GPU 计算结果错误**——请降低该显卡的偏移/频率 |
| `SHARE STALE` | 份额到达前区块已更换——无害，不计入被拒绝 |
| `SHARE NOT CREDITED` | 矿池端的状况（例如 `backend_unavailable`）——不是 GPU 问题 |
| `SHARE RETRY \| code=worker_busy` | 矿池正忙于处理同一矿工的另一个份额（每台矿机一个矿工）；份额会自动重发 |
| `SHARE REJECTED | code=...` | 矿池拒绝了该份额；反复被拒 = GPU 不稳定 |
| `DEV FEE | mining 36 s ...` / `DEV FEE | done` | 1 % 开发者抽水时间段 |

HiveOS 日志：`/var/log/miner/freeforgeminer/miner.log`，其旁边每块 GPU 各有一个文件。

### 9. 开发者抽水 — 1 %

每块 GPU 每小时有 36 秒，矿工会在同一矿池中向
`a6b0915b0620997b2606574726fcf05628da6dc9ae9f2ff5bffe6d0a33ea9f2c` 挖矿（矿工名 `ffm-fee`）。
每块 GPU 的时间段是随机的（一台矿机不会同时重连所有显卡）；如果矿池拒绝，则跳过该时段。
代码：`patches/0003-*`。

### 10. 故障排除

| 现象 | 解决办法 |
|---|---|
| `GLIBC_2.xx not found` | 使用 1.0.1 或更新的版本（为 Ubuntu 22.04 编译） |
| 1.2.0 或更早版本 CPU 占用/CPU 温度很高 | 更新到 1.2.1（将 Installation URL 改为新版本） |
| HiveOS 提示 `Already installed` 且没有任何变化 | Installation URL 必须指向新版本 |
| `worker temporarily banned` | 你的 IP 因被拒份额被矿池封禁：停止该 IP 下所有矿工约 1 小时，修正超频，先只启动一台矿机 |
| `INTEGRITY | ERROR` 或大量 `SHARE REJECTED` | 降低该 GPU 的核心偏移，重启矿工 |
| 模型下载失败 | 检查矿机的 DNS/网络；模型来自官方 Common Foundry CDN |
| Windows：算力只有 0.5-2 FW/s，而不是约 20 | 6.4 GB 模型放不进可用显存，Windows 把一部分挪到了内存：请关闭占用 GPU 的程序（本地 AI 模型、游戏、浏览器硬件加速）；可用显存少于约 7000 MiB 时 `start.bat` 会发出警告 |
| Windows：压缩包或 `.exe` 被 Defender / SmartScreen 拦截 | *更多信息 → 仍要运行*，或将矿工文件夹加入 Defender 排除项；请核对发布页面上的压缩包 SHA-256 |

### 11. 不使用 HiveOS 的 Linux

```bash
tar xzf freeforgeminer-X.Y.Z.tar.gz && cd freeforgeminer
./cmfd-miner pool --pool 'cmfd+tls://IP:PORT?pin=...' --miner YOUR_ADDRESS --worker rig01 --gpu 0 [--batch 32] \
  --production-v4-bank /path/to/MODEL-V2.bank --production-v4-replay-worker "$PWD/cmfd-v4-replay" \
  --production-v4-scratch /tmp/ffm-gpu0 --stats-seconds 5
```
每块 GPU 运行一个进程（`--gpu N`）。首次运行需要模型以及压缩包中的启动文件（`production-mainnet/`）。

### 12. Windows 10/11

原生 Windows 版本——无需 WSL、无需安装 CUDA、无需 Python。只需要 NVIDIA 驱动
（已在驱动 572.70、RTX 4070 Laptop 上测试：约 20 FW/s，与 Linux 版本逐位一致）。

1. 从发布页面下载 **`freeforgeminer-1.2.1-windows-x64.zip`**：
   `https://github.com/pepsykolya/freeforgeminer/releases/download/v1.2.1/freeforgeminer-1.2.1-windows-x64.zip`
2. 解压到**不含空格和非英文字符**的文件夹，例如 `C:\FreeForgeMiner`。
3. 右键点击 **`start.bat`** → *编辑*，并设置：

| 设置项 | 值 |
|---|---|
| `WALLET` | 你的 CMFD 地址（64 位十六进制字符） |
| `POOL` | 第 5 节中一个完整的 `cmfd+tls://…` URL（默认：cmfd-pool.online） |
| `WORKER` | 矿机名称，默认 = 计算机名 |
| `GPUS` | 留空 = 所有 NVIDIA 显卡，或类似 `0,1` 的列表（编号来自 `nvidia-smi`） |
| `BATCH` | 留空 = 自动，或 1-64 |
| `PER_GPU_WORKERS` | `0` = 这台电脑在矿池上是一个矿工，`1` = 每块 GPU 一个矿工 |

4. 双击 **`start.bat`**。首次启动会一次性下载 6.4 GB 模型（16 个并行分块，每个分块都经过
   SHA-256 校验，视网速约 10-30 分钟）。之后启动只需重新校验（约 1 分钟）。
5. 每块 GPU 运行一个矿工进程；它们的输出在同一窗口中显示为 `[GPU0] …`、`[GPU1] …`，并保存到
   `logs\gpuN.log`。进程退出后会在 15 秒后自动重启。`Ctrl+C` 停止全部。

* **显存：** 模型约占用 6.7 GB 显存。8 GB 显卡请关闭其他所有占用 GPU 的程序——如果放不下，Windows 会悄悄把一部分挪到系统内存，算力会降到约 0.5 FW/s。
* **超频：** 使用 MSI Afterburner（通过曲线编辑器锁定核心频率 + 核心偏移，显存保持默认）；第 7 节的规则完全适用。笔记本：接上充电器并选择最高性能模式。
* 开机自启：把 `start.bat` 的快捷方式放进 `shell:startup`。

---

### 更新日志

* **1.2.1** - 矿工在等待 GPU 期间不再让每块 GPU 占满一个 CPU 核心 100 %（CUDA blocking sync）：在 CPU 较弱的矿机上（例如 4 核 i5 带 6–8 块 GPU），CPU 占用和温度大幅下降。算力和结果不变。
* **1.2.0 Windows** - 1.2.0 的原生 Windows 10/11 x64 版本（无需 WSL）：`start.bat` 启动器、每块 GPU 一个进程、自动下载模型并自动重启。代码和结果与 Linux 版本相同。
* **1.2.0** - 新的融合 GEMM+reduce GPU 内核（int8 tensor cores，层归约在寄存器中完成）：GPU 基准测试中 RTX 3070 14.9 -> 20.0 FW/s (+34 %)，RTX 4070 Ti 26.1 -> 32.4 FW/s (+24 %)；矿池上 4070 Ti 25.6 -> 30.5 FW/s。与参考实现逐位一致（已验证确定性和摘要），GPU 显存占用约减少 4 倍。适用于 RTX 30/40/50 (sm_80+)；更老的 GPU 使用之前的路径。`CMFD_FUSED=-1` 可恢复旧内核。
* **1.1.1** - 日志横幅显示真实的发布版本号。
* **1.1.0** - 持久化搜索缓冲区，并去掉对每层激活/预激活值的无用写入。RTX 4070 Ti：23.7 -> 25.7 FW/s (+9 %, ~185 W)；RTX 3070：14.56 -> 14.69 FW/s (+1 %)。逐位一致（已验证确定性和摘要），矿池上 0 被拒绝 / 0 无效。
* **1.0.6** - 修正 batch 64 时的算力显示（12 GB 以上显卡）。
