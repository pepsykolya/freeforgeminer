@echo off
setlocal EnableExtensions
title FreeForgeMiner

rem ================================================================
rem  FreeForgeMiner for Windows - EDIT THESE VALUES
rem ================================================================
rem Your CMFD wallet address (64 hex characters)
set "WALLET="
rem Pool URL - one line from MANUAL.md section 5 (default: Aria / AriaBrain)
set "POOL=cmfd+tls://159.69.194.46:29445?pin=9dfb51083f287726117f689f87bc7a878792efcca58ca8b6f6e7c05ac5d152e9"
rem Worker (rig) name: 1-32 letters, numbers, dots, underscores, hyphens
set "WORKER=%COMPUTERNAME%"
rem GPUs to use: empty = all NVIDIA GPUs, or a list like 0,1,3 (indexes from nvidia-smi)
set "GPUS="
rem Forwards per GPU pass: empty = automatic, or 1-64
set "BATCH="
rem 0 = the whole PC is one worker on the pool, 1 = one worker per GPU (WORKER.gpuN)
set "PER_GPU_WORKERS=0"
rem speed = maximum hashrate (default), eco = fewer watts (RTX 30: about -13 % power, -2 % hashrate; faster at a power limit). RTX 40/50: same kernel in both modes
set "MODE=speed"
rem ================================================================

set "PS=powershell.exe"
where pwsh.exe >nul 2>&1 && set "PS=pwsh.exe"
"%PS%" -NoProfile -ExecutionPolicy Bypass -File "%~dp0start.ps1" -Wallet "%WALLET%" -Pool "%POOL%" -Worker "%WORKER%" -Gpus "%GPUS%" -Batch "%BATCH%" -PerGpuWorkers "%PER_GPU_WORKERS%" -Mode "%MODE%"
echo.
echo FreeForgeMiner stopped (exit code %ERRORLEVEL%).
pause
