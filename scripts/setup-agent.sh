#!/bin/bash
# Set up the Farmstead AI Agent infrastructure:
#   1. Auto-detect GPU VRAM and pick the best model (or use OLLAMA_AGENT_MODEL)
#   2. Create Open WebUI Farmstead Agent preset
#   3. Create n8n Agent Router workflow (keyword extraction + RAG + Ollama)
#   4. Create n8n Escalation Manager workflow (creates Vikunja tasks)
#   5. Create n8n Learn from SO workflow (adds wiki pages from SO answers)
#
# Usage: docker exec nginx-proxy-manager bash /tmp/setup-agent.sh [model_name]
#   e.g. docker exec nginx-proxy-manager bash /tmp/setup-agent.sh llama3.1:8b

set -e

N8N="http://n8n:5678"
OLLAMA="http://ollama:11434"
OPENWEBUI="http://open-webui:8080"
WIKI="http://wikijs:3000"

# ── Step 0: Pick the right model ──────────────────────────────────────
# Priority: CLI arg > OLLAMA_AGENT_MODEL env > auto-detect via VRAM
if [ -n "${1:-}" ]; then
  MODEL="$1"
elif [ -n "${OLLAMA_AGENT_MODEL:-}" ]; then
  MODEL="$OLLAMA_AGENT_MODEL"
else
  echo "Auto-detecting best model for your GPU..."
  VRAM_BYTES=$(curl -s "$OLLAMA/api/ps" 2>/dev/null | grep -oP '"total":\K[0-9]+' | head -1 || true)
  if [ -z "$VRAM_BYTES" ]; then
    # Fallback: try nvidia-smi or assume low VRAM
    VRAM_GB=0
  else
    VRAM_GB=$(( VRAM_BYTES / 1073741824 ))
  fi

  if [ "$VRAM_GB" -ge 14 ]; then
    MODEL="llama3.1:13b"
  elif [ "$VRAM_GB" -ge 8 ]; then
    MODEL="llama3.1:8b"
  else
    MODEL="llama3.2:3b"
  fi
  echo "  Detected ~${VRAM_GB}GB VRAM → selected $MODEL"
fi

echo "Using model: $MODEL"

# ── Step 1: Pull model ────────────────────────────────────────────────
echo "Pulling $MODEL (this may take a few minutes)..."
curl -s -X POST "$OLLAMA/api/pull" \
  -H "Content-Type: application/json" \
  -d "{\"name\":\"$MODEL\",\"stream\":false}" | grep -q "success" && \
  echo "✓ Model pulled" || echo "⚠ Model pull may still be in progress"

# ── Step 2: Login to Open WebUI ───────────────────────────────────────
echo "Logging in to Open WebUI..."
OW_TOKEN=$(curl -s -X POST "$OPENWEBUI/api/v1/auths/signin" \
  -H "Content-Type: application/json" \
  -d '{"email":"admin@farmstead.local","password":"Farmstead2026!"}' \
  | grep -oP '"token"\s*:\s*"\K[^"]+')

if [ -z "$OW_TOKEN" ]; then
  echo "⚠ Open WebUI login failed - skipping agent preset"
