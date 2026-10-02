[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string[]]$Name
)

$ErrorActionPreference = 'Stop'

$moduleDir = Join-Path $HOME 'Tools\PowerShell\Modules'
New-Item -ItemType Directory -Path $moduleDir -Force | Out-Null
$userModulePath = [Environment]::GetEnvironmentVariable('PSModulePath', 'User')
$userModulePaths = @($moduleDir) + @($userModulePath -split ';' | Where-Object { $_ -and $_ -ne $moduleDir })
[Environment]::SetEnvironmentVariable('PSModulePath', ($userModulePaths -join ';'), 'User')
$env:PSModulePath = (@($moduleDir) + @($env:PSModulePath -split ';' | Where-Object { $_ -and $_ -ne $moduleDir })) -join ';'

if (-not (Get-PackageProvider -Name NuGet -ListAvailable -ErrorAction SilentlyContinue |
        Where-Object { $_.Version -ge [version]'2.8.5.201' })) {
    Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Scope CurrentUser -Force | Out-Null
}

# Save-Module supports a custom destination; Install-Module -Scope CurrentUser
# still targets Documents. Use this script for additional modules here too.
foreach ($moduleName in $Name) {
    $modulePath = Join-Path $moduleDir $moduleName
    if (-not (Test-Path -LiteralPath $modulePath)) {
        Save-Module -Name $moduleName -Repository PSGallery -Path $moduleDir -Force
    }
    # Keep commands available to bootstrap.ps1 after this script returns.
    Import-Module $modulePath -Global -Force
}
