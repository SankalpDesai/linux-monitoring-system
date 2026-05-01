#!/usr/bin/env bash
# report.sh — Daily system health report generator

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/config.cfg"

# ── Setup ──────────────────────────────────────────────────────
mkdir -p "${SCRIPT_DIR}/${LOG_DIR}"
mkdir -p "${SCRIPT_DIR}/${REPORT_DIR}"

TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
REPORT_DATE=$(date '+%Y-%m-%d_%H-%M-%S')
REPORT_FILE="${SCRIPT_DIR}/${REPORT_DIR}/report_${REPORT_DATE}.txt"
HOSTNAME=$(hostname)

echo "Generating daily report..."
echo "Report file: $REPORT_FILE"

# ── Generate Report ────────────────────────────────────────────
{
echo "======================================================"
echo "         DAILY SYSTEM HEALTH REPORT"
echo "   Generated : $TIMESTAMP"
echo "   Hostname  : $HOSTNAME"
echo "======================================================"
echo ""

# ── Section 1: System Uptime ───────────────────────────────
echo "[ 1 ] SYSTEM UPTIME"
echo "------------------------------------------------------"
uptime
echo ""

# ── Section 2: CPU Statistics ──────────────────────────────
echo "[ 2 ] CPU STATISTICS"
echo "------------------------------------------------------"
if command -v mpstat &>/dev/null; then
    mpstat 1 1
else
    top -bn1 | grep "Cpu(s)"
fi
echo ""

# ── Section 3: Memory Statistics ──────────────────────────
echo "[ 3 ] MEMORY STATISTICS"
echo "------------------------------------------------------"
free -h
echo ""

# ── Section 4: Disk Statistics ────────────────────────────
echo "[ 4 ] DISK STATISTICS"
echo "------------------------------------------------------"
df -h
echo ""

# ── Section 5: Top 5 Processes ────────────────────────────
echo "[ 5 ] TOP 5 PROCESSES BY CPU"
echo "------------------------------------------------------"
ps aux --sort=-%cpu | head -6
echo ""

# ── Section 6: Load Average ───────────────────────────────
echo "[ 6 ] LOAD AVERAGE"
echo "------------------------------------------------------"
cat /proc/loadavg
echo ""

# ── Section 7: Network Statistics ────────────────────────
echo "[ 7 ] NETWORK STATISTICS"
echo "------------------------------------------------------"
if command -v ss &>/dev/null; then
    ss -tun | head -20
else
    netstat -tun | head -20
fi
echo ""

# ── Section 8: Error Summary ──────────────────────────────
echo "[ 8 ] ERROR SUMMARY (last 5 mins)"
echo "------------------------------------------------------"
if command -v journalctl &>/dev/null; then
    journalctl --since "5 minutes ago" -p err --no-pager \
        | tail -20
else
    grep -i "error" /var/log/syslog 2>/dev/null | tail -20
fi
echo ""

# ── Section 9: TCP Statistics ────────────────────────────
echo "[ 9 ] TCP STATISTICS"
echo "------------------------------------------------------"
if [[ -f /proc/net/snmp ]]; then
    grep "Tcp:" /proc/net/snmp | tail -1
else
    netstat -s | grep -i retransmit
fi
echo ""

# ── Section 10: Today's Alerts Summary ───────────────────
echo "[ 10 ] TODAY'S ALERTS SUMMARY"
echo "------------------------------------------------------"
if [[ -f "${SCRIPT_DIR}/${ALERT_LOG}" ]]; then
    local_date=$(date '+%Y-%m-%d')
    alert_count=$(grep "$local_date" \
        "${SCRIPT_DIR}/${ALERT_LOG}" 2>/dev/null | wc -l)
    echo "Total alerts today: $alert_count"
    echo ""
    grep "$local_date" \
        "${SCRIPT_DIR}/${ALERT_LOG}" 2>/dev/null | tail -20
else
    echo "No alerts log found."
fi
echo ""

echo "======================================================"
echo "              END OF REPORT"
echo "======================================================"

} > "$REPORT_FILE"

# ── Compress Report ────────────────────────────────────────────
compress_report() {
    if command -v zip &>/dev/null; then
        zip "${REPORT_FILE}.zip" "$REPORT_FILE" && rm "$REPORT_FILE"
        echo "Report compressed: ${REPORT_FILE}.zip"
    elif command -v gzip &>/dev/null; then
        gzip "$REPORT_FILE"
        echo "Report compressed: ${REPORT_FILE}.gz"
    else
        echo "No compression tool found. Report saved as plain text."
    fi
}

# ── Email Report ───────────────────────────────────────────────
email_report() {
    local subject="${EMAIL_SUBJECT_PREFIX} Daily Report - $HOSTNAME - $TIMESTAMP"
    local body="Please find attached the daily system health report for $HOSTNAME."

    if command -v mail &>/dev/null; then
        echo "$body" | mail -s "$subject" \
            -a "From: ${EMAIL_FROM}" "${EMAIL_RECIPIENT}"
        echo "Report emailed to ${EMAIL_RECIPIENT}"
    else
        echo "Mail command not found. Skipping email."
    fi
}

# ── Run Post Report Actions ────────────────────────────────────
echo "Report generated successfully!"
echo "------------------------------------------------------"
cat "$REPORT_FILE"
echo "------------------------------------------------------"

compress_report

if [[ "$EMAIL_ENABLED" == "true" ]]; then
    email_report
fi

echo "Done! Check ${REPORT_DIR}/ for your report."
