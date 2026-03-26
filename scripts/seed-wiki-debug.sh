#!/bin/bash
WIKI="http://wikijs:3000/graphql"

JWT=$(curl -s -X POST "$WIKI" \
  -H "Content-Type: application/json" \
  -d '{"query":"mutation { authentication { login(username: \"admin@meetstack.local\", password: \"MeetStack2026!\", strategy: \"local\") { responseResult { succeeded } jwt } } }"}' \
  | grep -o '"jwt":"[^"]*' | cut -d'"' -f4)

if [ -z "$JWT" ]; then
  echo "ERROR: Could not login to Wiki.js"
  exit 1
fi
echo "Logged in (jwt=${JWT:0:20}...)"

AUTH="Authorization: Bearer $JWT"

# Use GraphQL variables to avoid nested escaping issues
create_page() {
  local path="$1" title="$2" content="$3"
  # Build proper JSON with jq-like printf to handle escaping
  PAYLOAD=$(printf '{"query":"mutation CreatePage($content: String!, $path: String!, $title: String!) { pages { create(content: $content, description: \"\", editor: \"markdown\", isPublished: true, isPrivate: false, locale: \"en\", path: $path, tags: [], title: $title) { responseResult { succeeded message } } } }","variables":{"content":"%s","path":"%s","title":"%s"}}' "$content" "$path" "$title")
  RESP=$(curl -s -X POST "$WIKI" \
    -H "Content-Type: application/json" \
    -H "$AUTH" \
    -d "$PAYLOAD")
  SUCCEEDED=$(echo "$RESP" | grep -o '"succeeded":true')
  if [ -n "$SUCCEEDED" ]; then
    echo "  OK: $title ($path)"
  else
    echo "  FAIL: $title ($path): $RESP"
  fi
}

echo "Creating pages..."
create_page "meetings" "Meeting Minutes" "# Meeting Minutes

## 2026-03-25 — Weekly Standup
- **Attendees:** Tyler, Sarah, Mike
- **Agenda:** Equipment check, upcoming camp, website refresh
- **Action Items:**
  - Tyler: Order new radios (due Apr 1)
  - Sarah: Draft camp schedule (due Apr 5)
  - Mike: Update uniform guidelines on wiki

## 2026-03-18 — Planning Session
- Discussed summer camp logistics
- Reviewed budget for Q2"

create_page "sops" "SOPs and Policies" "# Standard Operating Procedures

## Uniform Standards
All cadets must wear the approved uniform during official events.

## Communication Protocol
1. Use the Discord channel for day-to-day comms
2. Email for formal requests
3. Wiki for documentation

## Equipment Sign-Out
All equipment must be signed out through Vikunja task board."

create_page "faq" "Frequently Asked Questions" "# FAQ

## How do I join?
Contact your local squadron or visit our website.

## What is the meeting schedule?
Weekly meetings every Tuesday at 1830.

## How do I access the shared calendar?
Use any CalDAV client (Thunderbird, Apple Calendar) and connect to the Radicale server."

create_page "contacts" "Contact Directory" "# Contact Directory

| Name | Role | Email |
|------|------|-------|
| Tyler | Tech Lead | tyler@example.com |
| Sarah | Logistics | sarah@example.com |
| Mike | Training | mike@example.com |"

echo "Done."
