#!/usr/bin/env bash
# setup_cron.sh — Install all automation schedules into crontab

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/config.cfg"

# ── Setup ──────────────────────────────────────────────────────
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
MARKER_START="# LINUX-MONITORING-SYSTEM-START"
MARKER_END="# LINUX-MONITORING-SYSTEM-END"

# ── Full paths to all scripts ──────────────────────────────────
ALERTS_SCRIPT="${SCRIPT_DIR}/alerts.sh"
SELFHEAL_SCRIPT="${SCRIPT_DIR}/self_heal.sh"
REPORT_SCRIPT="${SCRIPT_DIR}/report.sh"
ROTATION_SCRIPT="${SCRIPT_DIR}/log_rotation.sh"
MAINTENANCE_SCRIPT="${SCRIPT_DIR}/maintenance.sh"
SECURITY_SCRIPT="${SCRIPT_DIR}/security_update.sh"

# ── Full paths to log files ────────────────────────────────────
ALERTS_LOG="${SCRIPT_DIR}/logs/alerts_cron.log"
SELFHEAL_LOG="${SCRIPT_DIR}/logs/selfheal_cron.log"
REPORT_LOG="${SCRIPT_DIR}/logs/report_cron.log"
ROTATION_LOG="${SCRIPT_DIR}/logs/rotation_cron.log"
MAINTENANCE_LOG="${SCRIPT_DIR}/logs/maintenance_cron.log"
SECURITY_LOG="${SCRIPT_DIR}/logs/security_cron.log"

echo "======================================================"
echo "     LINUX MONITORING SYSTEM — CRON INSTALLER"
echo "======================================================"
echo "Installing cron jobs at: $TIMESTAMP"
echo "Project directory: $SCRIPT_DIR"
echo "------------------------------------------------------"

# ── Remove Old Cron Entries ────────────────────────────────────
echo "Removing old cron entries (if any)..."

CLEAN_CRONTAB=$(crontab -l 2>/dev/null | \
    sed "/$(echo $MARKER_START | sed 's/[\/&]/\\&/g')/,/$(echo $MARKER_END | sed 's/[\/&]/\\&/g')/d")

echo "$CLEAN_CRONTAB" | crontab -
echo "Old entries removed"
echo "------------------------------------------------------"

# ── Build New Cron Block ───────────────────────────────────────
echo "Installing new cron jobs..."

NEW_CRON_BLOCK="$MARKER_START
*/5 * * * * bash $ALERTS_SCRIPT >> $ALERTS_LOG 2>&1
*/5 * * * * bash $SELFHEAL_SCRIPT >> $SELFHEAL_LOG 2>&1
59 23 * * * bash $REPORT_SCRIPT >> $REPORT_LOG 2>&1
0 0 * * * bash $ROTATION_SCRIPT >> $ROTATION_LOG 2>&1
0 2 * * 0 bash $MAINTENANCE_SCRIPT >> $MAINTENANCE_LOG 2>&1
0 3 * * 0 bash $SECURITY_SCRIPT >> $SECURITY_LOG 2>&1
$MARKER_END"

# ── Install Into Crontab ───────────────────────────────────────
(crontab -l 2>/dev/null; echo "$NEW_CRON_BLOCK") | crontab -

echo "Cron jobs installed successfully!"
echo "------------------------------------------------------"

# ── Verify Installation ────────────────────────────────────────
echo ""
echo "======================================================"
echo "         INSTALLED CRON JOBS"
echo "======================================================"
crontab -l
echo "======================================================"

# ── Show Schedule Summary ──────────────────────────────────────
echo ""
echo "======================================================"
echo "         SCHEDULE SUMMARY"
echo "======================================================"
echo ""
echo "  Every 5 mins  → alerts.sh    (threshold alerting)"
echo "  Every 5 mins  → self_heal.sh (service auto-restart)"
echo "  Daily 11:59PM → report.sh    (daily health report)"
echo "  Daily midnight→ log_rotation.sh (log cleanup)"
echo "  Sunday 2AM    → maintenance.sh  (weekly maintenance)"
echo "  Sunday 3AM    → security_update.sh (security patches)"
echo ""
echo "======================================================"
echo ""
echo "To remove all cron jobs, run:"
echo "  crontab -l | grep -v '$MARKER_START' | crontab -"
echo ""
echo "To view cron logs:"
echo "  ls -lh ${SCRIPT_DIR}/logs/"
echo ""
echo "======================================================"
echo "[$TIMESTAMP] Cron installation complete!"
