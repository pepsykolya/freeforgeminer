# Build cmfd-miner.exe (FreeForgeMiner, Windows x64)
$ErrorActionPreference = 'Stop'
$vs = & "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe" -products * -latest -property installationPath
Import-Module "$vs\Common7\Tools\Microsoft.VisualStudio.DevShell.dll"
Enter-VsDevShell -VsInstallPath $vs -SkipAutomaticLocation -DevCmdArguments '-arch=x64 -host_arch=x64' | Out-Null
$env:PATH = "$env:USERPROFILE\.cargo\bin;C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v12.9\bin;$env:PATH"
$env:CUDA_PATH = 'C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v12.9'
Set-Location "$PSScriptRoot\CommonFoundry"
$env:CMFD_BUILD_SOURCE_COMMIT = (git rev-parse HEAD).Trim()
$env:RUSTFLAGS = '-C target-feature=+crt-static'
rustup show active-toolchain
cargo build --release -p cmfd-miner --features production-mainnet 2>&1
if ($LASTEXITCODE -ne 0) { throw "cargo failed: $LASTEXITCODE" }
Get-Item target\release\cmfd-miner.exe | Select-Object Name, Length
