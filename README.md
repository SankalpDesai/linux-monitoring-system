# 🖥️ Linux Monitoring & Auto-Maintenance System

A production-grade Linux system monitoring and automation toolkit built entirely from scratch using **pure Bash scripting**. This project demonstrates real-world DevOps practices including centralized configuration, threshold alerting, self-healing services, log lifecycle management, and fully automated cron scheduling.

---

## 📌 Project Overview

This system continuously monitors a Linux server's health, alerts on threshold breaches, auto-recovers crashed services, generates daily reports, rotates logs, and applies security patches — all without human intervention.

> Built on Ubuntu 24.04 (WSL2) as part of a hands-on DevOps learning journey.

---

## 🏗️ Project Structure

```
linux-monitoring-system/
├── config.cfg            # Phase 1: Central configuration (single source of truth)
├── monitor.sh            # Phase 2: Real-time terminal dashboard
├── alerts.sh             # Phase 3: Threshold alerting system
├── report.sh             # Phase 4: Daily health report generator
├── self_heal.sh          # Phase 5: Service auto-restart (self-healing)
├── log_rotation.sh       # Phase 6: Log cleanup & compression
├── maintenance.sh        # Phase 7: Weekly system maintenance
├── security_update.sh    # Phase 8: Security-only patch installer
├── setup_cron.sh         # Phase 9: Cron job automation installer
├── logs/                 # Auto-created: all runtime logs
└── reports/              # Auto-created: compressed daily reports
```

---

## ⚙️ Components

### Phase 1 — `config.cfg` — Central Configuration
Single source of truth for all thresholds, paths, and settings. Every script sources this file — change a threshold once, it affects the entire system.

```bash
CPU_WARN=70        CPU_CRIT=90
MEMORY_WARN=65     MEMORY_CRIT=75
DISK_WARN=75       DISK_CRIT=85
CRITICAL_SERVICES="sshd nginx mysql"
MAX_RESTART_RETRIES=3
LOG_RETENTION_DAYS=30
```

---

### Phase 2 — `monitor.sh` — Live Dashboard
Auto-refreshing terminal dashboard with ANSI color-coded status bars. Reads metrics directly from `/proc` filesystem for real-time accuracy.

**Features:**
- CPU usage via `/proc/stat` (two-sample delta method)
- Memory via `free -m`
- Disk via `df -h`
- Load average via `/proc/loadavg`
- Top 5 processes by CPU
- Health snapshot logging every 5 minutes
- Calls `alerts.sh` in background (non-blocking)
- Graceful exit on `Ctrl+C` via `trap`

```bash
bash monitor.sh
# Press Ctrl+C to stop
```

**Sample output:**
```
╔══════════════════════════════════════════════╗
║       LINUX SYSTEM MONITOR DASHBOARD        ║
╚══════════════════════════════════════════════╝
CPU Usage   : [███░░░░░░░░░░░░░░░░░░░░░░░░░░░] 10.0%   NORMAL
Memory      : [██░░░░░░░░░░░░░░░░░░░░░░░░░░░░]  7.2%   NORMAL   (421MB / 5799MB)
Disk Usage  : [░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░]  1.0%   NORMAL   (1.6G / 1007G)
Load Avg    : 0.01   NORMAL
```

---

### Phase 3 — `alerts.sh` — Threshold Alerting
Receives metric values as CLI arguments from `monitor.sh`, compares against config thresholds, and logs breaches with severity levels.

**Alert log format:**
```
[2026-05-01 15:30:00] CRITICAL: CPU = 92.0 (warn=70, crit=90)
[2026-05-01 15:30:00] WARNING: MEMORY = 68.0 (warn=65, crit=75)
```

**Manual test:**
```bash
bash alerts.sh 95 70 40 1.2
cat logs/alerts.log
```

---

### Phase 4 — `report.sh` — Daily Report Generator
Generates a comprehensive system health report with 10 sections, compresses it (`gzip`/`zip`), and saves to `reports/` with a timestamp in the filename.

**Report sections:** Uptime, CPU stats, Memory, Disk, Top processes, Load average, Network connections, Error summary, TCP statistics, Today's alerts.

```bash
bash report.sh
ls reports/   # report_2026-05-01_23-59-00.txt.gz
```

---

### Phase 5 — `self_heal.sh` — Service Auto-Recovery
Checks critical services every 5 minutes. If a service is down, retries restart up to `MAX_RESTART_RETRIES` times. Escalates via email if all retries fail.

**Recovery flow:**
```
Service down detected
    → Attempt restart (1/3) → wait 2s → check
    → Attempt restart (2/3) → wait 2s → check
    → Attempt restart (3/3) → wait 2s → check
    → All failed → send escalation email
```

**Log sample:**
```
[2026-05-01 15:30:00] WARNING: nginx is down! Attempting restart...
[2026-05-01 15:30:03] SUCCESS: nginx restarted successfully on attempt 1
```

---

### Phase 6 — `log_rotation.sh` — Log Lifecycle Manager
Runs 4 operations to prevent disk exhaustion from growing log files.

