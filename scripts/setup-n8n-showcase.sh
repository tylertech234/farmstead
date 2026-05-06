#!/bin/bash
# Create showcase n8n workflows that demonstrate the full Farmstead pipeline
# Usage: docker exec nginx-proxy-manager bash /tmp/setup-n8n-showcase.sh

N8N="http://n8n:5678"

echo "Logging in to n8n..."
LOGIN_RESP=$(curl -s -D /tmp/n8n-headers.txt -X POST "$N8N/rest/login" \
  -H "Content-Type: application/json" \
  -d '{"email":"admin@farmstead.local","password":"Farmstead2026!"}')

echo "$LOGIN_RESP" | grep -q '"id"' && echo "Login successful" || {
  echo "Login failed: $LOGIN_RESP"
  exit 1
}

TOKEN=$(grep -oP 'n8n-auth=\K[^;]+' /tmp/n8n-headers.txt)
if [ -z "$TOKEN" ]; then
  echo "ERROR: Could not extract auth token"
  exit 1
fi

AUTH="Cookie: n8n-auth=$TOKEN"

# ── Workflow 1: Meeting Minutes Pipeline (Webhook) ──────────────────────
# POST raw meeting notes → Ollama summarizes → publishes to Wiki.js
WORKFLOW1='{
  "name": "Meeting Minutes Pipeline",
  "nodes": [
    {
      "parameters": {
        "httpMethod": "POST",
        "path": "meeting-minutes",
        "responseMode": "responseNode",
        "options": {}
      },
      "id": "wh1",
      "name": "Receive Meeting Notes",
      "type": "n8n-nodes-base.webhook",
      "typeVersion": 2,
      "position": [200, 300],
      "webhookId": "meeting-minutes"
    },
    {
      "parameters": {
        "method": "POST",
        "url": "http://ollama:11434/api/generate",
        "sendBody": true,
        "specifyBody": "json",
        "jsonBody": "={\"model\":\"tinyllama\",\"prompt\":\"You are a meeting minutes assistant. Given the following raw meeting notes, produce clean formatted meeting minutes in Markdown with these sections: ## Attendees, ## Agenda, ## Discussion, ## Action Items. Be concise.\\n\\nRaw notes:\\n{{ $json.body.notes }}\",\"stream\":false}",
        "options": { "timeout": 120000 }
      },
      "id": "ollama1",
      "name": "Summarize with Ollama",
      "type": "n8n-nodes-base.httpRequest",
      "typeVersion": 4.2,
      "position": [420, 300]
    },
    {
      "parameters": {
        "method": "POST",
        "url": "http://wikijs:3000/graphql",
        "sendBody": true,
        "specifyBody": "json",
        "jsonBody": "={\"query\":\"mutation { pages { create(content: \\\"{{ $json.response.replace(/\\\"/g, \\'\\\\\\\\\\\"\\').replace(/\\n/g, \\'\\\\\\\\n\\') }}\\\", description: \\\"Auto-generated meeting minutes\\\", editor: \\\"markdown\\\", isPublished: true, isPrivate: false, locale: \\\"en\\\", path: \\\"meetings/{{ new Date().toISOString().split(\\'T\\')[0] }}\\\", tags: [], title: \\\"Minutes — {{ new Date().toISOString().split(\\'T\\')[0] }}\\\") { responseResult { succeeded message } } } }\"}",
        "options": {}
      },
      "id": "wiki1",
      "name": "Post to Wiki.js",
      "type": "n8n-nodes-base.httpRequest",
      "typeVersion": 4.2,
      "position": [640, 300],
      "disabled": true
    },
    {
      "parameters": {
        "respondWith": "json",
        "responseBody": "={{ { status: \"ok\", summary: $node[\"Summarize with Ollama\"].json.response } }}"
      },
      "id": "resp1",
      "name": "Return Summary",
      "type": "n8n-nodes-base.respondToWebhook",
      "typeVersion": 1.1,
      "position": [860, 300]
    },
    {
      "parameters": {},
      "id": "noop1",
      "name": "No Operation",
      "type": "n8n-nodes-base.noOp",
      "typeVersion": 1,
      "position": [640, 480]
    }
  ],
  "connections": {
    "Receive Meeting Notes": {
      "main": [[{"node": "Summarize with Ollama", "type": "main", "index": 0}]]
    },
    "Summarize with Ollama": {
      "main": [[{"node": "Post to Wiki.js", "type": "main", "index": 0}, {"node": "No Operation", "type": "main", "index": 0}]]
    },
    "Post to Wiki.js": {
      "main": [[{"node": "Return Summary", "type": "main", "index": 0}]]
    },
    "No Operation": {
      "main": [[{"node": "Return Summary", "type": "main", "index": 0}]]
    }
  },
  "settings": {},
  "staticData": null,
  "active": false
}'