else
  echo "✓ Open WebUI login successful"

  # Create Farmstead Agent model preset
  echo "Creating Farmstead Agent preset..."
  AGENT_PRESET="{\"id\":\"farmstead-agent\",\"name\":\"Farmstead Agent\",\"meta\":{\"profile_image_url\":\"/static/favicon.png\",\"description\":\"Context-aware AI assistant for Farmstead operations, notes, tasks, and schedules\",\"capabilities\":{\"vision\":false}},\"base_model_id\":\"$MODEL\",\"params\":{\"temperature\":0.4,\"top_p\":0.9,\"num_predict\":500,\"system\":\"You are Farmstead Agent, the AI assistant for a self-hosted farm and homestead operations platform called Farmstead.\\n\\nYou have access to:\\n- Wiki.js knowledge base with field notes, procedures, FAQ, and contact info\\n- Vikunja task management with chores, maintenance tasks, and projects\\n- Calendar via Radicale\\n- Whisper for speech-to-text\\n\\nKey knowledge:\\n- Team: Tyler (Operations), Sarah (Logistics), Mike (Field Support)\\n- Weekly operations reviews are documented in Field Notes\\n- Procedures cover equipment maintenance, irrigation, and scheduling\\n- FAQ covers stack access and routine operations\\n\\nBe concise, practical, and helpful. If you are not confident, say so and suggest escalating to an admin.\"}}"

  PRESET_RESP=$(curl -s -X POST "$OPENWEBUI/api/v1/models/add" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $OW_TOKEN" \
    -d "$AGENT_PRESET")
  echo "$PRESET_RESP" | grep -q "farmstead-agent" && \
    echo "✓ Agent preset created" || echo "⚠ Agent preset creation: $PRESET_RESP"
fi

# ── Step 3: Login to n8n ──────────────────────────────────────────────
echo ""
echo "Logging in to n8n..."
LOGIN_RESP=$(curl -s -D /tmp/n8n-headers.txt -X POST "$N8N/rest/login" \
  -H "Content-Type: application/json" \
  -d '{"email":"admin@farmstead.local","password":"Farmstead2026!"}')

echo "$LOGIN_RESP" | grep -q '"id"' && echo "✓ n8n login successful" || {
  echo "✗ n8n login failed"
  exit 1
}

TOKEN=$(grep -oP 'n8n-auth=\K[^;]+' /tmp/n8n-headers.txt)
AUTH="Cookie: n8n-auth=$TOKEN"

# ── Step 4: Farmstead Agent Router ────────────────────────────────────
# RAG pipeline: webhook → Code node (wiki search + Ollama) → respond
echo ""
echo "Creating Farmstead Agent Router..."

# The Code node JS is stored as a JSON string - escape carefully
read -r -d '' AGENT_CODE << 'JSEOF' || true
const userMessage = $input.all()[0].json.body.message;\nif (!userMessage) {\n  return [{ json: { answer: \"Please provide a message.\", source: \"system\" } }];\n}\n\n// Step 1: Extract search keywords using LLM (fixes full-sentence search issue)\nlet searchTerms = userMessage.substring(0, 100);\ntry {\n  const kwResp = await this.helpers.httpRequest({\n    method: \"POST\",\n    url: \"http://ollama:11434/api/generate\",\n    headers: { \"Content-Type\": \"application/json\" },\n    body: JSON.stringify({\n      model: \"AGENT_MODEL_PLACEHOLDER\",\n      prompt: \"Extract 1-3 search keywords from this question. Return ONLY the keywords separated by spaces, nothing else.\\n\\nQuestion: \" + userMessage + \"\\n\\nKeywords:\",\n      stream: false,\n      options: { temperature: 0.1, num_predict: 20 }\n    })\n  });\n  if (kwResp.response) searchTerms = kwResp.response.trim().substring(0, 100);\n} catch (e) {}\n\nlet wikiJwt = \"\";\ntry {\n  const loginResp = await this.helpers.httpRequest({\n    method: \"POST\",\n    url: \"http://wikijs:3000/graphql\",\n    headers: { \"Content-Type\": \"application/json\" },\n    body: JSON.stringify({\n      query: 'mutation { authentication { login(username: \\\"admin@farmstead.local\\\", password: \\\"Farmstead2026!\\\", strategy: \\\"local\\\") { jwt } } }'\n    })\n  });\n  wikiJwt = loginResp.data.authentication.login.jwt;\n} catch (e) {}\n\nlet wikiResults = [];\nif (wikiJwt) {\n  try {\n    const searchResp = await this.helpers.httpRequest({\n      method: \"POST\",\n      url: \"http://wikijs:3000/graphql\",\n      headers: { \"Content-Type\": \"application/json\", \"Authorization\": \"Bearer \" + wikiJwt },\n      body: JSON.stringify({\n        query: \"query SearchPages($q: String!) { pages { search(query: $q) { results { title path } } } }\",\n        variables: { q: searchTerms }\n      })\n    });\n    if (searchResp.data && searchResp.data.pages && searchResp.data.pages.search) {\n      wikiResults = searchResp.data.pages.search.results || [];\n    }\n  } catch (e) {}\n}\n\nlet wikiContext = \"\";\nfor (const page of wikiResults.slice(0, 3)) {\n  try {\n    const pageResp = await this.helpers.httpRequest({\n      method: \"POST\",\n      url: \"http://wikijs:3000/graphql\",\n      headers: { \"Content-Type\": \"application/json\", \"Authorization\": \"Bearer \" + wikiJwt },\n      body: JSON.stringify({\n        query: \"query GetPage($p: String!) { pages { singleByPath(path: $p, locale: \\\"en\\\") { title content } } }\",\n        variables: { p: page.path }\n      })\n    });\n    const pg = pageResp.data && pageResp.data.pages && pageResp.data.pages.singleByPath;\n    if (pg) wikiContext += \"\\n\\n--- \" + pg.title + \" ---\\n\" + pg.content.substring(0, 1500);\n  } catch (e) {}\n}\n\nlet taskContext = \"\";\ntry {\n  const vikLogin = await this.helpers.httpRequest({\n    method: \"POST\",\n    url: \"http://vikunja:3456/api/v1/login\",\n    headers: { \"Content-Type\": \"application/json\" },\n    body: JSON.stringify({ username: \"admin\", password: \"Farmstead2026!\" })\n  });\n  if (vikLogin.token) {\n    const taskList = await this.helpers.httpRequest({\n      method: \"GET\",\n      url: \"http://vikunja:3456/api/v1/tasks/all\",\n      headers: { \"Authorization\": \"Bearer \" + vikLogin.token }\n    });\n    if (Array.isArray(taskList)) {\n      const top5 = taskList.slice(0, 5).map(t => \"- [\" + (t.done ? \"x\" : \" \") + \"] \" + t.title).join(\"\\n\");\n      taskContext = \"\\n\\nRecent Tasks:\\n\" + top5;\n    }\n  }\n} catch (e) {}\n\nconst prompt = \"You are Farmstead Agent. Answer based on context below. If unsure, suggest escalating to an admin.\\n\\nWIKI CONTEXT:\" + (wikiContext || \"\\nNo wiki results.\") + taskContext + \"\\n\\nUSER: \" + userMessage + \"\\n\\nAnswer concisely:\";\n\nlet answer = \"Sorry, I could not generate a response.\";\ntry {\n  const ollamaResp = await this.helpers.httpRequest({\n    method: \"POST\",\n    url: \"http://ollama:11434/api/generate\",\n    headers: { \"Content-Type\": \"application/json\" },\n    body: JSON.stringify({ model: \"AGENT_MODEL_PLACEHOLDER\", prompt: prompt, stream: false, options: { temperature: 0.4, num_predict: 500 } })\n  });\n  if (ollamaResp.response) answer = ollamaResp.response;\n} catch (e) { answer = \"Ollama is not responding.\"; }\n\nconst source = wikiResults.length > 0 ? wikiResults.map(r => r.title).join(\", \") : \"general knowledge\";\nreturn [{ json: { answer, source, wiki_results: wikiResults.length, search_terms: searchTerms } }];
JSEOF

AGENT_ROUTER=$(cat <<'EOF'
{
  "name": "Farmstead Agent Router",
  "active": false,
  "nodes": [
    {
      "parameters": { "httpMethod": "POST", "path": "agent", "responseMode": "responseNode", "options": {} },
      "id": "wh_agent", "name": "Webhook", "type": "n8n-nodes-base.webhook", "typeVersion": 2, "position": [260, 340], "webhookId": "agent-router"
    },
    {
      "parameters": { "jsCode": "AGENT_CODE_PLACEHOLDER" },
      "id": "code_agent", "name": "Agent Brain", "type": "n8n-nodes-base.code", "typeVersion": 2, "position": [480, 340]
    },
    {
      "parameters": { "respondWith": "json", "responseBody": "={{ $json }}", "options": {} },
      "id": "resp_agent", "name": "Respond", "type": "n8n-nodes-base.respondToWebhook", "typeVersion": 1.1, "position": [700, 340]
    }
  ],
  "connections": {
    "Webhook": { "main": [[{ "node": "Agent Brain", "type": "main", "index": 0 }]] },
    "Agent Brain": { "main": [[{ "node": "Respond", "type": "main", "index": 0 }]] }
  },
  "settings": { "executionOrder": "v1" }
}
EOF
)

# Replace placeholders with actual code and model
AGENT_ROUTER_FINAL=$(echo "$AGENT_ROUTER" | sed "s|AGENT_CODE_PLACEHOLDER|$AGENT_CODE|")
AGENT_ROUTER_FINAL=$(echo "$AGENT_ROUTER_FINAL" | sed "s|AGENT_MODEL_PLACEHOLDER|$MODEL|g")

RESP=$(curl -s -X POST "$N8N/rest/workflows" \
  -H "Content-Type: application/json" -H "$AUTH" \
  -d "$AGENT_ROUTER_FINAL")
AGENT_ID=$(echo "$RESP" | grep -oP '"id"\s*:\s*"\K[^"]+' | head -1)
if [ -n "$AGENT_ID" ]; then
  curl -s -X PATCH "$N8N/rest/workflows/$AGENT_ID" \
    -H "Content-Type: application/json" -H "$AUTH" \
    -d '{"active":true}' > /dev/null
  echo "✓ Agent Router created and activated ($AGENT_ID)"
else
  echo "⚠ Agent Router creation failed: $RESP"
fi

# ── Step 5: Escalation Manager ────────────────────────────────────────
echo "Creating Escalation Manager..."

ESCALATION_WF=$(cat <<'EOF'
{
  "name": "Escalation Manager",
  "active": false,
  "nodes": [
    {
      "parameters": { "httpMethod": "POST", "path": "escalate", "responseMode": "responseNode", "options": {} },
      "id": "wh_esc", "name": "Receive Escalation", "type": "n8n-nodes-base.webhook", "typeVersion": 2, "position": [200, 300], "webhookId": "escalate"
    },
    {
      "parameters": { "jsCode": "const body = $input.all()[0].json.body;\nconst question = body.question || \"No question provided\";\nconst user = body.user || \"unknown\";\nconst agentResponse = body.agent_response || \"No response\";\n\nlet vikToken = \"\";\ntry {\n  const login = await this.helpers.httpRequest({\n    method: \"POST\", url: \"http://vikunja:3456/api/v1/login\",\n    headers: { \"Content-Type\": \"application/json\" },\n    body: JSON.stringify({ username: \"admin\", password: \"Farmstead2026!\" })\n  });\n  vikToken = login.token;\n} catch (e) {\n  return [{ json: { status: \"error\", message: \"Vikunja auth failed\" } }];\n}\n\ntry {\n  const task = await this.helpers.httpRequest({\n    method: \"PUT\", url: \"http://vikunja:3456/api/v1/projects/1/tasks\",\n    headers: { \"Content-Type\": \"application/json\", \"Authorization\": \"Bearer \" + vikToken },\n    body: JSON.stringify({\n      title: \"[ESCALATION] \" + question.substring(0, 100),\n      description: \"**Question:** \" + question + \"\\n\\n**User:** \" + user + \"\\n\\n**Agent Response:** \" + agentResponse,\n      priority: 5\n    })\n  });\n  return [{ json: { status: \"escalated\", task_id: task.id, message: \"Escalation created for admin review\" } }];\n} catch (e) {\n  return [{ json: { status: \"error\", message: \"Failed to create escalation task: \" + e.message } }];\n}" },
      "id": "code_esc", "name": "Process Escalation", "type": "n8n-nodes-base.code", "typeVersion": 2, "position": [440, 300]
    },
    {
      "parameters": { "respondWith": "json", "responseBody": "={{ $json }}", "options": {} },
      "id": "resp_esc", "name": "Respond", "type": "n8n-nodes-base.respondToWebhook", "typeVersion": 1.1, "position": [660, 300]
    }
  ],
  "connections": {
    "Receive Escalation": { "main": [[{ "node": "Process Escalation", "type": "main", "index": 0 }]] },
    "Process Escalation": { "main": [[{ "node": "Respond", "type": "main", "index": 0 }]] }
  },
  "settings": { "executionOrder": "v1" }
}
EOF
)

RESP=$(curl -s -X POST "$N8N/rest/workflows" \
  -H "Content-Type: application/json" -H "$AUTH" \
  -d "$ESCALATION_WF")
ESC_ID=$(echo "$RESP" | grep -oP '"id"\s*:\s*"\K[^"]+' | head -1)
if [ -n "$ESC_ID" ]; then
  curl -s -X PATCH "$N8N/rest/workflows/$ESC_ID" \
    -H "Content-Type: application/json" -H "$AUTH" \
    -d '{"active":true}' > /dev/null
  echo "✓ Escalation Manager created and activated ($ESC_ID)"
else
  echo "⚠ Escalation Manager creation failed: $RESP"
fi

# ── Step 6: Learn from SO Response ────────────────────────────────────
echo "Creating Learn from SO Response..."

LEARN_WF=$(cat <<'EOF'
{
  "name": "Learn from SO Response",
  "active": false,
  "nodes": [
    {
      "parameters": { "httpMethod": "POST", "path": "learn", "responseMode": "responseNode", "options": {} },
      "id": "wh_learn", "name": "Receive Learning", "type": "n8n-nodes-base.webhook", "typeVersion": 2, "position": [200, 300], "webhookId": "learn"
    },
    {
      "parameters": { "jsCode": "const body = $input.all()[0].json.body;\nconst question = body.question || \"\";\nconst answer = body.answer || \"\";\nif (!question || !answer) {\n  return [{ json: { status: \"error\", message: \"Both question and answer are required\" } }];\n}\n\nlet wikiJwt = \"\";\ntry {\n  const login = await this.helpers.httpRequest({\n    method: \"POST\", url: \"http://wikijs:3000/graphql\",\n    headers: { \"Content-Type\": \"application/json\" },\n    body: JSON.stringify({\n      query: 'mutation { authentication { login(username: \\\"admin@farmstead.local\\\", password: \\\"Farmstead2026!\\\", strategy: \\\"local\\\") { jwt } } }'\n    })\n  });\n  wikiJwt = login.data.authentication.login.jwt;\n} catch (e) {\n  return [{ json: { status: \"error\", message: \"Wiki.js auth failed\" } }];\n}\n\nconst slug = \"learned/\" + question.substring(0, 50).toLowerCase().replace(/[^a-z0-9]+/g, \"-\").replace(/-+$/, \"\");\nconst content = \"# \" + question + \"\\n\\n**Answer (verified by Admin):**\\n\\n\" + answer + \"\\n\\n---\\n*Added via Farmstead learning pipeline on \" + new Date().toISOString().split(\"T\")[0] + \"*\";\n\ntry {\n  const result = await this.helpers.httpRequest({\n    method: \"POST\", url: \"http://wikijs:3000/graphql\",\n    headers: { \"Content-Type\": \"application/json\", \"Authorization\": \"Bearer \" + wikiJwt },\n    body: JSON.stringify({\n      query: \"mutation CreatePage($content: String!, $path: String!, $title: String!) { pages { create(content: $content, description: \\\"\\\", editor: \\\"markdown\\\", isPublished: true, isPrivate: false, locale: \\\"en\\\", path: $path, tags: [], title: $title) { responseResult { succeeded message } page { id path } } } }\",\n      variables: { content: content, path: slug, title: question.substring(0, 100) }\n    })\n  });\n  const res = result.data.pages.create;\n  if (res.responseResult.succeeded) {\n    return [{ json: { status: \"learned\", page_path: res.page.path, message: \"Knowledge added to wiki\" } }];\n  } else {\n    return [{ json: { status: \"error\", message: res.responseResult.message } }];\n  }\n} catch (e) {\n  return [{ json: { status: \"error\", message: \"Failed to create wiki page: \" + e.message } }];\n}" },
      "id": "code_learn", "name": "Process Learning", "type": "n8n-nodes-base.code", "typeVersion": 2, "position": [440, 300]
    },
    {
      "parameters": { "respondWith": "json", "responseBody": "={{ $json }}", "options": {} },
      "id": "resp_learn", "name": "Respond", "type": "n8n-nodes-base.respondToWebhook", "typeVersion": 1.1, "position": [660, 300]
    }
  ],
  "connections": {
    "Receive Learning": { "main": [[{ "node": "Process Learning", "type": "main", "index": 0 }]] },
    "Process Learning": { "main": [[{ "node": "Respond", "type": "main", "index": 0 }]] }
  },
  "settings": { "executionOrder": "v1" }
}
EOF
)

RESP=$(curl -s -X POST "$N8N/rest/workflows" \
  -H "Content-Type: application/json" -H "$AUTH" \
  -d "$LEARN_WF")
LEARN_ID=$(echo "$RESP" | grep -oP '"id"\s*:\s*"\K[^"]+' | head -1)
if [ -n "$LEARN_ID" ]; then
  curl -s -X PATCH "$N8N/rest/workflows/$LEARN_ID" \
    -H "Content-Type: application/json" -H "$AUTH" \
    -d '{"active":true}' > /dev/null
  echo "✓ Learn from SO created and activated ($LEARN_ID)"
else
  echo "⚠ Learn from SO creation failed: $RESP"
fi

# ── Summary ───────────────────────────────────────────────────────────
echo ""
echo "═══════════════════════════════════════════════════════"
echo "  Farmstead Agent Infrastructure Setup Complete"
echo "═══════════════════════════════════════════════════════"
echo ""
echo "  Model:      $MODEL"
echo "  Open WebUI: Farmstead Agent preset available"
echo ""
echo "  n8n Webhooks:"
echo "    POST /webhook/agent    → AI agent with wiki RAG"
echo "    POST /webhook/escalate → Create SO review task"
echo "    POST /webhook/learn    → Add SO answer to wiki"
echo ""
echo "  Test:"
echo "    curl -X POST http://n8n.localhost/webhook/agent \\"
echo "      -H 'Content-Type: application/json' \\"
echo "      -d '{\"message\": \"What are the meeting minutes about?\"}'"
echo ""
