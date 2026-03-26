# n8n Workflow Designs

These workflows are designed to be built in n8n's visual editor after the stack
is deployed. Each section describes the trigger, nodes, and data flow.

> **Tip:** Export finished workflows as JSON and save them in this directory
> (`services/n8n/workflows/`) for version control and easy re-import.

---

## 1. Gmail Scanner & Auto-Reply

Automatically scans incoming Gmail for common cadets-related questions and
replies using the local LLM with FAQ context.

```
┌─────────────┐     ┌──────────────┐     ┌──────────────┐     ┌─────────────┐
│ Gmail Trigger│────▸│ LLM Classify │────▸│  Switch on   │────▸│ Auto-Reply  │
│ (poll 5 min) │     │  (Ollama)    │     │  category    │     │ (Gmail Send)│
└─────────────┘     └──────────────┘     └──────┬───────┘     └─────────────┘
                                                │
                                                ├──▸ FAQ → Generate reply with Ollama → Send via Gmail
                                                ├──▸ Requires Human → Create Vikunja task
                                                └──▸ Informational → Archive / label only
```

### Nodes

1. **Gmail Trigger** — poll every 5 minutes for unread messages in inbox
2. **HTTP Request → Ollama** — POST to `http://ollama:11434/api/generate`
   - System prompt: cadets FAQ knowledge base (meeting times, enrollment, uniform policy, etc.)
   - User prompt: email subject + body
   - Ask the model to classify as: `faq`, `human`, or `info`
3. **Switch** — route based on classification
4. **HTTP Request → Ollama** (FAQ branch) — generate a polite reply using cadets context
5. **Gmail Send** — reply to original sender
6. **Vikunja API** (human branch) — create a task in the "Inbox" project for manual review

### Environment / credentials needed

- Gmail OAuth2 credentials (configured in n8n Credentials)
- Vikunja API token (Administration → API Tokens)

---

## 2. Discord Q&A Bot

Monitors a designated Discord channel and answers common questions using the
local LLM with cadets FAQ context.

```
┌──────────────┐     ┌──────────────┐     ┌──────────────┐
│ Discord      │────▸│ LLM Generate │────▸│ Discord Send │
│ Trigger      │     │  (Ollama)    │     │  (reply)     │
└──────────────┘     └──────────────┘     └──────────────┘
```

### Nodes

1. **Discord Trigger** — on new message in `#ask-questions` channel
2. **Filter** — ignore bot messages (check `message.author.bot === false`)
3. **HTTP Request → Ollama** — generate answer with cadets FAQ system prompt
4. **Discord Send** — post reply in the same channel, mentioning the original author
5. **Rate Limiter** — use n8n's built-in Wait node to limit to 1 reply per 10 seconds

### Environment / credentials needed

- Discord Bot Token (create in [Discord Developer Portal](https://discord.com/developers/applications))
- Bot must be invited to your server with `Send Messages` permission

---

## 3. Meeting Minutes

Accepts an audio file or text notes, transcribes (if audio), summarises into
structured meeting minutes, and publishes to Wiki.js.

```
┌──────────────┐     ┌──────────────┐     ┌──────────────┐     ┌──────────────┐     ┌─────────────┐
│ Webhook      │────▸│ Is audio?    │────▸│ Whisper      │────▸│ LLM Summary  │────▸│ Wiki.js     │
│ (file upload)│     │ (Switch)     │     │ Transcribe   │     │  (Ollama)    │     │ (GraphQL)   │
└──────────────┘     └──────────────┘     └──────────────┘     └──────────────┘     └──────┬──────┘
                                                                                          │
                                                                                          ▼
                                                                                   ┌─────────────┐
                                                                                   │ Discord Post│
                                                                                   │ (summary)   │
                                                                                   └─────────────┘
```

### Nodes

1. **Webhook** — accepts `multipart/form-data` file upload
2. **Switch** — check MIME type: `audio/*` → Whisper path; `text/*` → skip to summarise
3. **HTTP Request → Whisper** — POST file to `http://whisper:9000/asr`, get transcript JSON
4. **HTTP Request → Ollama** — summarise with system prompt:
   ```
   You are a meeting minutes assistant for an Air Force Cadets squadron.
   Given a transcript or notes, produce structured minutes with:
   - Date and attendees
   - Agenda items discussed
   - Key decisions made
   - Action items (who, what, due date)
   Keep the tone professional and concise.
   ```
5. **HTTP Request → Wiki.js** — GraphQL mutation to create a page under `/minutes/YYYY-MM-DD`
6. **Discord Send** — post a summary + link to the full minutes page

### Environment / credentials needed

- Wiki.js API key (Administration → API Access)
- Discord Bot Token (same as workflow #2)

---

## 4. Calendar Reminders

Runs daily to check for upcoming events in Radicale and sends reminders to
Discord and/or email.

```
┌──────────────┐     ┌──────────────┐     ┌──────────────┐     ┌──────────────┐
│ Cron Trigger │────▸│ CalDAV Query │────▸│ Filter next  │────▸│ Discord /    │
│ (daily 8 AM) │     │ (Radicale)   │     │ 48 hours     │     │ Email notify │
└──────────────┘     └──────────────┘     └──────────────┘     └──────────────┘
```

### Nodes

1. **Cron Trigger** — daily at 08:00 (configurable)
2. **HTTP Request → Radicale** — CalDAV `REPORT` request to `http://radicale:5232/<user>/<calendar>/`
   with a `calendar-query` filter for `DTSTART` within the next 48 hours
3. **Filter / Split** — parse iCalendar data, filter events in the window
4. **Discord Send** — post formatted reminder: event name, date/time, location
5. **Email Send** (optional) — send reminder email to the mailing list

### Environment / credentials needed

- Radicale credentials (htpasswd user created during setup)
- Discord Bot Token
- SMTP credentials (if email reminders enabled)

---

## 5. Vikunja Task Sync

Automatically creates tasks in Vikunja from meeting action items and optionally
syncs due dates to the Radicale calendar.

```
┌──────────────┐     ┌──────────────┐     ┌──────────────┐
│ Vikunja      │────▸│ Parse action │────▸│ Radicale     │
│ Webhook      │     │ items        │     │ CalDAV PUT   │
└──────────────┘     └──────────────┘     └──────────────┘
```

### Nodes

1. **Webhook** — triggered after Meeting Minutes workflow (workflow #3) completes
   - Receives the structured action items JSON
2. **Loop / Split** — iterate over each action item
3. **HTTP Request → Vikunja** — `POST /api/v1/projects/{id}/tasks` to create each task
   with title, description, assignee, and due date
4. **HTTP Request → Radicale** — `PUT` a VEVENT to the shared calendar for each
   task with a due date

### Environment / credentials needed

- Vikunja API token
- Radicale credentials

---

## System prompt template

Save this as a reference for workflows #1, #2, and #3. Customise the FAQ
content with your squadron's actual information.

```text
You are "CadetBot", an AI assistant for [Squadron Name] Australian/Canadian Air Force Cadets.

Key information:
- Parade nights: [day] at [time], [location]
- Commanding Officer: [name]
- Enrolment: contact [email/phone] or visit [URL]
- Uniform: [brief policy]
- Upcoming events: query the shared calendar for current events

When answering:
- Be professional, friendly, and concise
- If you don't know the answer, say so and suggest contacting [CO name/email]
- Never make up information about dates, policies, or events
- For sensitive topics (disciplinary, medical), direct to the appropriate officer
```
