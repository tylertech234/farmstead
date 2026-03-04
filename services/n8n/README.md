# n8n — bind-mount config directory

Place any files here that you want available inside the n8n container at
`/home/node/.n8n/custom`. Examples:

| File / folder | Purpose |
|---|---|
| `credentials.json` | Exported n8n credentials (for migration / seeding) |
| `workflows/` | Exported workflow JSON files |
| `nodes/` | Custom community nodes installed locally |

> **Note:** Sensitive credential values should be stored in `.env`, not committed here.
