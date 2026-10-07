#requires -Version 5.1
# FreeForgeMiner for Windows: prepares the model once, then runs one native miner process per GPU,
# merges their output into this window and restarts a process that exits.
[CmdletBinding()]
param(
    [string]$Wallet,
    [string]$Pool,
    [string]$Worker = $env:COMPUTERNAME,
    [string]$Gpus = '',
    [string]$Batch = '',
    [string]$PerGpuWorkers = '0'
)
$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
Set-Location -LiteralPath $root

function Fail([string]$message) { Write-Host "ERROR: $message" -ForegroundColor Red; exit 1 }

if ($root -match '\s|[^\x00-\x7F]') {
    Write-Host "WARNING: the folder path contains spaces or non-English letters: $root" -ForegroundColor Yellow
    Write-Host "         If the miner fails to start, move the folder to e.g. C:\FreeForgeMiner" -ForegroundColor Yellow
}
if ([string]::IsNullOrWhiteSpace($Wallet)) {
    Write-Host 'WALLET is empty. Right-click start.bat -> Edit, and set WALLET to your 64-character CMFD address.'
    $Wallet = (Read-Host 'Or paste the wallet address now').Trim()
}
if ($Wallet -cnotmatch '^[0-9a-fA-F]{64}$') { Fail 'WALLET must be exactly 64 hexadecimal characters.' }
if ($Pool -cnotmatch '^cmfd\+tls://[0-9]{1,3}(\.[0-9]{1,3}){3}:[0-9]{1,5}\?pin=[0-9A-Fa-f]{64}$') {
    Fail 'POOL must look like cmfd+tls://IP:PORT?pin=64_HEX (see MANUAL.md, section 5).'
}
if ([string]::IsNullOrWhiteSpace($Worker)) { $Worker = 'rig' }
$Worker = ($Worker.Trim() -replace '[^A-Za-z0-9._-]', '-')
if ($Worker.Length -gt 32) { $Worker = $Worker.Substring(0, 32) }
if ($Batch -and ($Batch -notmatch '^\d+$' -or [int]$Batch -lt 1 -or [int]$Batch -gt 64)) { Fail 'BATCH must be empty or 1-64.' }

foreach ($file in 'cmfd-miner.exe', 'cmfd-v4-replay.exe', 'PREPARE-V4-INPUTS.ps1', 'production-mainnet\LAUNCH-BEACON.json') {
    if (-not (Test-Path -LiteralPath (Join-Path $root $file))) { Fail "$file is missing - unpack the whole archive again." }
}

$smi = Get-Command nvidia-smi.exe -ErrorAction SilentlyContinue
if (-not $smi) { Fail 'nvidia-smi.exe not found - install the NVIDIA driver (R550 or newer).' }
$all = @(& $smi.Source --query-gpu=index,uuid,name,memory.free --format=csv,noheader,nounits | ForEach-Object {
    $parts = $_ -split ',\s*'
    [pscustomobject]@{ Index = [int]$parts[0]; Uuid = $parts[1].Trim(); Name = $parts[2].Trim(); FreeMiB = [int]$parts[3] }
})
if ($all.Count -eq 0) { Fail 'No NVIDIA GPU found.' }
$selected = if ([string]::IsNullOrWhiteSpace($Gpus)) { $all } else {
    $wanted = $Gpus -split '[,\s]+' | Where-Object { $_ } | ForEach-Object { [int]$_ }
    $all | Where-Object { $wanted -contains $_.Index }
}
if (@($selected).Count -eq 0) { Fail "GPUS=$Gpus matches no GPU. Available: $(($all | ForEach-Object { $_.Index }) -join ',')" }

Write-Host "FreeForgeMiner for Windows - wallet $($Wallet.Substring(0,8))..., worker $Worker"
foreach ($g in $selected) {
    Write-Host ("  GPU {0}: {1}, {2} MiB free" -f $g.Index, $g.Name, $g.FreeMiB)
    # The model alone takes 6.4 GB of VRAM. If it does not fit, Windows silently moves part of it
    # to system RAM and the hashrate drops 20-40x instead of failing.
    if ($g.FreeMiB -lt 7000) {
        Write-Host ("  WARNING: GPU {0} has only {1} MiB free VRAM, ~7000 MiB are needed. Close programs that use" -f $g.Index, $g.FreeMiB) -ForegroundColor Yellow
        Write-Host '           the GPU (local AI models, games, video editors, browser hardware acceleration),' -ForegroundColor Yellow
        Write-Host '           otherwise the hashrate will be very low.' -ForegroundColor Yellow
    }
}

