# Homesteady - Farm Infrastructure Stack

**Forked from:** meetstack  
**Purpose:** Farm/homestead-optimized infrastructure deployment  
**Target Hardware:** 1L PC (x86_64)  
**Network:** Separate farm VLAN, isolated from primary home network

## Overview

Homesteady is a streamlined fork of meetstack, optimized for farm/homestead deployments on resource-constrained hardware. This configuration runs on a 1L PC with 16GB RAM, providing essential data management and automation services for agricultural operations while accessing centralized home services via Tailscale VPN.

## Architecture Philosophy

### Two-Site Deployment Model

**HOUSE (Main Homelab)**
- pfSense router/firewall/DNS
- Plex media server
- Vaultwarden password manager
- FreshRSS feed reader
- Primary Home Assistant instance
- Backup server for farm data sync

**FARM (Homesteady - 1L PC)**
- Farm-specific data services
- Local AI inference
- Automation and monitoring
- Syncs critical data to house for backup

### Services Included (22 services)

#### Core Services (7)
- ✅ **nginx-proxy-manager** - Reverse proxy with SSL
- ✅ **n8n** - Farm workflow automation
- ✅ **ollama** - Local LLM inference (llama3.2:3b for x86_64)
- ✅ **open-webui** - Chat interface for AI
- ✅ **vikunja** - Farm project/task management
- ✅ **wikijs** - Farm documentation and knowledge base
- ✅ **whisper** - Voice-to-text transcription (base model for x86_64)

#### Farm-Essential Services (15)
- ✅ **watchtower** - Auto-update Docker containers
- ✅ **uptime-kuma** - Monitor farm services (visible from house)
- ✅ **gitea** - Git hosting for farm scripts and configs
- ✅ **code-server** - VSCode in browser for on-site editing
- ✅ **joplin-server** - Farm notes and observations
- ✅ **syncthing** - **CRITICAL** - Sync farm data to house for backups
- ✅ **paperless-ngx** - OCR document management (receipts, manuals, records)
- ✅ **immich** - AI-powered photo management with face recognition
- ✅ **mealie** - Recipe manager (preserving, animal feed recipes)
- ✅ **grocy** - Grocery/supply inventory tracking
- ✅ **home-assistant** - Farm IoT automation ("homesteadassistant")
- ✅ **homepage** - Dashboard for all farm services
- ✅ **postgresql** - Standalone database server
- ✅ **mysql** - Standalone database server
- ✅ **redis** - Cache and queue server

#### Dependency Services (6)
- joplin-db (PostgreSQL for Joplin)
- paperless-postgres + paperless-redis
- immich-postgres + immich-redis + immich-machine-learning

**Total Containers:** 28

### Services Deliberately EXCLUDED

These services run on the main house server and are accessed via Tailscale:

- ❌ **Vaultwarden** - Passwords MUST be centralized, not duplicated
- ❌ **AdGuard Home** - DNS/ad-blocking already handled by pfSense
- ❌ **Jellyfin** - Media served from house Plex server
- ❌ **FreshRSS** - RSS feeds are personal, use house instance
- ❌ **Radicale** - Calendar/contacts sync via house or cloud service
- ❌ **MongoDB** - Too heavy for 1L PC, PostgreSQL handles most needs

## Resource Usage

### RAM Budget (16GB Total)
- Core services: ~4GB
- Immich (with ML): ~2-3GB
- Paperless-ngx: ~512MB
- Ollama (model loaded): ~2GB
- WikiJS/Joplin/Gitea: ~500MB
- Mealie/Grocy: ~200MB
- Home Assistant: ~512MB
- n8n: ~256MB
- Other services: ~1-2GB
- **Total: ~13-14GB (2GB headroom)**

### Storage Layout

**Internal SSD (256GB)**
- Ubuntu OS + Docker system
- PostgreSQL/MySQL/Redis databases
- Active working data
- Immich thumbnail cache
- ~100GB reserved free space

**External Drive (2-4TB, mounted at `/mnt/farm-data`)**

**Critical Data (Synced to House via Syncthing):**
```
/mnt/farm-data/
├─ immich/upload/           # Farm photos
├─ paperless/consume/       # Farm documents
├─ backups/
│  ├─ postgres-dumps/       # Daily database backups
│  ├─ wikijs-exports/       # Weekly wiki exports
│  └─ gitea-repos/          # Git repository backups
└─ syncthing/sync/          # Active sync folder
```

**Non-Critical Data (No Backup):**
```
/mnt/farm-data/
├─ downloads/               # Temporary downloads
├─ ollama-models/           # Can re-download (3-7GB)
├─ whisper-models/          # Can re-download (~500MB)
└─ temp/                    # Scratch space
```

## Use Cases

### Farm-Specific Data Management

1. **Photo Documentation** (Immich)
   - Livestock condition tracking
   - Crop progress monitoring
   - Equipment maintenance records
   - Property boundary documentation
   - AI-powered face recognition for people/animals

