#Requires -Version 7.4
param([string[]]$Name = @('Yayaml'))

$path = "$HOME/Tools/PowerShell/Modules"
New-Item $path -ItemType Directory -Force | Out-Null
$Name | ForEach-Object { Save-Module $_ -Path $path -Force }
