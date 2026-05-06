#!/bin/bash
# Vikunja seed script — creates all projects and tasks via REST API
# Usage: VIKUNJA_TOKEN=your_token_here bash seed-vikunja.sh

VIKUNJA_URL="${VIKUNJA_URL:-http://localhost:3456}"
TOKEN="${VIKUNJA_TOKEN:?Error: Set VIKUNJA_TOKEN environment variable}"
API="$VIKUNJA_URL/api/v1"

json_id() {
  python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('id',''))" 2>/dev/null
}

create_project() {
  local title="$1" color="$2"
  curl -sf -X POST "$API/projects" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    -d "{\"title\":\"$title\",\"hex_color\":\"$color\"}" | json_id
}

create_task() {
  local project_id="$1" title="$2" description="$3" priority="$4"
  python3 -c "
import sys, json, urllib.request
data = json.dumps({'title': sys.argv[1], 'description': sys.argv[2], 'priority': int(sys.argv[3])}).encode()
req = urllib.request.Request('$API/projects/$project_id/tasks', data=data, method='PUT')
req.add_header('Authorization', 'Bearer $TOKEN')
req.add_header('Content-Type', 'application/json')
resp = urllib.request.urlopen(req)
print(json.load(resp).get('id',''))
" "$title" "$description" "$priority" 2>/dev/null
}

