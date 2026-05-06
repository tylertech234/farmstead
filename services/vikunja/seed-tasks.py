#!/usr/bin/env python3
"""Seed Vikunja with projects and tasks via REST API."""
import json
import os
import sys
import urllib.request
import urllib.error

VIKUNJA_URL = os.environ.get("VIKUNJA_URL", "http://localhost:3456")
TOKEN = os.environ.get("VIKUNJA_TOKEN")

if not TOKEN:
    print("Error: set VIKUNJA_TOKEN environment variable")
    sys.exit(1)

API = f"{VIKUNJA_URL}/api/v1"
HEADERS = {
    "Authorization": f"Bearer {TOKEN}",
    "Content-Type": "application/json",
}


def request(method, path, data=None):
    body = json.dumps(data).encode() if data else None
    req = urllib.request.Request(f"{API}{path}", data=body, method=method, headers=HEADERS)
    try:
        with urllib.request.urlopen(req) as resp:
            return json.load(resp)
    except urllib.error.HTTPError as e:
        print(f"  ERROR {e.code} {method} {path}: {e.read().decode()}")
        return {}


def create_project(title, color):
    resp = request("PUT", "/projects", {"title": title, "hex_color": color})
    pid = resp.get("id")
    print(f"  Created: {title} (id={pid})")
    return pid


def create_task(project_id, title, description="", priority=0):
    resp = request("PUT", f"/projects/{project_id}/tasks", {
        "title": title,
        "description": description,
        "priority": priority,
    })
    return resp.get("id")


def create_subtask(project_id, parent_id, title):
    child_id = create_task(project_id, title)
    if child_id and parent_id:
        request("PUT", f"/tasks/{parent_id}/relations", {
            "other_task_id": child_id,
            "relation_kind": "subtask",
        })


print("Creating projects and tasks...")

# ─── Outdoor & Property ──────────────────────────────────────────────────────
p = create_project("🌿 Outdoor & Property", "4caf50")
if p:
    t = create_task(p, "Mulch around peach tree", "Apply 3-4 inches of mulch around the drip line. Keep 6 inches away from trunk.", 2)
    for s in ["Buy mulch (2-3 cubic yards)", "Clear existing weeds around drip line", "Apply 3-4 inch layer around drip line", "Ensure 6 inch gap between mulch and trunk"]:
        create_subtask(p, t, s)
    t = create_task(p, "Clear brush around fence lines", "Remove overgrown brush along all fence lines.", 2)
    for s in ["Clear north fence line", "Clear south fence line", "Clear east fence line", "Clear west fence line", "Dispose of brush (burn pile or haul off)"]:
        create_subtask(p, t, s)

# ─── Garage & Workshop ───────────────────────────────────────────────────────
p = create_project("🔨 Garage & Workshop", "ff9800")
if p:
    t = create_task(p, "Clean out garage", "Full cleanout — sort keep, donate, trash. Prerequisite for all finish work.", 4)
    for s in ["Sort all items (keep / donate / trash)", "Haul out trash", "Donate or list unwanted items", "Sweep and clean floor"]:
        create_subtask(p, t, s)
    t = create_task(p, "Clean out workshop", "Organize and clean workshop space. Clear workbenches and floor.", 3)
    for s in ["Clear all workbench surfaces", "Organize tools by category", "Dispose of scrap material", "Sweep and clean floor"]:
        create_subtask(p, t, s)
    t = create_task(p, "Run new power to garage", "Run dedicated circuit or subpanel. Do before mini split install.", 4)
    for s in ["Plan circuit requirements (loads, panel capacity)", "Pull permit if required", "Run conduit from main panel", "Pull wire and install breaker", "Install outlets and subpanel", "Schedule inspection if required"]:
        create_subtask(p, t, s)
    t = create_task(p, "Install mini split in garage", "Ductless mini split for heating and cooling. Requires new power circuit first.", 2)
    for s in ["Get quotes from HVAC contractors", "Calculate BTU requirements for space", "Purchase unit", "Confirm electrical rough-in is complete", "Schedule HVAC installation", "Test unit operation"]:
        create_subtask(p, t, s)
    t = create_task(p, "Finish interior of garage", "Drywall, paint, trim. Blocked by cleanout and electrical.", 2)
    for s in ["Hang and tape drywall", "Mud and sand", "Prime and paint walls", "Install trim and baseboards"]:
        create_subtask(p, t, s)

