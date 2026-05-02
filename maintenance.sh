#!/usr/bin/env bash
# maintenance.sh — Weekly automated system maintenance

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/config.cfg"

# ── Setup ──────────────────────────────────────────────────────
mkdir -p "${SCRIPT_DIR}/${LOG_DIR}"
MAINT_LOG="${SCRIPT_DIR}/${LOG_DIR}/maintenance.log"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

# ── Logger Function ────────────────────────────────────────────
log_msg() {
    local level=$1
    local message=$2
    local entry="[$TIMESTAMP] $level: $message"
    echo "$entry" | tee -a "$MAINT_LOG"
}

# ── Refresh timestamp (called before each operation) ───────────
refresh_timestamp() {
    TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
}

log_msg "INFO" "Starting weekly maintenance on $(hostname)"
echo "======================================================"

# ── Operation 1: System Package Update ────────────────────────
refresh_timestamp
log_msg "INFO" "Operation 1: Updating system packages..."
START_TIME=$(date +%s)

if command -v apt-get &>/dev/null; then
    log_msg "INFO" "Detected package manager: apt-get (Ubuntu/Debian)"
    DEBIAN_FRONTEND=noninteractive sudo apt-get update -y 2>&1 | \
        tail -5 | tee -a "$MAINT_LOG"
    DEBIAN_FRONTEND=noninteractive sudo apt-get upgrade -y 2>&1 | \
        tail -5 | tee -a "$MAINT_LOG"
    DEBIAN_FRONTEND=noninteractive sudo apt-get autoremove -y 2>&1 | \
        tail -5 | tee -a "$MAINT_LOG"

elif command -v yum &>/dev/null; then
    log_msg "INFO" "Detected package manager: yum (CentOS/RHEL)"
    sudo yum update -y 2>&1 | tail -5 | tee -a "$MAINT_LOG"
    sudo yum autoremove -y 2>&1 | tail -5 | tee -a "$MAINT_LOG"

elif command -v dnf &>/dev/null; then
    log_msg "INFO" "Detected package manager: dnf (Fedora/RHEL8+)"
    sudo dnf update -y 2>&1 | tail -5 | tee -a "$MAINT_LOG"
    sudo dnf autoremove -y 2>&1 | tail -5 | tee -a "$MAINT_LOG"

elif command -v pacman &>/dev/null; then
    log_msg "INFO" "Detected package manager: pacman (Arch)"
    sudo pacman -Syu --noconfirm 2>&1 | tail -5 | tee -a "$MAINT_LOG"

else
    log_msg "WARNING" "No supported package manager found. Skipping updates."
fi

END_TIME=$(date +%s)
DURATION=$(( END_TIME - START_TIME ))
refresh_timestamp
log_msg "INFO" "Package update completed in ${DURATION} seconds"
echo "------------------------------------------------------"

# ── Operation 2: Clean Temporary Files ────────────────────────
refresh_timestamp
log_msg "INFO" "Operation 2: Cleaning temporary files..."

# Delete files in /tmp older than 7 days
find /tmp -type f -mtime +7 -delete 2>/dev/null
log_msg "INFO" "Cleaned /tmp files older than 7 days"

# Delete files in /var/tmp older than 7 days
find /var/tmp -type f -mtime +7 -delete 2>/dev/null
log_msg "INFO" "Cleaned /var/tmp files older than 7 days"

# Clear thumbnail cache
if [[ -d ~/.cache/thumbnails ]]; then
    rm -rf ~/.cache/thumbnails/*
    log_msg "INFO" "Cleared thumbnail cache"
fi

# Vacuum journalctl logs older than 7 days
if command -v journalctl &>/dev/null; then
    sudo journalctl --vacuum-time=7d 2>&1 | tee -a "$MAINT_LOG"
    log_msg "INFO" "Vacuumed journal logs older than 7 days"
fi

refresh_timestamp
log_msg "INFO" "Temporary file cleanup complete"
echo "------------------------------------------------------"

# ── Operation 3: Run Log Rotation ─────────────────────────────
refresh_timestamp
log_msg "INFO" "Operation 3: Running log rotation..."

if [[ -x "${SCRIPT_DIR}/log_rotation.sh" ]]; then
    bash "${SCRIPT_DIR}/log_rotation.sh"
    refresh_timestamp
    log_msg "INFO" "Log rotation completed"
else
    log_msg "WARNING" "log_rotation.sh not found or not executable. Skipping."
fi

echo "------------------------------------------------------"

# ── Final Summary ──────────────────────────────────────────────
refresh_timestamp
log_msg "INFO" "Weekly maintenance completed!"

echo ""
echo "======================================================"
echo "         MAINTENANCE SUMMARY"
echo "======================================================"
echo ""
echo "Disk usage after maintenance:"
df -h "${SCRIPT_DIR}"
echo ""
echo "Memory status:"
free -h
echo ""
echo "Log files:"
ls -lh "${SCRIPT_DIR}/${LOG_DIR}/"
echo "======================================================"

log_msg "INFO" "Maintenance finished. Next run: Sunday 2AM (via cron)"
