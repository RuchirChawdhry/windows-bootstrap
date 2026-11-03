$ErrorActionPreference = "Stop"
$root = Resolve-Path "$PSScriptRoot/.."
$template = Get-Content "$root/unattended/Autounattend.xml.tmpl" -Raw
$samplePassword = "CI-Only-Disposable-Password!&<>2026"
@{
    COMPUTER_NAME = "WIN-CI-TEST"
    TEMP_PASSWORD = $samplePassword
    TARGET_DISK = "0"
}.GetEnumerator() | ForEach-Object {
    $template = $template.Replace(("{" * 2 + $_.Key + "}" * 2), [Security.SecurityElement]::Escape($_.Value))
}
[xml]$xml = $template
$ns = [System.Xml.XmlNamespaceManager]::new($xml.NameTable)
$ns.AddNamespace("u", "urn:schemas-microsoft-com:unattend")
$pick = { param($path) $xml.SelectSingleNode($path, $ns).InnerText }
function Assert($ok, $message) { if (!$ok) { throw $message } }

Assert (($xml.unattend.settings | ForEach-Object pass) -join "," -eq "windowsPE,specialize,oobeSystem") "Setup pass order"
Assert ((& $pick "//u:DiskConfiguration/u:Disk/u:WillWipeDisk") -eq "true") "Target disk wipe"
Assert ((& $pick "//u:OSImage/u:InstallFrom/u:MetaData/u:Value") -eq "Windows 11 Pro") "Edition"
Assert ((& $pick "//u:OSImage/u:InstallTo/u:PartitionID") -eq "3") "Windows partition"
Assert ((& $pick "//u:LocalAccount/u:Name") -ceq "PC") "Account name"
Assert ((& $pick "//u:LocalAccount/u:Group") -eq "Administrators") "Admin group"
Assert ((& $pick "//u:AutoLogon/u:LogonCount") -eq "1") "AutoLogonCount"
Assert ((& $pick "//u:AutoLogon/u:Username") -ceq "PC") "AutoLogon account"
$password = & $pick "//u:LocalAccount/u:Password/u:Value"
Assert ($password -ceq $samplePassword) "Escaped template password"
Assert ((& $pick "//u:AutoLogon/u:Password/u:Value") -ceq $password) "AutoLogon credentials match account"
Assert ((& $pick "//u:ComputerName") -eq "WIN-CI-TEST") "Computer name"
Assert ((& $pick "//u:FirstLogonCommands/u:SynchronousCommand/u:CommandLine") -like "*first-logon.ps1") "First logon handoff"
Assert ((& $pick "//u:RunSynchronousCommand/u:Path") -like "*windows-bootstrap*") "Offline source staging"
Assert (!$xml.OuterXml.Contains("SkipMachineOOBE")) "No SkipMachineOOBE"
Assert (!$template.Contains("{{")) "No unrendered placeholders"
$handoff = Get-Content "$PSScriptRoot/../unattended/first-logon.ps1" -Raw
Assert ($handoff.Contains('SetPassword("")')) "Reset unknown password to blank"
Assert ($handoff.Contains('PasswordExpired = 1')) "Force permanent password creation"
Assert ($handoff.IndexOf("LastTaskResult") -lt $handoff.IndexOf('SetPassword("")')) "Only reset password after bootstrap succeeds"
Assert ($handoff.IndexOf('SetPassword("")') -lt $handoff.IndexOf('PasswordExpired = 1')) "Expire blank password after reset"
Assert (!$handoff.Contains("Restart-Computer") -and !$handoff.Contains("logoff.exe")) "Leave sign-out or reboot to Windows and user"
Assert (($xml.SelectNodes("//u:CreatePartition", $ns)).Count -eq 3) "GPT partition count"
Assert ((& $pick "//u:CreatePartition[u:Order='1']/u:Type") -eq "EFI") "EFI partition"
Assert ((& $pick "//u:CreatePartition[u:Order='2']/u:Type") -eq "MSR") "MSR partition"
Assert ((& $pick "//u:ModifyPartition[u:PartitionID='3']/u:Format") -eq "NTFS") "Windows NTFS partition"
$taskfile = Get-Content "$root/Taskfile.yml" -Raw
Assert ($taskfile.Contains("iso:download:")) "ISO acquisition task"
Assert ($taskfile.Contains("RandomNumberGenerator]::GetBytes")) "Cryptographic password generation"
Assert (!$taskfile.Contains('$env:TEMP_PASSWORD')) "No user-supplied temporary password"
Assert ($taskfile.Contains('-Lang "^English$"')) "Exact en-US Fido language selection"
Assert ($taskfile.Contains("aria2c --continue=true")) "Resumable aria2 download"
Assert ($taskfile.Contains("unattended:stage:")) "Shared unattended media staging task"
Assert (!$taskfile.Contains("unattended:render:")) "No standalone render task"
Assert (Test-Path "$root/unattended/bootstrap-user.ps1") "First-login bootstrap script"
Write-Output "Offline unattended XML template and handoff assertions passed."
