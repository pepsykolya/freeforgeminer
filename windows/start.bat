@echo off
setlocal EnableExtensions
title FreeForgeMiner

rem ================================================================
rem  FreeForgeMiner for Windows - EDIT THESE VALUES
rem ================================================================
rem Your CMFD wallet address (64 hex characters)
set "WALLET="
rem Pool URL - one line from MANUAL.md section 5 (default: cmfd-pool.online)
set "POOL=cmfd+tls://109.199.124.187:29465?pin=ebe88f5e05f3a222208d551d05b6d39057b64ce8239ba7a708d487e15ac711be"
rem Worker (rig) name: 1-32 letters, numbers, dots, underscores, hyphens
set "WORKER=%COMPUTERNAME%"
rem GPUs to use: empty = all NVIDIA GPUs, or a list like 0,1,3 (indexes from nvidia-smi)
set "GPUS="
rem Forwards per GPU pass: empty = automatic, or 1-64
set "BATCH="
rem 0 = the whole PC is one worker on the pool, 1 = one worker per GPU (WORKER.gpuN)
set "PER_GPU_WORKERS=0"
rem ================================================================

set "PS=powershell.exe"
where pwsh.exe >nul 2>&1 && set "PS=pwsh.exe"
"%PS%" -NoProfile -ExecutionPolicy Bypass -File "%~dp0start.ps1" -Wallet "%WALLET%" -Pool "%POOL%" -Worker "%WORKER%" -Gpus "%GPUS%" -Batch "%BATCH%" -PerGpuWorkers "%PER_GPU_WORKERS%"
echo.
echo FreeForgeMiner stopped (exit code %ERRORLEVEL%).
pause
