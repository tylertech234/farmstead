#!/bin/bash
# Run inside a container that can reach wikijs:3000
# Usage: docker exec nginx-proxy-manager bash /tmp/setup-wiki.sh

WIKI="http://wikijs:3000/graphql"

# Login
JWT=$(curl -s -X POST "$WIKI" \
  -H "Content-Type: application/json" \
  -d '{"query":"mutation { authentication { login(username: \"admin@farmstead.local\", password: \"Farmstead2026!\", strategy: \"local\") { responseResult { succeeded } jwt } } }"}' \
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

create_page "home" "Welcome to Farmstead" "# Welcome to Farmstead\\n\\nThis is the **Farmstead operations** knowledge base.\\n\\n## Quick Links\\n- [Field Notes](/meetings)\\n- [Procedures](/sops)\\n- [FAQ](/faq)\\n- [Contacts](/contacts)"

create_page "meetings" "Field Notes" "# Field Notes\\n\\n## 2026-03-25 — Weekly Operations Review\\n- **Attendees:** Tyler, Sarah, Mike\\n- **Agenda:** Equipment check, seed inventory, irrigation repairs\\n- **Action Items:**\\n  - Tyler: Order replacement pump fittings (due Apr 1)\\n  - Sarah: Draft greenhouse planting schedule (due Apr 5)\\n  - Mike: Update maintenance checklist on wiki\\n\\n## 2026-03-18 — Planning Session\\n- Reviewed spring planting priorities\\n- Confirmed supply budget for Q2"

create_page "sops" "Procedures and Policies" "# Standard Operating Procedures\\n\\n## Daily Checklists\\nRecord greenhouse, water, and livestock checks before noon each day.\\n\\n## Communication Protocol\\n1. Use chat for day-to-day coordination\\n2. Email for formal requests\\n3. Wiki for documented procedures\\n\\n## Equipment Sign-Out\\nAll equipment must be signed out through the Vikunja task board."

create_page "faq" "Frequently Asked Questions" "# FAQ\\n\\n## How do I access the stack remotely?\\nConnect through your approved VPN or Tailscale route first.\\n\\n## When are operations reviewed?\\nWeekly planning happens every Tuesday evening.\\n\\n## How do I access the shared calendar?\\nUse any CalDAV client (Thunderbird, Apple Calendar) and connect to the Radicale server."

create_page "contacts" "Contact Directory" "# Contact Directory\\n\\n| Name | Role | Email |\\n|------|------|-------|\\n| Tyler | Operations Lead | tyler@example.com |\\n| Sarah | Logistics | sarah@example.com |\\n| Mike | Field Support | mike@example.com |"

echo "Wiki.js setup complete!"