2. **Document Management** (Paperless-ngx)
   - Seed packet receipts and information
   - Veterinary records
   - Equipment manuals and warranties
   - Property deeds and legal documents
   - Supply invoices and receipts

3. **Knowledge Base** (WikiJS)
   - Planting schedules and crop rotation plans
   - Animal care protocols
   - Equipment maintenance procedures
   - Pest and disease identification guides
   - Weather pattern observations

4. **Inventory Management** (Grocy)
   - Seed inventory and viability tracking
   - Tool and equipment tracking
   - Fertilizer and feed supplies
   - Livestock supplies
   - Bulk purchase tracking

5. **Recipe Management** (Mealie)
   - Food preservation recipes
   - Animal feed formulations
   - Bulk cooking for farm workers
   - Harvest processing methods

### Automation & Monitoring

1. **Farm IoT** (Home Assistant)
   - Greenhouse temperature/humidity monitoring
   - Chicken coop door automation
   - Irrigation system control
   - Weather station integration
   - Well pump monitoring
   - Propane tank level sensors
   - Barn lighting schedules

2. **Workflow Automation** (n8n)
   - Weather alerts for frost/hail
   - Feeding schedule reminders
   - Harvest window notifications
   - Equipment maintenance reminders
   - Integration between services

3. **Service Monitoring** (Uptime-kuma)
   - Monitor all farm services
   - Alert house if farm goes down
   - Track service uptime statistics

### Development & Documentation

1. **Code Management** (Gitea)
   - Automation scripts version control
   - Configuration backup
   - Sensor integration code
   - Custom tool development

2. **On-Site Development** (Code-server)
   - Edit configs directly on farm
   - Debug issues without laptop
   - Terminal access via browser

3. **Notes & Observations** (Joplin)
   - Daily farm observations
   - Weather notes
   - Animal behavior tracking
   - Experiment results

### Local AI Capabilities

1. **Farm-Specific Queries** (Ollama + Open-WebUI)
   - "What pests attack tomatoes in July?"
   - "When should I plant lettuce in Zone 6?"
   - "How do I treat mastitis in goats?"
   - Works offline if internet drops

2. **Voice Notes** (Whisper)
   - Transcribe observations while walking property
   - Document issues hands-free
   - Create reminders verbally

## Network Architecture

```
┌─────────────────────────────────────────────────┐
│ HOUSE VLAN (Main Network)                       │
│ ├─ pfSense (192.168.1.1)                        │
│ ├─ Home Assistant (home devices)                │
│ ├─ Plex Media Server                            │
│ ├─ Vaultwarden (passwords)                      │
│ └─ Backup Server                                │
└─────────────────────────────────────────────────┘
                      ↕ Tailscale VPN
┌─────────────────────────────────────────────────┐
│ FARM VLAN (Isolated Network)                    │
│ ├─ Homesteady (1L PC)                           │
│ │  ├─ 28 Docker containers                      │
│ │  ├─ PostgreSQL/MySQL/Redis                    │
│ │  └─ Syncthing → House Backup                  │
│ ├─ Farm IoT Devices                             │
│ │  ├─ Temperature sensors                       │
│ │  ├─ Irrigation controllers                    │
│ │  ├─ Security cameras                          │
│ │  └─ Smart plugs/relays                        │
│ └─ Access House Services via Tailscale:         │
│    ├─ Vaultwarden (passwords)                   │
│    ├─ Plex (stream media)                       │
│    └─ FreshRSS (RSS feeds)                      │
└─────────────────────────────────────────────────┘
```

### VLAN Isolation Strategy

- **Farm VLAN**: Isolated segment for homesteading operations
- **Firewall Rules**: Only essential traffic between VLANs
- **Tailscale**: Encrypted VPN for cross-VLAN service access
- **Syncthing**: Encrypted sync of farm data to house backup
- **Benefits**: Security, network segmentation, independent operation

## Deployment

### Prerequisites

1. **Hardware**
   - 1L PC with x86_64 CPU (Intel/AMD)
   - 16GB RAM minimum
   - 256GB internal SSD
   - 2-4TB external USB/SATA drive
   - USB drive (256GB+) for installer

2. **Network**
   - VLAN-capable switch/router
   - Tailscale account with auth key
   - Static IP or DHCP reservation for farm PC

3. **Services Prepared**
   - Tailscale auth key
   - SSH key generated
   - User password chosen
   - SMTP credentials (optional)

### Build Process

```powershell
# 1. Generate production secrets with random passwords
.\.working\scripts\Generate-ProductionSecrets.ps1 -Architecture x86_64

# 2. Configure services (non-interactive mode uses optimized defaults)
.\scripts\Prepare-MeetstackInstaller.ps1 -TargetArchitecture x86_64 -NonInteractiveServiceConfig

# 3. Stage to USB drive (requires Administrator PowerShell)
# Note: This step requires running as Administrator
# Build-FarmstackUSB.ps1 creates bootable Ubuntu USB with cloud-init config

# 4. Update USB payload (can be run as regular user)
.\.working\scripts\Stage-CIDataPayload.ps1 -DriveLetter H -CleanMeetstackTarget
```

