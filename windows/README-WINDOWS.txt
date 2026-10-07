FreeForgeMiner for Windows 10/11 (x64) - CMFD / ForgeMatrix V4 miner for NVIDIA GPUs
Full manual (EN/RU): https://github.com/pepsykolya/freeforgeminer/blob/main/MANUAL.md#12-windows-1011

QUICK START
1. Unpack this archive to a folder without spaces or non-English letters, e.g. C:\FreeForgeMiner
2. Right-click start.bat -> Edit. Set WALLET (your 64-character CMFD address), POOL (one URL from the
   list below) and optionally WORKER, GPUS, BATCH. Save.
3. Double-click start.bat. First start downloads the 6.4 GB model once (verified), then mining starts.
   Logs: logs\gpuN.log. Ctrl+C stops the miner.

Needs only the NVIDIA driver (no CUDA, no Python, no WSL). The model needs ~6.7 GB of free VRAM:
on 8 GB cards close programs that use the GPU, otherwise the hashrate will be very low.

POOLS (copy one line into POOL)
cmfd-pool.online (3 %):  cmfd+tls://109.199.124.187:29465?pin=ebe88f5e05f3a222208d551d05b6d39057b64ce8239ba7a708d487e15ac711be
Aria / AriaBrain (3 %):  cmfd+tls://159.69.194.46:29445?pin=9dfb51083f287726117f689f87bc7a878792efcca58ca8b6f6e7c05ac5d152e9
NurseryPool (1 %):       cmfd+tls://162.19.84.16:29445?pin=f61b1a26bebc257d95dad2e770ac15f229659ad85597f65c78293a3c1259c6a6

DEV FEE 1 %: 36 s per hour per GPU to a6b0915b0620997b2606574726fcf05628da6dc9ae9f2ff5bffe6d0a33ea9f2c
on the same pool (worker ffm-fee). Open source (MIT): https://github.com/pepsykolya/freeforgeminer

------------------------------------------------------------------------------------------------
FreeForgeMiner для Windows 10/11 (x64)

БЫСТРЫЙ СТАРТ
1. Распакуйте архив в папку без пробелов и русских букв, например C:\FreeForgeMiner
2. Правой кнопкой по start.bat -> Изменить. Задайте WALLET (ваш 64-символьный CMFD-адрес), POOL (строка из
   списка пулов выше) и при желании WORKER, GPUS, BATCH. Сохраните.
3. Запустите start.bat. При первом запуске модель 6,4 ГБ скачается один раз (с проверкой), затем начнётся майнинг.
   Логи: logs\gpuN.log. Ctrl+C - остановка.

Нужен только драйвер NVIDIA (CUDA, Python и WSL не нужны). Модели нужно ~6,7 ГБ свободной видеопамяти:
на картах 8 ГБ закройте программы, использующие видеокарту, иначе хешрейт будет очень низким.
Если Defender/SmartScreen блокирует запуск: "Подробнее -> Выполнить в любом случае" или добавьте папку в исключения.
