# windows-bootstrap

Minimal Windows provisioning with [Task](https://taskfile.dev), PowerShell 7.4+, Yayaml, Scoop and WinGet.

**Configuration:** `$HOME/.app-config.yml` (`%USERPROFILE%\\.app-config.yml`). The tracked `.app-config.yml` is the initial template; `task config:init` copies it once without overwriting your profile file.

**First run:**

```powershell
pwsh -NoProfile -File .\\bootstrap.ps1
```

Then run `task --list-all` (or `task help`) to discover operations:

| Task | Purpose |
| --- | --- |
| `task bootstrap` | Provision managers, buckets, apps and languages |
| `task speedup` | Apply Windows UI responsiveness optimizations |
| `task apps:install` | Install configured applications sequentially |
| `task apps:reinstall` | Force-reinstall configured apps (skips Task itself) |
| `task apps:upgrade` | Upgrade configured apps |
| `task apps:status` | Show installed apps |
| `task cache:prefetch` | Download Scoop packages concurrently (6 workers, aria2) |
| `task cache:clear` | Clear Scoop download cache |
| `task doctor` | Display Scoop health/status and installed WinGet packages |

`task speedup` (aliases: `task optimize`, `task perf`) currently disables window minimize/maximize animations and taskbar animations for the current user. Run it separately from bootstrap; sign out and back in to apply all changes. Future optimizations can be added as `speedup:*` subtasks. It does not alter security, services or power settings.

The Taskfile uses shared PowerShell statements via `vars` and directly imports **Yayaml** to read the user-profile YAML. `install-modules.ps1` stores modules in `$HOME/Tools/PowerShell/Modules`; Scoop lives in `$HOME/Tools/Scoop`. No separate app dispatcher or duplicate package list is used.

Short aliases are available: `task setup` / `task bs`, `task install`, `task reinstall`, `task upgrade`, `task status`, `task prefetch`, `task clean`, and `task check`. Use `task help` to display the list. Namespaced shortcuts include `task apps:i`, `task apps:r`, and `task apps:u`.

## GitHub Actions

[Windows bootstrap](.github/workflows/windows-bootstrap.yml) calls the central [reusable CI workflow](https://github.com/RuchirChawdhry/ci-workflows/blob/main/.github/workflows/windows-bootstrap.yml) on every PR and push to `main`. The smoke job executes the real `bootstrap.ps1` and `Taskfile.yml` on a clean `windows-2025` runner using [the small CI configuration](tests/ci-app-config.yml), then verifies Scoop, Yayaml, the installed packages and Taskfile commands.

To attempt the **complete** `.app-config.yml` inventory, open Actions → Windows bootstrap → Run workflow → enable **full**. This installs WinGet and GUI packages as well. Hosted `windows-2025` runs Windows Server 2025 rather than desktop Windows 11, so full GUI / Microsoft Store installs may be unsupported there; a smoke pass does not validate those packages.

## Unattended Windows 11 Pro installation

Both paths render the **same** `unattended/Autounattend.xml.tmpl` and include a copy of the current repository as `bootstrap/`. Setup installs UEFI/GPT Windows 11 Pro, creates a local administrator called `PC`, auto-logs in once, and runs the existing `bootstrap.ps1` / `task bootstrap`. Only after bootstrap exits successfully does it expire `PC`'s temporary password and restart. The next sign-in requires a permanent password. Windows 11 Pro installation media and an appropriate Windows license are required.

> **Data loss:** the generated answer file **wipes Windows Setup disk 0** by default. On a physical PC, identify the correct Windows Setup/WinPE disk number before booting; set `$env:TARGET_DISK` when rendering if it is not 0. Do not boot this installer on a machine containing data you intend to preserve. The USB-preparation disk is **different** from the Windows installation target.

Generate once per installation, with a disposable password (PowerShell 7.4+):

```powershell
$env:TEMP_PASSWORD = 'Disposable-Strong-Password!'
$env:COMPUTER_NAME = 'MY-PC'   # optional; otherwise a unique PC-XXXXXXXX
$env:TARGET_DISK = '0'         # optional; WinPE installation disk number
task unattended:render
```

`task install:vm` (Ubuntu host with `pwsh`, QEMU/KVM, `qemu-img`, `swtpm`, `xorriso`, OVMF):

```powershell
task install:vm
```

It uses `.cache/windows.iso`, creates `.cache/windows.qcow2` (80 GiB), a persistent OVMF variables file, TPM state, and `.cache/unattended.iso`, then starts QEMU with VNC on `127.0.0.1:5901`. Set `OVMF_CODE` and `OVMF_VARS` environment variables for nonstandard firmware paths. The QCOW2 disk is reused on later runs; **rerunning installation will wipe that VM disk again**.

`task install:usb` (elevated PowerShell on Windows 11, using `oscdimg` only if separately creating the unattended ISO):

```powershell
task install:usb
```

It detects a single non-system USB disk automatically, prints its model/size, and requires typing `ERASE N` before destroying its contents. When multiple USB disks are present, set `$env:USB_DISK = 'N'` to choose the **USB installer drive**. This number is unrelated to `TARGET_DISK`. It creates an MBR/FAT32 bootable partition (at most 32 GiB), mounts the Windows ISO, copies installation files, splits oversized `sources/install.wim` to `install.swm` parts with DISM, and includes `Autounattend.xml` plus `bootstrap/` at the root. It does not use Rufus.

Both commands accept a different local ISO with `task install:vm ISO=/path/to/windows.iso` or `task install:usb ISO=C:/path/to/windows.iso`. ISO downloading is intentionally independent; place a licensed Windows 11 ISO at `.cache/windows.iso` or pass `ISO`. No Microsoft download link is embedded.

The installed machine must have Internet access for unattended WinGet installation of PowerShell 7 and for the existing Scoop/WinGet bootstrap. FirstLogonCommands disables subsequent auto-logins immediately and schedules the existing bootstrap in the unelevated interactive `PC` session (required by Scoop). See the `PC` user's `AppData\Local\windows-bootstrap.log`. On failure the password **is not expired** and the PC **does not reboot** automatically; fix connectivity/the issue and rerun `C:\windows-bootstrap\unattended\first-logon.ps1` as administrator. On success, the account is marked password-expired before reboot. Keep the USB/secondary ISO connected until the first login stages have completed.

`Autounattend.xml` contains the **disposable** password in plaintext (required by Windows Setup) and is also cached by Windows Setup. The permanent password is **never collected or written by this repository**. Keep installer media secure, and delete `.cache/` and securely erase/reformat the USB when provisioning is finished. Generated files are Git-ignored.

Validate the rendered XML and lifecycle wiring with `task unattended:render` and `pwsh -File tests/unattended.ps1`. The CI validates structure; end-to-end Windows 11 Setup behavior requires a real VM or physical install.
