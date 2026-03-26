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
bash scripts/restore.sh backups/2024-03-15/n8n_data.tar.gz meetstack_n8n_data
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
