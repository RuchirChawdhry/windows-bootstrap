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
$root = Resolve-Path "$PSScriptRoot/.."
Assert (($xml.SelectNodes("//u:CreatePartition", $ns)).Count -eq 3) "GPT partition count"
Assert ((& $pick "//u:CreatePartition[u:Order='1']/u:Type") -eq "EFI") "EFI partition"
Assert ((& $pick "//u:CreatePartition[u:Order='2']/u:Type") -eq "MSR") "MSR partition"
Assert ((& $pick "//u:ModifyPartition[u:PartitionID='3']/u:Format") -eq "NTFS") "Windows NTFS partition"
task unattended:iso
Assert (Test-Path "$root/.cache/unattended.iso") "Secondary QEMU ISO"
Assert (Test-Path "$root/.cache/unattended-media/bootstrap/bootstrap.ps1") "Staged bootstrap"
Assert (Test-Path "$root/.cache/unattended-media/bootstrap/unattended/first-logon.ps1") "Staged first logon"
$generated = (Get-FileHash "$root/.cache/Autounattend.xml").Hash
$staged = (Get-FileHash "$root/.cache/unattended-media/Autounattend.xml").Hash
Assert ($generated -eq $staged) "VM and USB share a rendered answer file"
Write-Output "Unattended XML, bootstrap staging and secondary ISO validated."
