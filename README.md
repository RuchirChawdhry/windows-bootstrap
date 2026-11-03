# windows-bootstrap

Opinionated Windows 11 provisioning with [Task](https://taskfile.dev/), PowerShell 7, WinGet, and Scoop. **`.apps-config.yml` is the only application inventory.**

On a new PC, run `pwsh -NoProfile -File .\bootstrap.ps1` once to install Scoop and Task and execute the bootstrap. After that, use Task directly from the repository:

| Command | Purpose |
| --- | --- |
| `task bootstrap` | Install managers, buckets, cached apps, and languages |
| `task apps:install` | Install all configured apps sequentially |
| `task apps:reinstall` | Force-reinstall apps without uninstalling their data; skips the active Task binary |
| `task apps:upgrade` | Upgrade configured applications |
| `task apps:status` | Show installed Scoop and WinGet applications |
| `task languages:install` | Install Python, Go, and Lua |
| `task cache:prefetch` | Download configured Scoop packages in parallel using aria2 |
| `task cache:clear` | Clear Scoop's download cache |
| `task doctor` | Check Scoop and verify configured applications |
| `task --list` | Discover all commands |

Scoop buckets and package IDs are read directly from `.apps-config.yml`; the custom bucket is registered as `ruchir`. WinGet installs run one at a time. The bootstrap and reinstall commands do not uninstall unrelated applications.