# ─── Home Renovation ─────────────────────────────────────────────────────────
p = create_project("🏠 Home Renovation", "2196f3")
if p:
    t = create_task(p, "Run new power to kitchen", "Dedicated circuits for countertops, dishwasher, range. Do before cabinets.", 4)
    for s in ["Plan all kitchen circuits", "Pull permit", "Run rough-in wiring", "Install outlets and breakers", "Schedule inspection"]:
        create_subtask(p, t, s)
    t = create_task(p, "Install kitchen cabinets", "Full cabinet installation. Order lead time 4-8 weeks. Depends on power rough-in.", 3)
    for s in ["Measure kitchen and create cabinet layout", "Select cabinet style and order", "Demo existing cabinets if needed", "Mark studs and install ledger board", "Install upper cabinets", "Install lower cabinets", "Install doors and hardware"]:
        create_subtask(p, t, s)
    t = create_task(p, "Install appliances", "Range, dishwasher, refrigerator, hood. Depends on cabinets and power.", 2)
    for s in ["Verify rough-in locations for gas/electric/water", "Install range/oven", "Install dishwasher", "Install refrigerator", "Install range hood", "Test all appliances"]:
        create_subtask(p, t, s)
    t = create_task(p, "Finish floors", "Install finished flooring throughout remaining areas. Do after walls are complete.", 3)
    for s in ["Measure and calculate square footage per room", "Select and order flooring material", "Prep subfloor (level, clean, dry)", "Install flooring", "Install transitions and trim"]:
        create_subtask(p, t, s)
    t = create_task(p, "Finish utility room", "Drywall, paint, shelving, verify all utility connections.", 2)
    for s in ["Hang and finish drywall", "Paint", "Install shelving and storage", "Verify water, gas, and electric connections"]:
        create_subtask(p, t, s)
    t = create_task(p, "Fix sink fixtures in bathroom", "Replace or repair faucet, handles, and drain fixtures.", 2)
    for s in ["Identify all fixtures to replace", "Purchase replacement fixtures", "Shut off water supply", "Remove old fixtures", "Install new fixtures", "Turn water back on and test for leaks"]:
        create_subtask(p, t, s)

# ─── Tech & Computing ────────────────────────────────────────────────────────
p = create_project("🤖 Tech & Computing", "9c27b0")
if p:
    t = create_task(p, "Build local AI machine (Axios)", "Dedicated AI inference machine. Will run Ollama, ChromaDB, ComfyUI as backend for farmstead.", 3)
    for s in ["Finalize parts list (CPU, GPU, RAM, NVMe)", "Order components", "Build PC", "Install Ubuntu Server 24.04", "Install NVIDIA drivers and container toolkit", "Deploy Docker stack (Ollama, ChromaDB, ComfyUI)", "Point Open-WebUI on farmstead to Axios Ollama", "Test RAG pipeline with wiki documents"]:
        create_subtask(p, t, s)
    t = create_task(p, "Build microATX machine for pinball cabinet", "Small form factor PC for Virtual Pinball X and PinballY front-end.", 1)
    for s in ["Choose case and form factor", "Source parts (GPU for DMD + playfield output)", "Build machine", "Install Windows + Visual Pinball X", "Set up PinballY front-end", "Download and test tables", "Mount in cabinet"]:
        create_subtask(p, t, s)

# ─── Retro & Arcade ──────────────────────────────────────────────────────────
p = create_project("🕹️ Retro & Arcade", "f44336")
if p:
    t = create_task(p, "Rebuild Mountain Dew arcade cabinet", "Full restoration — new monitor, reconditioned exterior, fresh MAME install with artwork.", 1)
    for s in ["Assess current condition of cabinet", "Source replacement monitor (CRT or LCD)", "Recondition and repaint cabinet exterior", "Install Raspberry Pi or PC for MAME", "Configure controls and wiring harness", "Configure MAME/EmulationStation", "Source or print replacement artwork and bezel"]:
        create_subtask(p, t, s)
    t = create_task(p, "Setup Retro CRT open frame arcade", "Open-frame setup using a CRT with MiSTer FPGA or Pi for authentic scanlines.", 1)
    for s in ["Source CRT TV (consumer or PVM)", "Build or source open frame stand", "Choose platform (MiSTer FPGA vs Pi vs PC)", "Install and configure software", "Wire arcade controls", "Calibrate picture and test scanlines"]:
        create_subtask(p, t, s)
    t = create_task(p, "Setup capture card and VCR for digitization", "Set up capture workflow. Prerequisite for VHS conversion project.", 2)
    for s in ["Source or verify capture card (analog input)", "Test VCR playback quality — clean heads if needed", "Connect VCR to capture card to PC", "Install and configure OBS or VirtualDub2", "Test capture with a sample tape", "Define output format and storage path on farmstead"]:
        create_subtask(p, t, s)
    t = create_task(p, "Convert VHS tapes to digital", "Capture and archive all VHS tapes. Blocked by capture card setup.", 2)
    for s in ["Catalog all tapes (label, content, estimated condition)", "Prioritize tapes (irreplaceable home video first)", "Capture each tape", "Encode to archival format (H.265/MKV)", "Organize and name files", "Back up to farmstead /mnt/data", "Store original tapes in protective cases"]:
        create_subtask(p, t, s)

# ─── Electronics & IoT ───────────────────────────────────────────────────────
p = create_project("⚡ Electronics & IoT", "00bcd4")
if p:
    t = create_task(p, "Test solar battery with ESP32", "Prototype solar-charged ESP32 node. Log data to farmstead via MQTT.", 2)
    for s in ["Gather components (ESP32, TP4056, LiPo/18650, solar panel)", "Wire solar panel to charge controller to battery to ESP32", "Write firmware to report voltage and uptime", "Deploy outside and test over 24-48 hours", "Send data to farmstead via MQTT to n8n"]:
        create_subtask(p, t, s)
    t = create_task(p, "Get LoRa device and test with solar light kit", "First step toward farm-wide sensor network. Test LoRa range and solar viability.", 2)
    for s in ["Order LoRa module (TTGO LoRa32 or Heltec WiFi LoRa 32)", "Wire to solar light kit as power source", "Flash LoRa test firmware", "Set up LoRa gateway or second receiver node", "Test transmission range across property", "Document range results and plan sensor payload"]:
        create_subtask(p, t, s)

print("\nDone!")
