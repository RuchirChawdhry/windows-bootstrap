# windows-bootstrap

Opinionated Windows 11 provisioning with [Task](https://taskfile.dev/), PowerShell 7, WinGet, and Scoop.

`.app-config.yml` in this repository is a **first-run template**. The authoritative configuration is **`$HOME/.app-config.yml`** (`%USERPROFILE%\.app-config.yml`). `task config:init` copies the template only if the profile file does not exist. Every application task reads the profile file; subsequent edits to the repository template do not overwrite personal settings.

First run:

```powershell
pwsh -NoProfile -File .\bootstrap.ps1
```

Then, from the repository:

| Task | Action |
| --- | --- |
| `task bootstrap` | Initialize config, install managers, buckets, applications, and languages |
| `task config:init` | Copy the initial config into the user profile (once) |
| `task apps:install` | Install configured applications sequentially |
| `task apps:reinstall` | Force-reinstall apps (skips Scoop's active Task executable) |
| `task apps:upgrade` | Upgrade configured applications |
| `task apps:status` | Display installed applications |
| `task managers:install` | Install enabled managers and aria2 |
| `task buckets:add` | Add configured Scoop buckets |
| `task languages:install` | Install Python, Go, and Lua |
| `task cache:prefetch` | Download Scoop apps concurrently (six jobs, aria2) |
| `task cache:clear` | Clear the Scoop cache |
| `task doctor` | Check Scoop and configured application installation |
| `task --list` | List available tasks |

Package operations stay inline in `Taskfile.yml`. The `install-modules.ps1` utility manages PowerShell modules. No separate application dispatcher is required.

Scoop is installed in `$HOME/Tools/Scoop`, and the custom bucket is registered as `ruchir`. WinGet GUI installations remain sequential.
