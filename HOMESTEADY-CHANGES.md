# Homesteady Changes from Farmstead

**Date:** May 2, 2026  
**Fork Purpose:** Farm-optimized infrastructure for isolated VLAN deployment

## Services Removed (7)

These services are NOT included in homesteady because they're either:
- Redundant with house infrastructure
- Too resource-heavy for 1L PC
- Not needed for farm operations

### ❌ Radicale (CalDAV/CardDAV)
**Why removed:** Calendar/contacts should be centralized in cloud or house instance, not duplicated per location  
**Alternative:** Use house Radicale instance via Tailscale, or use cloud provider (Google Calendar, iCloud)

### ❌ Jellyfin (Media Server)
**Why removed:** Already have Plex running on main house server with multi-TB media library  
**Alternative:** Stream from house Plex via Tailscale VPN

### ❌ Vaultwarden (Password Manager)
**Why removed:** **CRITICAL** - Passwords MUST be centralized, not duplicated. Multiple instances create sync issues and security risks  
**Alternative:** Access house Vaultwarden instance via Tailscale (encrypted VPN access)

### ❌ AdGuard Home (DNS/Ad Blocking)
**Why removed:** pfSense router already handles network-wide DNS filtering and ad blocking  
**Alternative:** Use pfSense DNS/ad-blocking for entire network (including farm VLAN)

### ❌ FreshRSS (RSS Reader)
**Why removed:** RSS feeds are personal, not location-specific. No benefit to separate farm instance  
**Alternative:** Access house FreshRSS instance via Tailscale

### ❌ MongoDB (NoSQL Database)
**Why removed:** Resource hog (300-500MB RAM), specialized use case, most apps work fine with PostgreSQL/MySQL  
**Alternative:** PostgreSQL handles 95% of use cases that would need MongoDB

### ❌ Nextcloud (Previously removed)
**Why removed:** Too heavy for 1L PC, features covered by other lighter services  
**Alternatives:**
- File sync → Syncthing
- Calendar/Contacts → Radicale (house) or cloud
- Notes → Joplin
- Knowledge base → WikiJS

## Services Retained (22)

All other Farmstead services are included because they provide farm-specific value:

### Core Services (7)
- ✅ nginx-proxy-manager - SSL and reverse proxy
- ✅ n8n - Farm automation workflows
- ✅ ollama - Local AI (llama3.2:3b)
- ✅ open-webui - AI chat interface
- ✅ vikunja - Farm project management
- ✅ wikijs - Farm documentation
- ✅ whisper - Voice transcription (base model)

### Farm-Essential Services (15)
- ✅ watchtower - Auto-updates
- ✅ uptime-kuma - Service monitoring
- ✅ gitea - Code/config versioning
- ✅ code-server - On-site editing
- ✅ joplin-server - Farm notes
- ✅ syncthing - **CRITICAL** backup sync to house
- ✅ paperless-ngx - Document OCR/management
- ✅ immich - Photo management with AI
- ✅ mealie - Recipe management
- ✅ grocy - Inventory tracking
- ✅ home-assistant - Farm IoT automation
- ✅ homepage - Service dashboard
- ✅ postgresql - Standalone DB
- ✅ mysql - Standalone DB
- ✅ redis - Cache/queue

## Configuration Changes

### Script Updates

**Configure-FarmsteadServices.ps1:**
- Removed from `$coreServices`: radicale
- Removed from `$addons`: jellyfin, vaultwarden, adguardhome, freshrss, mongodb
- Removed Set-IfMissing calls for removed services
- Removed Docker Compose definitions for removed services
- Removed volume declarations for removed services
- Updated nginx upstream list (removed radicale, jellyfin, vaultwarden, adguardhome, freshrss)
- Updated $needsVolumes check

**Generate-ProductionSecrets.ps1:**
- Removed environment variables for: JELLYFIN_PORT, VAULTWARDEN_*, ADGUARD_*, FRESHRSS_PORT, MONGODB_*
- Reduced total environment variables from ~40 to ~30

### Resource Impact

**Before (Farmstead - 35 containers):**
- RAM: 10-12GB base + removed services (~2GB) = 12-14GB
- Services: 8 core + 20 optional + 7 dependencies

**After (Homesteady - 28 containers):**
- RAM: 13-14GB (2GB headroom in 16GB system)
- Services: 7 core + 15 optional + 6 dependencies

