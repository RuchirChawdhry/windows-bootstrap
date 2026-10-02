#Requires -Version 7.0

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string[]]$Name
)

$ErrorActionPreference = 'Stop'

$moduleDir = "$HOME\Tools\PowerShell\Modules"
New-Item -ItemType Directory -Path $moduleDir -Force | Out-Null

$userPaths = [Environment]::GetEnvironmentVariable('PSModulePath', 'User') -split ';'
if ($moduleDir -notin $userPaths) {
    $userModulePath = (@($moduleDir) + $userPaths | Where-Object { $_ }) -join ';'
    [Environment]::SetEnvironmentVariable('PSModulePath', $userModulePath, 'User')
}
if ($moduleDir -notin ($env:PSModulePath -split ';')) {
    $env:PSModulePath = "$moduleDir;$env:PSModulePath"
}

if (-not (Get-PackageProvider -Name NuGet -ListAvailable -ErrorAction SilentlyContinue |
        Where-Object { $_.Version -ge [version]'2.8.5.201' })) {
    Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Scope CurrentUser -Force | Out-Null
}

# Save-Module supports a custom destination; Install-Module -Scope CurrentUser
# still targets Documents. Use this script for additional modules here too.
$saveOptions = @{
    Repository = 'PSGallery'
    Path       = $moduleDir
    Force      = $true
}
foreach ($moduleName in $Name) {
    $modulePath = "$moduleDir\$moduleName"
    if (-not (Test-Path -LiteralPath $modulePath)) {
        Save-Module -Name $moduleName @saveOptions
    }
    # Keep commands available to bootstrap.ps1 after this script returns.
    Import-Module $modulePath -Global -Force
}
