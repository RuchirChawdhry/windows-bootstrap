$ErrorActionPreference = "Stop"
$env:TEMP_PASSWORD = "Test-Disposable-2026!&<>"
$env:COMPUTER_NAME = "WIN-CI-TEST"
$env:TARGET_DISK = "0"
task unattended:render
[xml]$xml = Get-Content "$PSScriptRoot/../.cache/Autounattend.xml" -Raw
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
Assert ((& $pick "//u:LocalAccount/u:Password/u:Value") -eq $env:TEMP_PASSWORD) "XML-escaped password"
Assert ((& $pick "//u:ComputerName") -eq "WIN-CI-TEST") "Computer name"
Assert ((& $pick "//u:FirstLogonCommands/u:SynchronousCommand/u:CommandLine") -like "*first-logon.ps1") "First logon handoff"
Assert ((& $pick "//u:RunSynchronousCommand/u:Path") -like "*windows-bootstrap*") "Offline source staging"
Assert (!$xml.OuterXml.Contains("SkipMachineOOBE")) "No SkipMachineOOBE"
Assert (!(Get-Content "$PSScriptRoot/../.cache/Autounattend.xml" -Raw).Contains("{{")) "No unrendered placeholders"
Assert ((Get-Content "$PSScriptRoot/../unattended/first-logon.ps1" -Raw) -match "PasswordExpired = 1") "Password expiration"
Assert ((Get-Content "$PSScriptRoot/../unattended/first-logon.ps1" -Raw) -match "LastTaskResult") "Bootstrap success gate"
Write-Output "Unattended XML and provisioning invariants validated."
