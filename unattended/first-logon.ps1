#Requires -RunAsAdministrator
$ErrorActionPreference = "Stop"
$root = "C:\windows-bootstrap"
$winlogon = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"

# Windows can increment LogonCount=1 to two logons: disable it immediately.
Set-ItemProperty $winlogon AutoAdminLogon "0"
Set-ItemProperty $winlogon AutoLogonCount 0
Remove-ItemProperty $winlogon DefaultPassword -ErrorAction SilentlyContinue

$pwsh = "$env:ProgramFiles\PowerShell\7\pwsh.exe"
if (!(Test-Path $pwsh)) {
    winget install --id Microsoft.PowerShell -e --source winget --scope machine --silent --disable-interactivity --accept-package-agreements --accept-source-agreements
    if ($LASTEXITCODE) { throw "PowerShell 7 installation failed ($LASTEXITCODE)" }
}

# Scoop must run unelevated, although FirstLogonCommands runs elevated.
$name = "WindowsBootstrap-User"
$action = New-ScheduledTaskAction -Execute $pwsh -Argument "-NoProfile -File ""$root\unattended\bootstrap-user.ps1"""
$principal = New-ScheduledTaskPrincipal -UserId "$env:COMPUTERNAME\PC" -LogonType Interactive -RunLevel Limited
Register-ScheduledTask -TaskName $name -Action $action -Principal $principal -Force | Out-Null
$started = (Get-Date).AddSeconds(-2)
Start-ScheduledTask -TaskName $name
do {
    Start-Sleep 3
    $info = Get-ScheduledTaskInfo -TaskName $name
    $state = (Get-ScheduledTask -TaskName $name).State
} while ($info.LastRunTime -lt $started -or $state -ne "Ready")

if ($info.LastTaskResult) { throw "Bootstrap failed ($($info.LastTaskResult)); inspect the PC user's AppData\Local\windows-bootstrap.log" }
Unregister-ScheduledTask -TaskName $name -Confirm:$false
$user = [ADSI]"WinNT://./PC,user"
$user.SetPassword("")
$user.PasswordExpired = 1
$user.SetInfo()
