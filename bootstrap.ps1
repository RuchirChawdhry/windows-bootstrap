# Run from a non-admin PowerShell window:
# powershell -NoProfile -ExecutionPolicy Bypass -File .\bootstrap.ps1
[CmdletBinding()]
param(
    [string]$ConfigPath = (Join-Path $PSScriptRoot 'packages.yaml')
)

$ErrorActionPreference = 'Stop'

$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = [Security.Principal.WindowsPrincipal]::new($identity)
if ($principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw 'Run this script in a non-admin PowerShell window. App installers can request elevation themselves.'
}
if (-not (Test-Path -LiteralPath $ConfigPath -PathType Leaf)) {
    throw "Config not found: $ConfigPath"
}

Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned -Force
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

& (Join-Path $PSScriptRoot 'install-modules.ps1') -Name powershell-yaml
$config = Get-Content -LiteralPath $ConfigPath -Raw | ConvertFrom-Yaml

if (-not (Get-Command winget.exe -ErrorAction SilentlyContinue)) {
    & (Join-Path $PSScriptRoot 'install-modules.ps1') -Name Microsoft.WinGet.Client
    Repair-WinGetPackageManager
}

$env:SCOOP = Join-Path $HOME 'Tools\Scoop'
[Environment]::SetEnvironmentVariable('SCOOP', $env:SCOOP, 'User')
$scoopCommand = Join-Path $env:SCOOP 'shims\scoop.cmd'
if (-not (Test-Path -LiteralPath $scoopCommand)) {
    $installer = Join-Path ([IO.Path]::GetTempPath()) "scoop-install-$([guid]::NewGuid()).ps1"
    try {
        Invoke-RestMethod -Uri 'https://get.scoop.sh' -OutFile $installer
        & $installer -ScoopDir $env:SCOOP
        if (-not (Test-Path -LiteralPath $scoopCommand)) {
            throw 'Scoop installation failed.'
        }
    }
    finally {
        Remove-Item -LiteralPath $installer -ErrorAction SilentlyContinue
    }
}
$env:Path = "$(Join-Path $env:SCOOP 'shims');$env:Path"

function Invoke-Scoop {
    & $scoopCommand @args
    if ($LASTEXITCODE -ne 0) {
        throw "scoop $args failed (exit code $LASTEXITCODE)."
    }
}

# Git is needed to add and update Scoop buckets.
if (-not (Get-Command git.exe -ErrorAction SilentlyContinue)) {
    Invoke-Scoop install git
}
foreach ($bucket in $config.scoop.buckets) {
    if (-not (Test-Path -LiteralPath (Join-Path $env:SCOOP "buckets\$bucket"))) {
        Invoke-Scoop bucket add $bucket
    }
}
foreach ($package in $config.scoop.packages) {
    Invoke-Scoop install $package
}
foreach ($package in $config.winget.packages) {
    & winget.exe install --id $package --exact --source winget --accept-package-agreements --accept-source-agreements --no-upgrade
    # WinGet returns APP_UPDATE_NOT_APPLICABLE for an already installed app.
    if ($LASTEXITCODE -notin @(0, -1978335189)) {
        throw "WinGet installation failed for $package (exit code $LASTEXITCODE)."
    }
}

Write-Host 'Bootstrap complete. Open a new terminal to pick up environment changes.'
