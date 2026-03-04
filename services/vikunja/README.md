# Vikunja — bind-mount config directory

Place any files here that you want available inside the Vikunja container at
`/app/vikunja/config`. Examples:

| File / folder | Purpose |
|---|---|
| `config.yml` | Vikunja server configuration overrides |

## Minimal `config.yml` example

```yaml
# /app/vikunja/config/config.yml
service:
  enableregistration: true   # set to false to disable public sign-up

mailer:
  enabled: false             # set to true and fill in SMTP settings to enable e-mail
```

> All database credentials are supplied via environment variables in
> `docker-compose.yml` and should not be duplicated here.
>
> For the full list of options see the
> [Vikunja configuration docs](https://vikunja.io/docs/config-options/).
