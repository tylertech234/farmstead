# Open WebUI — bind-mount config directory

Place any files here that you want available inside the Open WebUI container at
`/app/backend/config`. Examples:

| File / folder | Purpose |
|---|---|
| `config.json` | Persistent UI settings overrides |
| `prompts/` | Custom system-prompt templates |
| `functions/` | Custom OpenAI-compatible function definitions |

Open WebUI connects to Ollama automatically via the `OLLAMA_BASE_URL`
environment variable set in `docker-compose.yml` (`http://ollama:11434`).

> For full configuration options see the
> [Open WebUI documentation](https://docs.openwebui.com/).
