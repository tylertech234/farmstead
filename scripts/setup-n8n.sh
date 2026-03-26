#!/bin/bash
# Setup n8n with a sample workflow
# Usage: docker exec nginx-proxy-manager bash /tmp/setup-n8n.sh

N8N="http://n8n:5678"

echo "Logging in to n8n..."
LOGIN_RESP=$(curl -s -D /tmp/n8n-headers.txt -X POST "$N8N/rest/login" \
  -H "Content-Type: application/json" \
  -d '{"email":"admin@meetstack.local","password":"MeetStack2026!"}')

echo "$LOGIN_RESP" | grep -q '"id"' && echo "Login successful" || {
  echo "Login failed, trying to set up owner account..."
  SETUP_RESP=$(curl -s -X POST "$N8N/rest/owner/setup" \
    -H "Content-Type: application/json" \
    -d '{"email":"admin@meetstack.local","password":"MeetStack2026!","firstName":"Admin","lastName":"MeetStack"}')
  echo "$SETUP_RESP" | grep -q '"id"' && echo "Owner setup successful" || echo "Owner setup failed: $SETUP_RESP"

  # Login again after setup
  LOGIN_RESP=$(curl -s -D /tmp/n8n-headers.txt -X POST "$N8N/rest/login" \
    -H "Content-Type: application/json" \
    -d '{"email":"admin@meetstack.local","password":"MeetStack2026!"}')
  echo "$LOGIN_RESP" | grep -q '"id"' && echo "Login successful" || echo "Login still failing: $LOGIN_RESP"
}

# Extract JWT token from Set-Cookie header (Secure flag prevents cookie jar from working over HTTP)
TOKEN=$(grep -oP 'n8n-auth=\K[^;]+' /tmp/n8n-headers.txt)
if [ -z "$TOKEN" ]; then
  echo "ERROR: Could not extract auth token"
  exit 1
fi
echo "Got auth token"

# Create a test workflow: Manual Trigger -> Ollama -> Respond
WORKFLOW='{
  "name": "Test: Chat with Ollama",
  "nodes": [
    {
      "parameters": {},
      "id": "trigger1",
      "name": "Manual Trigger",
      "type": "n8n-nodes-base.manualTrigger",
      "typeVersion": 1,
      "position": [250, 300]
    },
    {
      "parameters": {
        "url": "http://ollama:11434/api/generate",
        "sendBody": true,
        "specifyBody": "json",
        "jsonBody": "={\"model\":\"tinyllama\",\"prompt\":\"Summarize what Air Force Cadets do in 2 sentences.\",\"stream\":false}",
        "options": {
          "timeout": 120000
        }
      },
      "id": "http1",
      "name": "Ask Ollama",
      "type": "n8n-nodes-base.httpRequest",
      "typeVersion": 4,
      "position": [450, 300]
    }
  ],
  "connections": {
    "Manual Trigger": {
      "main": [
        [{"node": "Ask Ollama", "type": "main", "index": 0}]
      ]
    }
  },
  "settings": {},
  "staticData": null,
  "active": false
}'

RESULT=$(curl -s -H "Cookie: n8n-auth=$TOKEN" -X POST "$N8N/rest/workflows" \
  -H "Content-Type: application/json" \
  -d "$WORKFLOW")

echo "$RESULT" | grep -q '"id"' && echo "Created workflow: Test Chat with Ollama" || echo "Failed to create workflow: $RESULT"

# Create a second workflow: Webhook -> summarize text -> respond
WORKFLOW2='{
  "name": "Webhook: Summarize Text",
  "nodes": [
    {
      "parameters": {
        "httpMethod": "POST",
        "path": "summarize"
      },
      "id": "webhook1",
      "name": "Webhook",
      "type": "n8n-nodes-base.webhook",
      "typeVersion": 1,
      "position": [250, 300]
    },
    {
      "parameters": {
        "url": "http://ollama:11434/api/generate",
        "sendBody": true,
        "specifyBody": "json",
        "jsonBody": "={\"model\":\"tinyllama\",\"prompt\":\"Summarize the following text in bullet points:\\n\\n{{ $json.body.text }}\",\"stream\":false}",
        "options": {
          "timeout": 120000
        }
      },
      "id": "http2",
      "name": "Summarize with Ollama",
      "type": "n8n-nodes-base.httpRequest",
      "typeVersion": 4,
      "position": [450, 300]
    },
    {
      "parameters": {
        "respondWith": "json",
        "responseBody": "={{ { summary: $json.response } }}"
      },
      "id": "respond1",
      "name": "Respond",
      "type": "n8n-nodes-base.respondToWebhook",
      "typeVersion": 1,
      "position": [650, 300]
    }
  ],
  "connections": {
    "Webhook": {
      "main": [
        [{"node": "Summarize with Ollama", "type": "main", "index": 0}]
      ]
    },
    "Summarize with Ollama": {
      "main": [
        [{"node": "Respond", "type": "main", "index": 0}]
      ]
    }
  },
  "settings": {},
  "staticData": null,
  "active": false
}'

RESULT2=$(curl -s -H "Cookie: n8n-auth=$TOKEN" -X POST "$N8N/rest/workflows" \
  -H "Content-Type: application/json" \
  -d "$WORKFLOW2")

echo "$RESULT2" | grep -q '"id"' && echo "Created workflow: Summarize Text Webhook" || echo "Failed: $RESULT2"

echo "n8n setup complete!"
