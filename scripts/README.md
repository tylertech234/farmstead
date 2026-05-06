# scripts/ — helper shell scripts

## Available scripts

### `backup.sh`

Dumps all named Docker volumes defined in `docker-compose.yml` to dated
tar.gz archives under `backups/YYYY-MM-DD/`.

```bash
bash scripts/backup.sh
```

### `restore.sh`

Restores a single Docker volume from a tar.gz archive. Prompts for
confirmation before overwriting data.

```bash
bash scripts/restore.sh backups/2024-03-15/n8n_data.tar.gz farmstead_n8n_data
```

### `pull-model.sh`

Pulls the Ollama model specified in `.env` (or pass a model name as an
argument).

```bash
# Pull the default model from .env
bash scripts/pull-model.sh

# Pull a specific model
bash scripts/pull-model.sh phi3:mini
```

### `update-stack.sh` / `update-stack.ps1`

Pulls latest images for all services, recreates containers, waits for
health checks, and prunes old images to free disk space.

```bash
# CPU-only update
bash scripts/update-stack.sh

# With GPU overlay
bash scripts/update-stack.sh --gpu

# Preview without changes
bash scripts/update-stack.sh --dry-run
```

PowerShell:

```powershell
.\scripts\update-stack.ps1 -Gpu
.\scripts\update-stack.ps1 -DryRun
```

### `compact-docker-vhdx.ps1`

Compacts the Docker Desktop WSL2 virtual disk (`ext4.vhdx`) to reclaim
unused space. WSL2 VHDXs grow when data is written but never auto-shrink.
**Must be run as Administrator.**

```powershell
# From an elevated PowerShell:
.\scripts\compact-docker-vhdx.ps1
```

### `Prepare-FarmsteadInstaller.ps1`

Wrapper for the legacy installer-preparation script in `.working` so you can
run installer preparation from repo root.

```powershell
.\scripts\Prepare-FarmsteadInstaller.ps1

# Use x86_64 optimization profile for target machine
.\scripts\Prepare-FarmsteadInstaller.ps1 -TargetArchitecture x86_64
```

### `Configure-FarmsteadServices.ps1`

Wrapper for the legacy service configurator in `.working`. Opens an interactive
configurator to enable/disable services, optional add-ons, and common stack
settings used by the autoinstall flow.

```powershell
.\scripts\Configure-FarmsteadServices.ps1

# Use defaults without prompts
.\scripts\Configure-FarmsteadServices.ps1 -NonInteractive

# Pick target profile explicitly
.\scripts\Configure-FarmsteadServices.ps1 -TargetArchitecture x86_64
```

### `Export-FarmsteadSecrets.ps1`

Wrapper for the legacy secret-export script in `.working` to create a local
backup archive of generated Farmstead credentials and deployment material.

```powershell
.\scripts\Export-FarmsteadSecrets.ps1
```

### `Build-FarmsteadUSB.ps1`

Wrapper for the legacy USB builder in `.working` to create the autoinstall USB
media from the repository root.

```powershell
.\scripts\Build-FarmsteadUSB.ps1

# Build or refresh a specific USB target
.\scripts\Build-FarmsteadUSB.ps1 -RequiredDriveLetter H
```

Optional services available in configurator prompts:

- watchtower
- uptime-kuma
- gitea
- code-server
- joplin-server (with joplin-db)
- syncthing

Required core behavior:

- nginx-proxy-manager remains enabled as mandatory infrastructure.