create_subtask() {
  local project_id="$1" parent_id="$2" title="$3"
  local child_id
  child_id=$(python3 -c "
import sys, json, urllib.request
data = json.dumps({'title': sys.argv[1], 'priority': 0}).encode()
req = urllib.request.Request('$API/projects/$project_id/tasks', data=data, method='PUT')
req.add_header('Authorization', 'Bearer $TOKEN')
req.add_header('Content-Type', 'application/json')
resp = urllib.request.urlopen(req)
print(json.load(resp).get('id',''))
" "$title" 2>/dev/null)
  if [ -n "$child_id" ] && [ -n "$parent_id" ]; then
    python3 -c "
import json, urllib.request
data = json.dumps({'other_task_id': $child_id, 'relation_kind': 'subtask'}).encode()
req = urllib.request.Request('$API/tasks/$parent_id/relations', data=data, method='POST')
req.add_header('Authorization', 'Bearer $TOKEN')
req.add_header('Content-Type', 'application/json')
urllib.request.urlopen(req)
" 2>/dev/null
  fi
}

echo "Creating projects..."

# ─── Outdoor & Property ─────────────────────────────────────────────────────
P=$(create_project "🌿 Outdoor & Property" "4caf50")
echo "  Created: Outdoor & Property (id=$P)"
T=$(create_task $P "Mulch around peach tree" "Apply 3-4 inches of mulch around the drip line. Keep 6 inches away from trunk." 2)
create_subtask $P $T "Buy mulch (2-3 cubic yards)"
create_subtask $P $T "Clear existing weeds around drip line"
create_subtask $P $T "Apply 3-4 inch layer around drip line"
create_subtask $P $T "Ensure 6 inch gap between mulch and trunk"
T=$(create_task $P "Clear brush around fence lines" "Remove overgrown brush along all fence lines to maintain access and reduce fire risk." 2)
create_subtask $P $T "Clear north fence line"
create_subtask $P $T "Clear south fence line"
create_subtask $P $T "Clear east fence line"
create_subtask $P $T "Clear west fence line"
create_subtask $P $T "Dispose of brush (burn pile or haul off)"

# ─── Garage & Workshop ──────────────────────────────────────────────────────
P=$(create_project "🔨 Garage & Workshop" "ff9800")
echo "  Created: Garage & Workshop (id=$P)"
T=$(create_task $P "Clean out garage" "Full cleanout — sort keep, donate, trash. Prerequisite for all finish work." 4)
create_subtask $P $T "Sort all items (keep / donate / trash)"
create_subtask $P $T "Haul out trash"
create_subtask $P $T "Donate or list unwanted items"
create_subtask $P $T "Sweep and clean floor"
T=$(create_task $P "Clean out workshop" "Organize and clean workshop space. Clear workbenches and floor." 3)
create_subtask $P $T "Clear all workbench surfaces"
create_subtask $P $T "Organize tools by category"
create_subtask $P $T "Dispose of scrap material"
create_subtask $P $T "Sweep and clean floor"
T=$(create_task $P "Run new power to garage" "Run dedicated circuit or subpanel. Do before mini split install." 4)
create_subtask $P $T "Plan circuit requirements (loads, panel capacity)"
create_subtask $P $T "Pull permit if required"
create_subtask $P $T "Run conduit from main panel"
create_subtask $P $T "Pull wire and install breaker"
create_subtask $P $T "Install outlets and subpanel"
create_subtask $P $T "Schedule inspection if required"
T=$(create_task $P "Install mini split in garage" "Ductless mini split for heating and cooling. Requires new power circuit first." 2)
create_subtask $P $T "Get quotes from HVAC contractors"
create_subtask $P $T "Calculate BTU requirements for space"
create_subtask $P $T "Purchase unit"
create_subtask $P $T "Confirm electrical rough-in is complete"
create_subtask $P $T "Schedule HVAC installation"
create_subtask $P $T "Test unit operation"
T=$(create_task $P "Finish interior of garage" "Drywall, paint, trim. Blocked by cleanout and electrical." 2)
create_subtask $P $T "Hang and tape drywall"
create_subtask $P $T "Mud and sand"
create_subtask $P $T "Prime and paint walls"
create_subtask $P $T "Install trim and baseboards"

# ─── Home Renovation ────────────────────────────────────────────────────────
P=$(create_project "🏠 Home Renovation" "2196f3")
echo "  Created: Home Renovation (id=$P)"
T=$(create_task $P "Run new power to kitchen" "Dedicated circuits for countertops, dishwasher, range. Do before cabinets." 4)
create_subtask $P $T "Plan all kitchen circuits"
create_subtask $P $T "Pull permit"
create_subtask $P $T "Run rough-in wiring"
create_subtask $P $T "Install outlets and breakers"
create_subtask $P $T "Schedule inspection"
T=$(create_task $P "Install kitchen cabinets" "Full cabinet installation. Order lead time 4-8 weeks. Depends on power rough-in." 3)
create_subtask $P $T "Measure kitchen and create cabinet layout"
create_subtask $P $T "Select cabinet style and order"
create_subtask $P $T "Demo existing cabinets if needed"
create_subtask $P $T "Mark studs and install ledger board"
create_subtask $P $T "Install upper cabinets"
create_subtask $P $T "Install lower cabinets"
create_subtask $P $T "Install doors and hardware"
T=$(create_task $P "Install appliances" "Range, dishwasher, refrigerator, hood. Depends on cabinets and power." 2)
create_subtask $P $T "Verify rough-in locations for gas/electric/water"
create_subtask $P $T "Install range/oven"
create_subtask $P $T "Install dishwasher"
create_subtask $P $T "Install refrigerator"
create_subtask $P $T "Install range hood"
create_subtask $P $T "Test all appliances"
T=$(create_task $P "Finish floors" "Install finished flooring throughout remaining areas. Do after walls are complete." 3)
create_subtask $P $T "Measure and calculate square footage per room"
create_subtask $P $T "Select and order flooring material"
create_subtask $P $T "Prep subfloor (level, clean, dry)"
create_subtask $P $T "Install flooring"
create_subtask $P $T "Install transitions and trim"
T=$(create_task $P "Finish utility room" "Drywall, paint, shelving, verify all utility connections." 2)
create_subtask $P $T "Hang and finish drywall"
create_subtask $P $T "Paint"
create_subtask $P $T "Install shelving and storage"
create_subtask $P $T "Verify water, gas, and electric connections"
T=$(create_task $P "Fix sink fixtures in bathroom" "Replace or repair faucet, handles, and drain fixtures." 2)
create_subtask $P $T "Identify all fixtures to replace"
create_subtask $P $T "Purchase replacement fixtures"
create_subtask $P $T "Shut off water supply"
create_subtask $P $T "Remove old fixtures"
create_subtask $P $T "Install new fixtures"
create_subtask $P $T "Turn water back on and test for leaks"

# ─── Tech & Computing ───────────────────────────────────────────────────────
P=$(create_project "🤖 Tech & Computing" "9c27b0")
echo "  Created: Tech & Computing (id=$P)"
T=$(create_task $P "Build local AI machine (Axios)" "Dedicated AI inference machine. Will run Ollama, ChromaDB, ComfyUI as backend for farmstead." 3)
create_subtask $P $T "Finalize parts list (CPU, GPU, RAM, NVMe)"
create_subtask $P $T "Order components"
create_subtask $P $T "Build PC"
create_subtask $P $T "Install Ubuntu Server 24.04"
create_subtask $P $T "Install NVIDIA drivers and container toolkit"
create_subtask $P $T "Deploy Docker stack (Ollama, ChromaDB, ComfyUI)"
create_subtask $P $T "Point Open-WebUI on farmstead to Axios Ollama"
create_subtask $P $T "Test RAG pipeline with wiki documents"
T=$(create_task $P "Build microATX machine for pinball cabinet" "Small form factor PC for Virtual Pinball X and PinballY front-end." 1)
create_subtask $P $T "Choose case and form factor"
create_subtask $P $T "Source parts (GPU for DMD + playfield output)"
create_subtask $P $T "Build machine"
create_subtask $P $T "Install Windows + Visual Pinball X"
create_subtask $P $T "Set up PinballY front-end"
create_subtask $P $T "Download and test tables"
create_subtask $P $T "Mount in cabinet"

# ─── Retro & Arcade ─────────────────────────────────────────────────────────
P=$(create_project "🕹️ Retro & Arcade" "f44336")
echo "  Created: Retro & Arcade (id=$P)"
T=$(create_task $P "Rebuild Mountain Dew arcade cabinet" "Full restoration — new monitor, reconditioned exterior, fresh MAME install with artwork." 1)
create_subtask $P $T "Assess current condition of cabinet"
create_subtask $P $T "Source replacement monitor (CRT or LCD)"
create_subtask $P $T "Recondition and repaint cabinet exterior"
create_subtask $P $T "Install Raspberry Pi or PC for MAME"
create_subtask $P $T "Configure controls and wiring harness"
create_subtask $P $T "Configure MAME/EmulationStation"
create_subtask $P $T "Source or print replacement artwork and bezel"
T=$(create_task $P "Setup Retro CRT open frame arcade" "Open-frame setup using a CRT with MiSTer FPGA or Pi for authentic scanlines." 1)
create_subtask $P $T "Source CRT TV (consumer or PVM)"
create_subtask $P $T "Build or source open frame stand"
create_subtask $P $T "Choose platform (MiSTer FPGA vs Pi vs PC)"
create_subtask $P $T "Install and configure software"
create_subtask $P $T "Wire arcade controls"
create_subtask $P $T "Calibrate picture and test scanlines"
T=$(create_task $P "Setup capture card and VCR for digitization" "Set up capture workflow. Prerequisite for VHS conversion project." 2)
create_subtask $P $T "Source or verify capture card (analog input)"
create_subtask $P $T "Test VCR playback quality — clean heads if needed"
create_subtask $P $T "Connect VCR → capture card → PC"
create_subtask $P $T "Install and configure OBS or VirtualDub2"
create_subtask $P $T "Test capture with a sample tape"
create_subtask $P $T "Define output format and storage path on farmstead"
T=$(create_task $P "Convert VHS tapes to digital" "Capture and archive all VHS tapes. Blocked by capture card setup." 2)
create_subtask $P $T "Catalog all tapes (label, content, estimated condition)"
create_subtask $P $T "Prioritize tapes (irreplaceable home video first)"
create_subtask $P $T "Capture each tape"
create_subtask $P $T "Encode to archival format (H.265/MKV)"
create_subtask $P $T "Organize and name files"
create_subtask $P $T "Back up to farmstead /mnt/data"
create_subtask $P $T "Store original tapes in protective cases"

# ─── Electronics & IoT ──────────────────────────────────────────────────────
P=$(create_project "⚡ Electronics & IoT" "00bcd4")
echo "  Created: Electronics & IoT (id=$P)"
T=$(create_task $P "Test solar battery with ESP32" "Prototype solar-charged ESP32 node. Log data to farmstead via MQTT." 2)
create_subtask $P $T "Gather components (ESP32, TP4056, LiPo/18650, solar panel)"
create_subtask $P $T "Wire solar panel → charge controller → battery → ESP32"
create_subtask $P $T "Write firmware to report voltage and uptime"
create_subtask $P $T "Deploy outside and test over 24-48 hours"
create_subtask $P $T "Send data to farmstead via MQTT → n8n"
T=$(create_task $P "Get LoRa device and test with solar light kit" "First step toward farm-wide sensor network. Test LoRa range and solar viability." 2)
create_subtask $P $T "Order LoRa module (TTGO LoRa32 or Heltec WiFi LoRa 32)"
create_subtask $P $T "Wire to solar light kit as power source"
create_subtask $P $T "Flash LoRa test firmware"
create_subtask $P $T "Set up LoRa gateway or second receiver node"
create_subtask $P $T "Test transmission range across property"
create_subtask $P $T "Document range results and plan sensor payload"

echo ""
echo "Done! All projects and tasks created."
