#!/bin/bash
# Setup Vikunja with test projects and tasks
# Usage: docker exec nginx-proxy-manager bash /tmp/setup-vikunja.sh

VIK="http://vikunja:3456/api/v1"

# Register first user
curl -s -X POST "$VIK/register" \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","email":"admin@farmstead.local","password":"Farmstead2026!"}' > /dev/null
echo "Registered admin user"

# Login
TOKEN=$(curl -s -X POST "$VIK/login" \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"Farmstead2026!"}' \
  | grep -o '"token":"[^"]*' | cut -d'"' -f4)

if [ -z "$TOKEN" ]; then
  echo "ERROR: Could not login to Vikunja"
  exit 1
fi
echo "Logged in to Vikunja"
AUTH="Authorization: Bearer $TOKEN"

# Create projects
create_project() {
  local title="$1" desc="$2"
  local id=$(curl -s -X PUT "$VIK/projects" \
    -H "Content-Type: application/json" -H "$AUTH" \
    -d "{\"title\":\"$title\",\"description\":\"$desc\"}" \
    | grep -o '"id":[0-9]*' | head -1 | cut -d: -f2)
  echo "$id"
}

create_task() {
  local project_id="$1" title="$2" priority="$3" due="$4"
  local body="{\"title\":\"$title\",\"priority\":$priority"
  if [ -n "$due" ]; then
    body="$body,\"due_date\":\"${due}T17:00:00Z\""
  fi
  body="$body}"
  curl -s -X PUT "$VIK/projects/$project_id/tasks" \
    -H "Content-Type: application/json" -H "$AUTH" \
    -d "$body" > /dev/null
  echo "  Task: $title"
}

# Project 1: Meeting Action Items
PID1=$(create_project "Meeting Action Items" "Tasks from weekly meetings")
echo "Project: Meeting Action Items (ID: $PID1)"
create_task "$PID1" "Order new radios" 3 "2026-04-01"
create_task "$PID1" "Draft summer camp schedule" 2 "2026-04-05"
create_task "$PID1" "Update uniform guidelines on wiki" 1 "2026-04-10"
create_task "$PID1" "Book meeting room for April" 2 "2026-03-28"
create_task "$PID1" "Send minutes to all members" 1 "2026-03-27"

# Project 2: Summer Camp Planning
PID2=$(create_project "Summer Camp 2026" "Planning and logistics for summer camp")
echo "Project: Summer Camp 2026 (ID: $PID2)"
create_task "$PID2" "Reserve campsite" 3 "2026-04-15"
create_task "$PID2" "Collect permission forms" 2 "2026-05-01"
create_task "$PID2" "Arrange transport" 2 "2026-05-15"
create_task "$PID2" "Order catering" 1 "2026-05-20"
create_task "$PID2" "First aid kit inventory" 3 "2026-04-10"

# Project 3: Equipment Inventory
PID3=$(create_project "Equipment Inventory" "Track and maintain squadron equipment")
echo "Project: Equipment Inventory (ID: $PID3)"
create_task "$PID3" "Audit radio inventory" 2 "2026-04-01"
create_task "$PID3" "Replace worn tent poles" 1 "2026-04-15"
create_task "$PID3" "Service first aid kits" 3 "2026-03-30"
create_task "$PID3" "Update equipment sign-out sheet" 1 ""

echo "Vikunja setup complete!"
