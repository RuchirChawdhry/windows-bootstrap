#Requires -Version 7.4

$env:SCOOP = "$HOME/Tools/Scoop"
[Environment]::SetEnvironmentVariable('SCOOP', $env:SCOOP, 'User')
$env:Path = "$env:SCOOP/shims;$env:Path"
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
(Get-Command scoop -EA Ignore) ? $null : (irm get.scoop.sh | iex)
(Get-Command task -EA Ignore) ? $null : (scoop install task)
task --taskfile "$PSScriptRoot/Taskfile.yml" bootstrap
exit $LASTEXITCODE
