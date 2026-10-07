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
| RTX 30xx (Ampere, sm_86) | Ampere Tensor Core path + GPU digest | **main target, tested** |
| RTX 40xx (Ada, sm_89) | GPU digest only (upstream already used the fast path) | tested on RTX 4070 Ti: 23.7 FW/s — **CMFD GPU miner r13 is currently faster on this card (25.9 FW/s)** |
| RTX 20xx (Turing), RTX 50xx (Blackwell), Volta, Hopper | GPU digest | built, not yet tested by us |

### 2. Measured performance

All numbers are real measurements, with the conditions stated.

| Test | Official / other miner | FreeForgeMiner |
|---|---|---|
| 1× RTX 3070, PCIe x1, stock clocks, full cycle (bench, 2026-10-07) | official Common Foundry code: **10.3 FW/s** | **16.4–16.9 FW/s** |
| Rig 8× RTX 3070, core lock 1560 MHz, hashrate reported to cmfd-pool.online (2026-10-07) | CMFD GPU miner r13 (lucasan123): **113.2 FW/s** | **116.7 FW/s** |

Results are bit-for-bit identical to upstream and shares are accepted by the pools
(cmfd-pool.online, Aria) with 0 invalid proofs. The pool's *effective* hashrate is computed from shares over time;
compare effective hashrate over several hours, not minutes.

### 3. Requirements

* NVIDIA GPU with **8 GB VRAM or more**.
* NVIDIA driver **R575 or newer** (CUDA 12.9 runtime is bundled).
* HiveOS (Ubuntu 22.04 based) or any Linux x86_64 with glibc 2.34+.
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
{"gpus":[0,1,2], "worker":"rig01", "per_gpu_workers":false, "model_dir":"/hive/miners/custom/cmfd-model"}
```
| Key | Meaning |
|---|---|
| `gpus` | mine only on these GPU indices (default: all) |
| `worker` | worker name on the pool (default: from the wallet template or the rig name) |
| `per_gpu_workers` | `true` = each card is a separate worker `rig.gpuN` on the pool; default `false` = one worker per rig |
| `model_dir` | where the 6.4 GB model lives (default `/hive/miners/custom/cmfd-model`, shared with other CMFD miners) |

### 7. Overclocking (RTX 30)

The Tensor Core path loads the GPU much harder than older miners. A profile that is stable elsewhere can make the GPU
**return wrong results silently** — the miner then finds no valid shares or the pool rejects them.

* Lock the core clock and use a core offset, memory stock. Start with **core lock 1560 MHz + offset 175**
  (~150 W per RTX 3070, ~14.6 FW/s). Raise the offset in steps of 25 only while the log shows `INTEGRITY | ok`
  and **no** `SHARE REJECTED`. On our cards +275 and +225 caused errors on some GPUs, +175 was stable.
  Each card is different: in HiveOS you can set a value per card (`175 175 275 ...`).
* **Never change clocks while the miner is running.** Set OC, then (re)start the miner.
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
| HiveOS says `Already installed` and nothing changes | the Installation URL must point to a new version |
| `worker temporarily banned` | your IP is banned by the pool for rejected shares: stop all miners on that IP for ~1 hour, fix OC, start one rig first |
| `INTEGRITY | ERROR` or many `SHARE REJECTED` | lower the core offset of that GPU, restart the miner |
| model download fails | check DNS/internet on the rig; the model comes from the official Common Foundry CDN |

### 11. Linux without HiveOS

```bash
tar xzf freeforgeminer-X.Y.Z.tar.gz && cd freeforgeminer
./cmfd-miner pool --pool 'cmfd+tls://IP:PORT?pin=...' --miner YOUR_ADDRESS --worker rig01 --gpu 0 \
  --production-v4-bank /path/to/MODEL-V2.bank --production-v4-replay-worker "$PWD/cmfd-v4-replay" \
  --production-v4-scratch /tmp/ffm-gpu0 --stats-seconds 5
