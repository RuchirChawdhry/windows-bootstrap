#Requires -Version 7.0

# Run from a non-admin PowerShell window:
# pwsh -NoProfile -ExecutionPolicy Bypass -File .\bootstrap.ps1
[CmdletBinding()]
param(
    [string]$ConfigPath = "$PSScriptRoot\packages.yaml"
)

$ErrorActionPreference = 'Stop'

function Invoke-Scoop {
    & $scoopCommand @args
    if ($LASTEXITCODE -ne 0) {
        throw "scoop $args failed (exit code $LASTEXITCODE)."
    }
}

$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = [Security.Principal.WindowsPrincipal]::new($identity)
if ($principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw 'Run this script in a non-admin PowerShell window. App installers can request elevation themselves.'
}
if (-not (Test-Path -LiteralPath $ConfigPath -PathType Leaf)) {
    throw "Config not found: $ConfigPath"
}

Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned -Force

$needsWinGet = -not (Get-Command winget.exe -ErrorAction SilentlyContinue)
$modules = @(
    'powershell-yaml'
    if ($needsWinGet) { 'Microsoft.WinGet.Client' }
)
& "$PSScriptRoot\install-modules.ps1" -Name $modules
$config = Get-Content -LiteralPath $ConfigPath -Raw | ConvertFrom-Yaml

if ($needsWinGet) {
    Repair-WinGetPackageManager
}

$env:SCOOP = "$HOME\Tools\Scoop"
[Environment]::SetEnvironmentVariable('SCOOP', $env:SCOOP, 'User')
$scoopShims = "$env:SCOOP\shims"
$scoopCommand = "$scoopShims\scoop.cmd"
if (-not (Test-Path -LiteralPath $scoopCommand)) {
    $installer = [scriptblock]::Create(
        (Invoke-RestMethod -Uri 'https://get.scoop.sh')
    )
    & $installer -ScoopDir $env:SCOOP
    if (-not (Test-Path -LiteralPath $scoopCommand)) {
        throw 'Scoop installation failed.'
    }
}
$env:Path = "$scoopShims;$env:Path"

# Git is needed to add and update Scoop buckets.
if (-not (Get-Command git.exe -ErrorAction SilentlyContinue)) {
    Invoke-Scoop install git
}
foreach ($bucket in $config.scoop.buckets) {
    if (-not (Test-Path -LiteralPath "$env:SCOOP\buckets\$bucket")) {
        Invoke-Scoop bucket add $bucket
    }
}
foreach ($package in $config.scoop.packages) {
    Invoke-Scoop install $package
}
$wingetOptions = @(
    '--exact'
    '--source', 'winget'
    '--accept-package-agreements'
    '--accept-source-agreements'
    '--no-upgrade'
)
# APP_UPDATE_NOT_APPLICABLE: the app is already installed.
$noApplicableUpgrade = -1978335189
foreach ($package in $config.winget.packages) {
    winget.exe install --id $package @wingetOptions
    if ($LASTEXITCODE -notin @(0, $noApplicableUpgrade)) {
        throw "WinGet installation failed for $package (exit code $LASTEXITCODE)."
    }
}

Write-Host 'Bootstrap complete. Open a new terminal to pick up environment changes.'