# Model: 6.4 GB, downloaded once in authenticated parts and verified (official Common Foundry script).
$inputs = Join-Path $root 'inputs'
& (Join-Path $root 'PREPARE-V4-INPUTS.ps1') -Role PoolMiner -Destination $inputs `
    -FallbackReleaseBase 'https://github.com/JustAResearcher/CommonFoundry-Binaries/releases/download/v0.1.0-devnet.16'
$bank = Join-Path $inputs 'MODEL-V2.bank'
if (-not (Test-Path -LiteralPath $bank)) { Fail 'Model preparation did not produce inputs\MODEL-V2.bank.' }

$env:FFM_SINGLE_WORKER = if ($PerGpuWorkers -eq '1') { '0' } else { '1' }
$logs = Join-Path $root 'logs'
New-Item -ItemType Directory -Force -Path $logs | Out-Null

$miners = @{}
function Start-Gpu($g) {
    $scratch = Join-Path $root "work\gpu$($g.Index)"
    New-Item -ItemType Directory -Force -Path $scratch | Out-Null
    $out = Join-Path $logs "gpu$($g.Index).log"
    $err = Join-Path $logs "gpu$($g.Index).err.log"
    $arguments = @('pool', '--pool', $Pool, '--miner', $Wallet, '--worker', $Worker, '--gpu', $g.Uuid,
        '--production-v4-bank', "`"$bank`"", '--production-v4-replay-worker', "`"$(Join-Path $root 'cmfd-v4-replay.exe')`"",
        '--production-v4-scratch', "`"$scratch`"", '--stats-seconds', '10')
    if ($Batch) { $arguments += @('--batch', $Batch) }
    $process = Start-Process -FilePath (Join-Path $root 'cmfd-miner.exe') -ArgumentList $arguments -WorkingDirectory $root `
        -NoNewWindow -PassThru -RedirectStandardOutput $out -RedirectStandardError $err
    $streams = foreach ($path in $out, $err) {
        $fs = [IO.File]::Open($path, 'OpenOrCreate', 'Read', 'ReadWrite, Delete')
        New-Object IO.StreamReader($fs)
    }
    $miners[$g.Index] = [pscustomobject]@{ Gpu = $g; Process = $process; Readers = $streams; Started = Get-Date }
}

$colors = 'Cyan', 'Green', 'Yellow', 'Magenta', 'White', 'Blue', 'DarkCyan', 'DarkGreen'
try {
    foreach ($g in $selected) { Start-Gpu $g }
    Write-Host 'Mining. Press Ctrl+C to stop. Logs: logs\gpuN.log'
    while ($true) {
        foreach ($m in @($miners.Values)) {
            foreach ($reader in $m.Readers) {
                while ($null -ne ($line = $reader.ReadLine())) {
                    $color = $colors[$m.Gpu.Index % $colors.Count]
                    if ($line -match 'ERROR|error|REJECTED|INVALID') { $color = 'Red' }
                    Write-Host ("[GPU{0}] {1}" -f $m.Gpu.Index, $line) -ForegroundColor $color
                }
            }
            if ($m.Process.HasExited) {
                Write-Host ("[GPU{0}] miner exited (code {1}), restarting in 15 s" -f $m.Gpu.Index, $m.Process.ExitCode) -ForegroundColor Red
                foreach ($reader in $m.Readers) { $reader.Dispose() }
                Start-Sleep -Seconds 15
                Start-Gpu $m.Gpu
            }
        }
        Start-Sleep -Milliseconds 500
    }
} finally {
    foreach ($m in @($miners.Values)) {
        if (-not $m.Process.HasExited) { Stop-Process -Id $m.Process.Id -Force -ErrorAction SilentlyContinue }
        Get-CimInstance Win32_Process -Filter "ParentProcessId=$($m.Process.Id)" -ErrorAction SilentlyContinue |
            ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
        foreach ($reader in $m.Readers) { $reader.Dispose() }
    }
}
