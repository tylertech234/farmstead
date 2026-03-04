# Ollama — bind-mount config directory

Place any files here that you want available inside the Ollama container at
`/etc/ollama`. Examples:

| File / folder | Purpose |
|---|---|
| `Modelfile` | Custom Modelfile to derive a fine-tuned variant |
| `config.json` | Ollama server config overrides (if supported by your version) |

## Pulling a model on first run

After `docker compose up -d`, pull a model interactively:

```bash
docker exec -it ollama ollama pull llama3
```

Or set `OLLAMA_MODEL` in `.env` and use a startup script in `scripts/` to
pull it automatically.

## GPU notes

See the [GPU Passthrough section in the root README](../../README.md#gpu-passthrough--ollama--rtx-4070-ti)
to enable NVIDIA GPU acceleration.