RESULT1=$(curl -s -H "$AUTH" -X POST "$N8N/rest/workflows" \
  -H "Content-Type: application/json" \
  -d "$WORKFLOW1")
WF1_ID=$(echo "$RESULT1" | grep -o '"id":"[^"]*' | head -1 | cut -d'"' -f4)
echo "$RESULT1" | grep -q '"id"' && echo "Created: Meeting Minutes Pipeline (ID: $WF1_ID)" || echo "Failed: $RESULT1"

# Activate it
if [ -n "$WF1_ID" ]; then
  curl -s -H "$AUTH" -X PATCH "$N8N/rest/workflows/$WF1_ID" \
    -H "Content-Type: application/json" \
    -d '{"active": true}' > /dev/null 2>&1
  echo "  Activated Meeting Minutes Pipeline"
fi

# ── Workflow 2: Daily Task Digest ──────────────────────────────────────
# Cron trigger → fetch Vikunja tasks → Ollama formats a digest
WORKFLOW2='{
  "name": "Daily Task Digest",
  "nodes": [
    {
      "parameters": {
        "rule": {
          "interval": [{"triggerAtHour": 8}]
        }
      },
      "id": "cron1",
      "name": "Every Morning at 8am",
      "type": "n8n-nodes-base.scheduleTrigger",
      "typeVersion": 1.2,
      "position": [200, 300]
    },
    {
      "parameters": {
        "method": "GET",
        "url": "http://vikunja:3456/api/v1/tasks/all",
        "authentication": "genericCredentialType",
        "genericAuthType": "httpHeaderAuth",
        "options": {}
      },
      "id": "vik1",
      "name": "Get Vikunja Tasks",
      "type": "n8n-nodes-base.httpRequest",
      "typeVersion": 4.2,
      "position": [420, 300]
    },
    {
      "parameters": {
        "method": "POST",
        "url": "http://ollama:11434/api/generate",
        "sendBody": true,
        "specifyBody": "json",
        "jsonBody": "={\"model\":\"tinyllama\",\"prompt\":\"Format the following task list as a brief daily digest email. Group by priority (high/medium/low). Highlight any tasks due today or overdue. Keep it short and actionable.\\n\\nTasks: {{ JSON.stringify($json) }}\",\"stream\":false}",
        "options": { "timeout": 120000 }
      },
      "id": "ollama2",
      "name": "Format Digest with Ollama",
      "type": "n8n-nodes-base.httpRequest",
      "typeVersion": 4.2,
      "position": [640, 300]
    }
  ],
  "connections": {
    "Every Morning at 8am": {
      "main": [[{"node": "Get Vikunja Tasks", "type": "main", "index": 0}]]
    },
    "Get Vikunja Tasks": {
      "main": [[{"node": "Format Digest with Ollama", "type": "main", "index": 0}]]
    }
  },
  "settings": {},
  "staticData": null,
  "active": false
}'

RESULT2=$(curl -s -H "$AUTH" -X POST "$N8N/rest/workflows" \
  -H "Content-Type: application/json" \
  -d "$WORKFLOW2")
echo "$RESULT2" | grep -q '"id"' && echo "Created: Daily Task Digest" || echo "Failed: $RESULT2"

