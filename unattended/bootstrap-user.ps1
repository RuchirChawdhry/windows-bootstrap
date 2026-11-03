#Requires -Version 7.4
$ErrorActionPreference = "Stop"
& "$PSScriptRoot/../bootstrap.ps1" *> "$PSScriptRoot/../bootstrap.log"
exit $LASTEXITCODE
