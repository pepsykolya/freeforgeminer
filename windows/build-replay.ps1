# Build cmfd-v4-replay.exe (native Windows CUDA worker)
# usage: build-replay.ps1 [-Archs "89"|"all"] [-Out path]
param([string]$Archs = "89", [string]$Out = "$PSScriptRoot\out\cmfd-v4-replay.exe")
$ErrorActionPreference = 'Stop'
$vs = & "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe" -products * -latest -property installationPath
Import-Module "$vs\Common7\Tools\Microsoft.VisualStudio.DevShell.dll"
Enter-VsDevShell -VsInstallPath $vs -SkipAutomaticLocation -DevCmdArguments '-arch=x64 -host_arch=x64' | Out-Null
$nvcc = 'C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v12.9\bin\nvcc.exe'
$src = "$PSScriptRoot\CommonFoundry\tools\production-v4-prover\cuda\koala_four_limb_replay.cu"
$list = if ($Archs -eq 'all') { @('70','75','80','86','89','90','120') } else { $Archs -split ',' }
$gen = @()
foreach ($a in $list) { $gen += "--generate-code=arch=compute_$a,code=sm_$a" }
if ($Archs -eq 'all') { $gen += '--generate-code=arch=compute_70,code=compute_70' }
New-Item -ItemType Directory -Force -Path (Split-Path $Out) | Out-Null
& $nvcc -O3 -std=c++17 --cudart static @gen -I "$PSScriptRoot\cutlass\include" `
    -Xcompiler "/EHsc /O2 /MT /Zc:__cplusplus" -diag-suppress 20012,20013,20014,20015 $src -o $Out
if ($LASTEXITCODE -ne 0) { throw "nvcc failed: $LASTEXITCODE" }
Get-Item $Out | Select-Object Name, Length