# ── Workflow 3: Wiki Search Bot (webhook) ─────────────────────────────
# POST a question → search Wiki.js → Ollama answers using wiki content
WORKFLOW3='{
  "name": "Wiki Q&A Bot",
  "nodes": [
    {
      "parameters": {
        "httpMethod": "POST",
        "path": "wiki-qa",
        "responseMode": "responseNode",
        "options": {}
      },
      "id": "wh3",
      "name": "Receive Question",
      "type": "n8n-nodes-base.webhook",
      "typeVersion": 2,
      "position": [200, 300],
      "webhookId": "wiki-qa"
    },
    {
      "parameters": {
        "method": "POST",
        "url": "http://wikijs:3000/graphql",
        "sendBody": true,
        "specifyBody": "json",
        "jsonBody": "={\"query\":\"{ pages { search(query: \\\"{{ $json.body.question }}\\\") { results { title path content } } } }\"}",
        "options": {}
      },
      "id": "wikisearch",
      "name": "Search Wiki.js",
      "type": "n8n-nodes-base.httpRequest",
      "typeVersion": 4.2,
      "position": [420, 300]
    },
    {
      "parameters": {
        "method": "POST",
        "url": "http://ollama:11434/api/generate",
        "sendBody": true,
        "specifyBody": "json",
        "jsonBody": "={\"model\":\"tinyllama\",\"prompt\":\"Answer the following question using ONLY the context provided. If the context does not contain the answer, say so.\\n\\nContext from wiki:\\n{{ JSON.stringify($json.data?.pages?.search?.results || []) }}\\n\\nQuestion: {{ $node[\\\"Receive Question\\\"].json.body.question }}\",\"stream\":false}",
        "options": { "timeout": 120000 }
      },
      "id": "ollama3",
      "name": "Answer with Ollama",
      "type": "n8n-nodes-base.httpRequest",
      "typeVersion": 4.2,
      "position": [640, 300]
    },
    {
      "parameters": {
        "respondWith": "json",
        "responseBody": "={{ { answer: $json.response } }}"
      },
      "id": "resp3",
      "name": "Return Answer",
      "type": "n8n-nodes-base.respondToWebhook",
      "typeVersion": 1.1,
      "position": [860, 300]
    }
  ],
  "connections": {
    "Receive Question": {
      "main": [[{"node": "Search Wiki.js", "type": "main", "index": 0}]]
    },
    "Search Wiki.js": {
      "main": [[{"node": "Answer with Ollama", "type": "main", "index": 0}]]
    },
    "Answer with Ollama": {
      "main": [[{"node": "Return Answer", "type": "main", "index": 0}]]
    }
  },
  "settings": {},
  "staticData": null,
  "active": false
}'

RESULT3=$(curl -s -H "$AUTH" -X POST "$N8N/rest/workflows" \
  -H "Content-Type: application/json" \
  -d "$WORKFLOW3")
WF3_ID=$(echo "$RESULT3" | grep -o '"id":"[^"]*' | head -1 | cut -d'"' -f4)
echo "$RESULT3" | grep -q '"id"' && echo "Created: Wiki Q&A Bot (ID: $WF3_ID)" || echo "Failed: $RESULT3"

if [ -n "$WF3_ID" ]; then
  curl -s -H "$AUTH" -X PATCH "$N8N/rest/workflows/$WF3_ID" \
    -H "Content-Type: application/json" \
    -d '{"active": true}' > /dev/null 2>&1
  echo "  Activated Wiki Q&A Bot"
fi

echo ""
echo "n8n showcase setup complete!"
echo ""
echo "Demo workflows:"
echo "  1. Meeting Minutes Pipeline - POST notes, get AI summary (webhook active)"
echo "  2. Daily Task Digest - Fetches Vikunja tasks, formats with AI (scheduled)"
echo "  3. Wiki Q&A Bot - Ask questions, searches wiki, answers with AI (webhook active)"
echo "  4. Test: Chat with Ollama - Simple manual LLM test"
echo "  5. Webhook: Summarize Text - POST text, get bullet-point summary"
