# Home Assistant — bind-mount config directory

Place any files here that you want available inside the Home Assistant container
at `/config/custom_components`. Examples:

| File / folder | Purpose |
|---|---|
| `<integration_name>/` | A custom HACS or hand-written integration |

## Persisted configuration

The named volume `home_assistant_data` stores the full HA config directory
(`/config`), including `configuration.yaml`, automations, scenes, scripts, and
the SQLite database.

To seed an initial `configuration.yaml`, you can copy it into the volume after
the first start:

```bash
docker cp configuration.yaml home-assistant:/config/configuration.yaml
docker compose restart home-assistant
```

> For integration docs and add-on guidance see the
> [Home Assistant documentation](https://www.home-assistant.io/docs/).
