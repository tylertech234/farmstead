#!/bin/bash
# Run inside a container that can reach wikijs:3000
# Usage: docker exec nginx-proxy-manager bash /tmp/setup-wiki.sh

WIKI="http://wikijs:3000/graphql"

# Login
JWT=$(curl -s -X POST "$WIKI" \
  -H "Content-Type: application/json" \
  -d '{"query":"mutation { authentication { login(username: \"admin@meetstack.local\", password: \"MeetStack2026!\", strategy: \"local\") { responseResult { succeeded } jwt } } }"}' \
  | grep -o '"jwt":"[^"]*' | cut -d'"' -f4)

if [ -z "$JWT" ]; then
  echo "ERROR: Could not login to Wiki.js"
  exit 1
fi
echo "Logged in to Wiki.js"

AUTH="Authorization: Bearer $JWT"

# Create test pages using GraphQL variables (avoids escaping issues)
create_page() {
  local path="$1" title="$2" content="$3"
  curl -s -X POST "$WIKI" \
    -H "Content-Type: application/json" \
    -H "$AUTH" \
    -d @- <<EOF > /dev/null
{"query":"mutation CreatePage(\$content: String!, \$path: String!, \$title: String!) { pages { create(content: \$content, description: \"\", editor: \"markdown\", isPublished: true, isPrivate: false, locale: \"en\", path: \$path, tags: [], title: \$title) { responseResult { succeeded message } } } }","variables":{"content":"$content","path":"$path","title":"$title"}}
EOF
  echo "  Created: $title ($path)"
}

create_page "home" "Welcome to MeetStack" "# Welcome to MeetStack\\n\\nThis is the **Air Force Cadets** knowledge base.\\n\\n## Quick Links\\n- [Meeting Minutes](/meetings)\\n- [SOPs & Policies](/sops)\\n- [FAQ](/faq)\\n- [Contacts](/contacts)"

create_page "meetings" "Meeting Minutes" "# Meeting Minutes\\n\\n## 2026-03-25 — Weekly Standup\\n- **Attendees:** Tyler, Sarah, Mike\\n- **Agenda:** Equipment check, upcoming camp, website refresh\\n- **Action Items:**\\n  - Tyler: Order new radios (due Apr 1)\\n  - Sarah: Draft camp schedule (due Apr 5)\\n  - Mike: Update uniform guidelines on wiki\\n\\n## 2026-03-18 — Planning Session\\n- Discussed summer camp logistics\\n- Reviewed budget for Q2"

create_page "sops" "SOPs and Policies" "# Standard Operating Procedures\\n\\n## Uniform Standards\\nAll cadets must wear the approved uniform during official events.\\n\\n## Communication Protocol\\n1. Use the Discord channel for day-to-day comms\\n2. Email for formal requests\\n3. Wiki for documentation\\n\\n## Equipment Sign-Out\\nAll equipment must be signed out through Vikunja task board."

create_page "faq" "Frequently Asked Questions" "# FAQ\\n\\n## How do I join?\\nContact your local squadron or visit our website.\\n\\n## What is the meeting schedule?\\nWeekly meetings every Tuesday at 1830.\\n\\n## How do I access the shared calendar?\\nUse any CalDAV client (Thunderbird, Apple Calendar) and connect to the Radicale server."

create_page "contacts" "Contact Directory" "# Contact Directory\\n\\n| Name | Role | Email |\\n|------|------|-------|\\n| Tyler | Tech Lead | tyler@example.com |\\n| Sarah | Logistics | sarah@example.com |\\n| Mike | Training | mike@example.com |"

echo "Wiki.js setup complete!"