```
Run one process per GPU (`--gpu N`). The first run needs the model and the launch files (`production-mainnet/`) from the archive.

---

## Русский

### 1. Что это

FreeForgeMiner — майнер с открытым кодом для **Common Foundry (CMFD, ForgeMatrix V4)** на видеокартах NVIDIA.
Это форк официального майнера Common Foundry (лицензия MIT): тот же консенсус, та же модель 6,4 ГБ, но быстрее на GPU.
Все изменения относительно официального кода лежат в [`patches/`](patches), включая код комиссии.

**Лучше всего подходит для RTX 30-й серии (Ampere).** Официальный код гоняет 30-ю серию по старому пути тензорных ядер
(как у Turing); FreeForgeMiner переводит её на путь Ampere и считает финальный хеш BLAKE3 прямо на видеокарте.

| Серия | Что даёт FreeForgeMiner | Статус |
|---|---|---|
| RTX 30xx (Ampere) | путь Ampere на тензорных ядрах + хеш на GPU | **основная цель, проверено** |
| RTX 40xx (Ada) | только хеш на GPU (быстрый путь у официального кода уже был) | проверено на RTX 4070 Ti: 23,7 FW/s — **CMFD GPU miner r13 на этой карте сейчас быстрее (25,9 FW/s)** |
| RTX 20xx, RTX 50xx, Volta, Hopper | хеш на GPU | собрано, нами пока не проверялось |

### 2. Измеренная производительность

Только реальные замеры, с условиями.

| Замер | Официальный / другой майнер | FreeForgeMiner |
|---|---|---|
| 1× RTX 3070, PCIe x1, сток, полный цикл (стенд, 07.10.2026) | официальный код Common Foundry: **10,3 FW/s** | **16,4–16,9 FW/s** |
| Риг 8× RTX 3070, фиксация ядра 1560 МГц, мощность на cmfd-pool.online (07.10.2026) | CMFD GPU miner r13 (lucasan123): **113,2 FW/s** | **116,7 FW/s** |

Результаты побитово совпадают с официальными, пулы (cmfd-pool.online, Aria) принимают шары, ошибочных доказательств 0.
Эффективную мощность пул считает по шарам за время — сравнивайте её за несколько часов, а не минут.

### 3. Требования

* Видеокарта NVIDIA с **8 ГБ памяти и больше**.
* Драйвер NVIDIA **R575 или новее** (среда CUDA 12.9 уже внутри архива).
* HiveOS (на базе Ubuntu 22.04) или любой Linux x86_64 с glibc 2.34+.
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
{"gpus":[0,1,2], "worker":"rig01", "per_gpu_workers":false, "model_dir":"/hive/miners/custom/cmfd-model"}
```
| Ключ | Что делает |
|---|---|
| `gpus` | майнить только на этих картах (по умолчанию — на всех) |
| `worker` | имя воркера на пуле (по умолчанию — из шаблона кошелька или имя рига) |
| `per_gpu_workers` | `true` — каждая карта отдельным воркером `rig.gpuN` на пуле; по умолчанию `false` — один воркер на риг |
| `model_dir` | где лежит модель 6,4 ГБ (по умолчанию `/hive/miners/custom/cmfd-model`, общая с другими CMFD-майнерами) |

### 7. Разгон (RTX 30)

Путь тензорных ядер нагружает карту сильнее, чем старые майнеры. Профиль, стабильный в другом майнере, может заставить
карту **молча считать неправильно** — тогда майнер не находит верных шар или пул их отклоняет.

* Фиксация частоты ядра + смещение, память — сток. Начинайте с **фиксации 1560 МГц и смещения +175**
  (~150 Вт на RTX 3070, ~14,6 FW/s). Повышайте смещение шагами по 25, только пока в логе `INTEGRITY | ok`
  и **нет** `SHARE REJECTED`. На наших картах +275 и +225 давали ошибки на части GPU, +175 — стабильно.
  Каждая карта своя: в HiveOS можно задать значение для каждой карты (`175 175 275 ...`).
* **Не меняйте частоты при работающем майнере.** Сначала разгон, потом (пере)запуск майнера.
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
| HiveOS пишет `Already installed`, ничего не меняется | в Installation URL должна быть новая версия |
| `worker temporarily banned` | ваш IP забанен пулом за отклонённые шары: остановите все майнеры за этим IP примерно на час, исправьте разгон, запускайте сначала один риг |
| `INTEGRITY | ERROR` или много `SHARE REJECTED` | снизьте смещение этой карте, перезапустите майнер |
| не качается модель | проверьте DNS/интернет на риге; модель берётся с официального CDN Common Foundry |

### 11. Linux без HiveOS

```bash
tar xzf freeforgeminer-X.Y.Z.tar.gz && cd freeforgeminer
./cmfd-miner pool --pool 'cmfd+tls://IP:PORT?pin=...' --miner ВАШ_АДРЕС --worker rig01 --gpu 0 \
  --production-v4-bank /путь/к/MODEL-V2.bank --production-v4-replay-worker "$PWD/cmfd-v4-replay" \
  --production-v4-scratch /tmp/ffm-gpu0 --stats-seconds 5
```
По процессу на каждую карту (`--gpu N`). Для первого запуска нужны модель и файлы запуска сети (`production-mainnet/`) из архива.
