#Requires -Version 7.0

$ErrorActionPreference = 'Stop'
$env:SCOOP = "$HOME\Tools\Scoop"
[Environment]::SetEnvironmentVariable('SCOOP', $env:SCOOP, 'User')

$scoop = "$env:SCOOP\shims\scoop.cmd"
if (-not (Test-Path $scoop)) {
    Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
    & ([scriptblock]::Create((Invoke-RestMethod 'https://get.scoop.sh'))) -ScoopDir $env:SCOOP
}
$env:Path = "$env:SCOOP\shims;$env:Path"
if (-not (Get-Command task.exe -EA Ignore)) { & $scoop install task }
& task.exe --taskfile "$PSScriptRoot\Taskfile.yml" bootstrap
exit $LASTEXITCODE