### First Boot Process

1. Insert USB into farm 1L PC
2. Boot from USB (F12/F2 for boot menu)
3. Ubuntu autoinstall runs automatically (~10 minutes)
4. First boot automation (~20 minutes):
   - Install Docker and Docker Compose
   - Join Tailscale VPN
   - Clone homesteady to `/opt/meetstack`
   - Start all 28 containers
5. Services available at configured ports

### Post-Deployment Configuration

**Immediate Steps:**
1. Access nginx-proxy-manager (port 81) - set up SSL certificates
2. Configure Syncthing - establish sync with house backup server
3. Set up Immich - install mobile app for automatic photo backup
4. Configure Homepage - create dashboard for all services
5. Configure Home Assistant - add farm IoT devices

**Recommended:**
- Map external drive to `/mnt/farm-data` in docker-compose mounts
- Set up nginx-proxy-manager reverse proxy for clean URLs
- Configure watchtower notifications for container updates
- Create database backup cron jobs
- Test disaster recovery (restore from house backup)

## Maintenance

### Daily
- Check Uptime-kuma for service alerts
- Verify Syncthing is syncing to house

### Weekly
- Review disk space on farm PC and external drive
- Check database sizes
- Review Home Assistant automations

### Monthly
- Verify backups successfully syncing to house
- Test disaster recovery procedure
- Ubuntu security updates: `apt update && apt upgrade`

### Quarterly
- Review service usage, disable unused services
- Clean up old data (paperless processed docs, old logs)
- Rotate Tailscale auth key if expired

## Security Model

### Password Management
- All service passwords randomly generated (24-32 characters)
- Secret keys: 64 hexadecimal characters (crypto-random)
- SSH: Key-only authentication (password auth disabled)
- Stored in: `.working/secrets/stack.env.generated`

### Network Security
- Tailscale VPN: Encrypted mesh network for remote access
- VLAN isolation: Farm network separated from home network
- nginx-proxy-manager: SSL certificates + authentication
- Services bind to all interfaces but protected by firewall

### Data Security
- Syncthing: Encrypted sync to house backup
- Database backups: Daily automated dumps
- External drive: Physical backup medium
- No internet-facing ports (Tailscale only)

## Comparison: Homesteady vs Meetstack

| Aspect | Meetstack | Homesteady |
|--------|-----------|------------|
| **Purpose** | General homelab/productivity | Farm/homestead-specific |
| **Services** | 35 containers | 28 containers (22% reduction) |
| **Target Hardware** | Any | 1L PC (resource-constrained) |
| **RAM Usage** | 10-12GB | 13-14GB (optimized selection) |
| **Network Model** | Standalone | Two-site (farm + house) |
| **Data Sync** | Optional | Required (Syncthing to house) |
| **Removed Services** | N/A | Vaultwarden, AdGuard, Jellyfin, FreshRSS, Radicale, MongoDB |
| **Added Focus** | N/A | Farm IoT, agriculture use cases |
| **VLAN Isolation** | No | Yes (farm VLAN separation) |

## Why Fork?

Homesteady diverged from meetstack for several key reasons:

1. **Use Case Specialization**: Farm/homestead operations have unique requirements (photo management for livestock, document scanning for receipts, inventory for seeds/supplies)

2. **Resource Optimization**: 1L PC hardware constraints require careful service selection (removed heavy services like MongoDB, duplicates like Vaultwarden)

3. **Network Architecture**: Two-site deployment model with VLAN isolation and data sync requirements

4. **Service Selection**: Optimized for farm-specific workflows rather than general homelab use

5. **Documentation**: Farm-focused examples and use cases

6. **Iteration Independence**: Ability to experiment with farm setup without impacting established home services

## Future Enhancements

### Planned
- MQTT broker integration for IoT sensors
- InfluxDB + Grafana for sensor data visualization
- Automated backup verification
- Multi-farm support (if expanding operations)

### Under Consideration
- Frigate NVR for security camera AI detection
- Node-RED as alternative to n8n
- Weather station integration
- Soil moisture sensor dashboards
- Livestock tracking system

## Links

- **Original Project**: meetstack (main branch)
- **This Fork**: homesteady (farm-optimized branch)
- **Documentation**: `.working/FARM-VS-HOUSE-ARCHITECTURE.md`
- **Service Details**: `.working/NEW-SERVICES.md`
- **Secrets Inventory**: `.working/SECRETS-INVENTORY.md`

## Support

This is a personal fork for farm deployment. For the original meetstack project, see the main repository.

## License

Inherits license from meetstack project. Fork maintained for personal farm infrastructure deployment.

---

**Built with 🌾 for the farm**
