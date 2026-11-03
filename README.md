# windows-bootstrap

Minimal Windows provisioning with [Task](https://taskfile.dev), PowerShell 7.4+, Yayaml, Scoop and WinGet.

**Configuration:** `$HOME/.app-config.yml` (`%USERPROFILE%\\.app-config.yml`). The tracked `.app-config.yml` is the initial template; `task config:init` copies it once without overwriting your profile file.

**First run:**

```powershell
pwsh -NoProfile -File .\\bootstrap.ps1
```

Then run `task help` (or `task --list-all`) to discover operations. The Taskfile disables command echoing globally (`silent: true`), while keeping command output and errors visible:

| Task | Purpose |
| --- | --- |
| `task bootstrap` | Provision managers, buckets, apps and languages |
| `task apps:install` | Install configured applications sequentially |
| `task apps:reinstall` | Force-reinstall configured apps (skips Task itself) |
| `task apps:upgrade` | Upgrade configured apps |
| `task apps:status` | Show installed apps |
| `task cache:prefetch` | Download Scoop packages concurrently (6 workers, aria2) |
| `task cache:clear` | Clear Scoop download cache |
| `task doctor` | Display Scoop health/status and installed WinGet packages |

The Taskfile uses shared PowerShell statements via `vars` and directly imports **Yayaml** to read the user-profile YAML. `install-modules.ps1` stores modules in `$HOME/Tools/PowerShell/Modules`; Scoop lives in `$HOME/Tools/Scoop`. No separate app dispatcher or duplicate package list is used.

Short aliases are available: `task setup` / `task bs`, `task install`, `task reinstall`, `task upgrade`, `task status`, `task prefetch`, `task clean`, and `task check`. Use `task help` to display the list. Namespaced shortcuts include `task apps:i`, `task apps:r`, and `task apps:u`.

## GitHub Actions

[Windows bootstrap](.github/workflows/windows-bootstrap.yml) calls the central [reusable CI workflow](https://github.com/RuchirChawdhry/ci-workflows/blob/main/.github/workflows/windows-bootstrap.yml) on every PR and push to `main`. The smoke job executes the real `bootstrap.ps1` and `Taskfile.yml` on a clean `windows-2025` runner using [the small CI configuration](tests/ci-app-config.yml), then verifies Scoop, Yayaml, the installed packages and Taskfile commands.

To attempt the **complete** `.app-config.yml` inventory, open Actions → Windows bootstrap → Run workflow → enable **full**. This installs WinGet and GUI packages as well. Hosted `windows-2025` runs Windows Server 2025 rather than desktop Windows 11, so full GUI / Microsoft Store installs may be unsupported there; a smoke pass does not validate those packages.
