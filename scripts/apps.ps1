#Requires -Version 7.0
param([string]$Action)

$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$env:SCOOP = "$HOME\Tools\Scoop"
$env:Path = "$env:SCOOP\shims;$env:Path"
$env:PSModulePath = "$HOME\Tools\PowerShell\Modules;$env:PSModulePath"

if ($Action -eq 'managers') {
    & "$root\install-modules.ps1" -Name powershell-yaml
}
Import-Module powershell-yaml
$config = Get-Content "$root\.apps-config.yml" -Raw | ConvertFrom-Yaml

function Invoke-Scoop {
    & "$env:SCOOP\shims\scoop.cmd" @args
    if ($LASTEXITCODE) { throw "Scoop $args failed ($LASTEXITCODE)" }
}

function Invoke-WinGet {
    & winget.exe @args
    if ($LASTEXITCODE -notin @(0, -1978335189)) { throw "WinGet $args failed ($LASTEXITCODE)" }
}

function Get-ScoopApps {
    foreach ($bucket in $config.scoop.apps.Keys) {
        foreach ($app in $config.scoop.apps[$bucket]) { "$bucket/$app" }
    }
}

function Install-ScoopApp([string]$Package, [bool]$Reinstall = $false) {
    $name = ($Package -split '/')[-1]
    if ($Reinstall -and (Test-Path "$env:SCOOP\apps\$name\current")) {
        Invoke-Scoop update --force $Package
    } else {
        Invoke-Scoop install $Package
    }
}

switch ($Action) {
    managers {
        if ($config.winget.enabled -and -not (Get-Command winget.exe -EA Ignore)) {
            & "$root\install-modules.ps1" -Name Microsoft.WinGet.Client
            Repair-WinGetPackageManager
        }
        if ($config.scoop.enabled -and -not (Test-Path "$env:SCOOP\shims\scoop.cmd")) {
            [Environment]::SetEnvironmentVariable('SCOOP', $env:SCOOP, 'User')
            Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
            & ([scriptblock]::Create((Invoke-RestMethod 'https://get.scoop.sh'))) -ScoopDir $env:SCOOP
        }
        if ($config.scoop.enabled) {
            if (-not (Test-Path "$env:SCOOP\apps\git\current")) { Invoke-Scoop install git }
            if (-not (Test-Path "$env:SCOOP\apps\aria2\current")) { Invoke-Scoop install aria2 }
            Invoke-Scoop config aria2-enabled true
        }
    }
    buckets {
        if ($config.scoop.enabled) {
            foreach ($bucket in $config.scoop.buckets) {
                $name = ($bucket -like 'https://*') ? 'ruchir' : $bucket
                if (-not (Test-Path "$env:SCOOP\buckets\$name")) {
                    ($bucket -like 'https://*') ? (Invoke-Scoop bucket add $name $bucket) : (Invoke-Scoop bucket add $name)
                }
            }
        }
    }
    prefetch {
        if ($config.scoop.enabled) {
            $packages = @(Get-ScoopApps) + @($config.languages | ForEach-Object { "main/$_" })
            $failed = @($packages | ForEach-Object -Parallel {
                & "$env:SCOOP\shims\scoop.cmd" download $_ | Out-Null
                if ($LASTEXITCODE) { $_ }
            } -ThrottleLimit 6)
            if ($failed.Count) { throw "Scoop downloads failed: $($failed -join ', ')" }
        }
    }
    scoop-install {
        if ($config.scoop.enabled) {
            foreach ($package in (Get-ScoopApps)) { Install-ScoopApp $package }
        }
    }
    scoop-reinstall {
        if ($config.scoop.enabled) {
            foreach ($package in (Get-ScoopApps)) {
                if ($package -ne 'main/task') { Install-ScoopApp $package $true }
            }
        }
    }
    scoop-upgrade {
        if ($config.scoop.enabled) {
            Invoke-Scoop update
            foreach ($package in (Get-ScoopApps)) {
                if ($package -ne 'main/task') {
                    $name = ($package -split '/')[-1]
                    (Test-Path "$env:SCOOP\apps\$name\current") ? (Invoke-Scoop update $package) : (Invoke-Scoop install $package)
                }
            }
        }
    }
    winget-install {
        if ($config.winget.enabled) {
            foreach ($id in $config.winget.apps) {
                Invoke-WinGet install --id $id --exact --silent --disable-interactivity --accept-source-agreements --accept-package-agreements --no-upgrade
            }
        }
    }
    winget-reinstall {
        if ($config.winget.enabled) {
            foreach ($id in $config.winget.apps) {
                Invoke-WinGet install --id $id --exact --silent --disable-interactivity --accept-source-agreements --accept-package-agreements --force
            }
        }
    }
    winget-upgrade {
        if ($config.winget.enabled) {
            foreach ($id in $config.winget.apps) {
                Invoke-WinGet upgrade --id $id --exact --silent --disable-interactivity --accept-source-agreements --accept-package-agreements
            }
        }
    }
    languages {
        if ($config.scoop.enabled) {
            foreach ($language in $config.languages) { Install-ScoopApp "main/$language" }
        }
    }
    cache-clear {
        if ($config.scoop.enabled) { Invoke-Scoop cache rm '*' }
    }
    status {
        if ($config.scoop.enabled) { Invoke-Scoop list }
        if ($config.winget.enabled) { Invoke-WinGet list --accept-source-agreements }
    }
    doctor {
        if ($config.scoop.enabled) {
            Invoke-Scoop checkup
            $missing = @(Get-ScoopApps | Where-Object { -not (Test-Path "$env:SCOOP\apps\$(($_ -split '/')[-1])\current") })
            $missing += @($config.languages | Where-Object { -not (Test-Path "$env:SCOOP\apps\$_\current") })
            if ($missing.Count) { throw "Missing Scoop packages: $($missing -join ', ')" }
        }
        if ($config.winget.enabled) {
            foreach ($id in $config.winget.apps) {
                winget.exe list --id $id --exact --accept-source-agreements | Out-Null
                if ($LASTEXITCODE) { throw "Missing WinGet package: $id" }
            }
        }
        Write-Host 'All configured applications are present.'
    }
}
