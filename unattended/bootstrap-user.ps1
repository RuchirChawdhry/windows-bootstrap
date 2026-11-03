#Requires -Version 7.4
$ErrorActionPreference = "Stop"
& "$PSScriptRoot/../bootstrap.ps1" *> "$env:LOCALAPPDATA/windows-bootstrap.log"
exit $LASTEXITCODE
