# windows-bootstrap

Minimal Windows provisioning with [Task](https://taskfile.dev), PowerShell 7.4+, Yayaml, Scoop and WinGet.

**Configuration:** `$HOME/.app-config.yml` (`%USERPROFILE%\.app-config.yml`). The tracked `.app-config.yml` is the initial template; `task config:init` copies it once without overwriting your profile file.

**First run:**

```powershell
pwsh -NoProfile -File .\bootstrap.ps1
```

Then run `task --list` to discover operations:

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