| Operation | Action | Config Variable |
|---|---|---|
| 1 | Delete logs older than N days | `LOG_RETENTION_DAYS=30` |
| 2 | Compress logs exceeding size limit | `LOG_MAX_SIZE_MB=50` |
| 3 | Prune excess compressed files | `MAX_ROTATED_FILES=10` |
| 4 | Clean old reports | `LOG_RETENTION_DAYS=30` |

---

### Phase 7 — `maintenance.sh` — Weekly Maintenance
Runs every Sunday at 2 AM. Auto-detects package manager and performs full system housekeeping.

**Operations:**
1. System package update (`apt-get` / `yum` / `dnf` / `pacman`)
2. Clean `/tmp` and `/var/tmp` files older than 7 days
3. Vacuum `journalctl` logs older than 7 days
4. Call `log_rotation.sh` automatically

---

### Phase 8 — `security_update.sh` — Security Patches
Runs every Sunday at 3 AM. Installs **security-only** patches — not full upgrades — to minimize risk on production servers.

**Distro detection via `/etc/os-release`:**
| Distro | Method |
|---|---|
| Ubuntu/Debian | `unattended-upgrade` |
| CentOS/RHEL | `yum update --security` |
| Fedora | `dnf update --security` |

Also checks `/var/run/reboot-required` and alerts if reboot is needed after kernel patches.

---

### Phase 9 — `setup_cron.sh` — Cron Installer
Run once to install all automation schedules. **Idempotent** — re-running replaces old entries instead of duplicating them, using marker comments.

**Installed schedule:**
| Schedule | Script | Purpose |
|---|---|---|
| `*/5 * * * *` | `alerts.sh` | Threshold alerting |
| `*/5 * * * *` | `self_heal.sh` | Service recovery |
| `59 23 * * *` | `report.sh` | Daily report |
| `0 0 * * *` | `log_rotation.sh` | Log cleanup |
| `0 2 * * 0` | `maintenance.sh` | Weekly maintenance |
| `0 3 * * 0` | `security_update.sh` | Security patches |

```bash
bash setup_cron.sh   # install
crontab -l           # verify
```

---

## 🚀 Quick Start

```bash
# 1. Clone the repository
git clone https://github.com/SankalpDesai/linux-monitoring-system.git
cd linux-monitoring-system

# 2. Make all scripts executable
chmod +x *.sh

# 3. Install bc (required for math operations)
sudo apt install bc -y

# 4. Edit config (set your thresholds and email)
nano config.cfg

# 5. Run the live dashboard
bash monitor.sh

# 6. Install cron automation
bash setup_cron.sh
```

---

## 🔑 Key Design Patterns

| Pattern | Description | Used In |
|---|---|---|
| Central config | Single `config.cfg` for all settings | All scripts |
| `SCRIPT_DIR` trick | Location-independent script execution | All scripts |
| `set -uo pipefail` | Strict error handling | All scripts |
| Two-level thresholds | WARN + CRIT for alert severity | `config.cfg`, `alerts.sh` |
| Background execution `&` | Non-blocking alert triggering | `monitor.sh` |
| Graceful degradation | Check tool exists before using it | All scripts |
| Idempotent install | Re-runnable without side effects | `setup_cron.sh` |
| Exit code checking | `$?` captured immediately after commands | `security_update.sh` |
| Null-delimited find | Safe handling of filenames with spaces | `log_rotation.sh` |
| Block redirect `{ } >` | Write entire report in one operation | `report.sh` |

---

## 🛠️ Tech Stack

- **Language:** Bash 5.x
- **OS:** Ubuntu 24.04 LTS (also compatible with Debian, CentOS, RHEL, Fedora)
- **Tools:** `bc`, `gzip`, `systemctl`, `journalctl`, `cron`, `find`, `sed`, `awk`, `ps`, `df`, `free`
- **Data sources:** `/proc/stat`, `/proc/loadavg`, `/proc/net/snmp`, `/etc/os-release`

---

## 📋 Prerequisites

- Linux system (Ubuntu/Debian recommended)
- `bash 4.0+`
- `bc` (`sudo apt install bc -y`)
- `sudo` access (for service management and package updates)
- `mail` or `sendmail` (optional, for email alerts)

---

## 🎯 DevOps Concepts Demonstrated

- ✅ Shell scripting best practices
- ✅ Cron job automation
- ✅ Linux service management (systemd)
- ✅ Log lifecycle management
- ✅ Security patch automation
- ✅ Self-healing infrastructure
- ✅ Cross-platform compatibility
- ✅ Separation of concerns
- ✅ Principle of least privilege (sudoers)
- ✅ Production-grade error handling

---

## 📁 Log Files Reference

| Log File | Contains |
|---|---|
| `logs/health_history.log` | CPU/Memory/Disk snapshots every 5 min |
| `logs/alerts.log` | All WARNING and CRITICAL threshold breaches |
| `logs/self_heal.log` | Every service check and restart attempt |
| `logs/security_update.log` | Security patch history |
| `logs/maintenance.log` | Weekly maintenance run history |
| `logs/rotation.log` | Log rotation activity |
| `reports/` | Compressed daily health reports |

---

## 👤 Author

**Sankalp Desai**
DevOps & Cloud Engineering Enthusiast | Linux | Shell Scripting | Docker | Kubernetes