**Savings:**
- -7 containers (20% reduction)
- -1-2GB RAM (depending on removed service usage)
- Simpler configuration, fewer moving parts

## Network Architecture Changes

### Farmstead (Original)
```
Internet ← → Home Network ← → Farmstead Server
                              ├─ All services
                              └─ Self-contained
```

### Homesteady (Fork)
```
Internet ← → pfSense/Core Switch
             ├─ Home VLAN ← → House Services
             │  ├─ Plex
             │  ├─ Vaultwarden
             │  ├─ FreshRSS
             │  ├─ Home Assistant (home)
             │  └─ Backup Server
             │
             └─ Farm VLAN ← → Homesteady (1L PC)
                ├─ 28 containers
                ├─ Farm IoT devices
                ├─ Tailscale ← → House Services
                └─ Syncthing → House Backup
```

## Deployment Differences

### Farmstead
- General-purpose homelab
- Single network
- All services local
- Optional external access

### Homesteady
- Farm-specific use cases
- VLAN isolation required
- Depends on house services via VPN
- Mandatory backup sync to house
- Offline-capable for critical functions

## Use Case Differences

### Farmstead Use Cases
- General productivity
- Media consumption
- Password management
- Home automation
- Development environment

### Homesteady Use Cases
- **Farm photo documentation** (livestock, crops, equipment)
- **Agricultural document management** (receipts, manuals, vet records)
- **Farm knowledge base** (planting schedules, care protocols)
- **Supply inventory** (seeds, tools, feed, supplies)
- **Farm IoT automation** (greenhouse, coops, irrigation)
- **Farm workflow automation** (weather alerts, feeding schedules)
- **Local AI for agriculture** (pest ID, planting guides)
- **Voice notes while working** (hands-free documentation)

## Documentation Added

New files specific to homesteady:
- `README-HOMESTEADY.md` - Complete farm deployment guide
- `HOMESTEADY-CHANGES.md` - This file
- `.working/FARM-VS-HOUSE-ARCHITECTURE.md` - Architectural justification

Modified files:
- `.working/NEW-SERVICES.md` - Updated to reflect removed services
- `.working/HOMESTEAD-SERVICES-SUMMARY.md` - Updated service list
- `.working/USB-CONFIGURATION.md` - Current deployment snapshot

## Migration Path

If you want to convert an existing Farmstead installation to homesteady:

1. **Backup all data** from services you're removing:
   - Vaultwarden: Export vault, move to house instance
   - Jellyfin: Not needed (use house Plex)
   - FreshRSS: Export OPML, import to house instance
   - AdGuard: Not needed (use pfSense)
   - MongoDB: Export data if used, migrate to PostgreSQL

2. **Stop removed services:**
   ```bash
   docker compose stop radicale jellyfin vaultwarden adguardhome freshrss mongodb
   ```

3. **Update configuration:**
   ```powershell
   .\.working\scripts\Generate-ProductionSecrets.ps1 -Architecture x86_64
   .\scripts\Prepare-FarmsteadInstaller.ps1 -TargetArchitecture x86_64 -NonInteractiveServiceConfig
   ```

4. **Apply new compose file:**
   ```bash
   cd /opt/farmstead
   docker compose down
   docker compose -f docker-compose.yml -f docker-compose.autoinstall.override.yml up -d
   ```

5. **Configure Syncthing** to sync critical data to house

6. **Verify** all services start correctly

## Future Fork Maintenance

### When to Pull from Farmstead Upstream
- Security updates to Docker images
- Bug fixes in scripts
- New service additions that make sense for farm use

### When NOT to Pull from Upstream
- Adding back removed services
- Changing resource allocations
- Network architecture changes

### Keep Homesteady-Specific
- Service selection (22 vs 35)
- VLAN documentation
- Farm use case examples
- Two-site architecture guides

## Summary

**Homesteady is NOT a superset or replacement for Farmstead.**

It's a **specialized fork** optimized for:
- Farm/agricultural operations
- Resource-constrained hardware (1L PC)
- Two-site deployment (farm + house)
- VLAN-isolated networks
- Mandatory data sync to central backup

If you need all 35 services, general homelab features, or don't have a two-site architecture, **use meetstack instead**.

---

**Fork maintained for personal farm infrastructure deployment** 🌾
