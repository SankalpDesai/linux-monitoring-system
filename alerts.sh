#!/usr/bin/env bash
# alerts.sh — Threshold alerting system

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/config.cfg"

# ── Receive Metrics as Arguments ───────────────────────────────
CPU="${1:-0}"
MEM="${2:-0}"
DISK="${3:-0}"
LOAD="${4:-0}"

# ── Setup ──────────────────────────────────────────────────────
ALERT_FILE="${SCRIPT_DIR}/${ALERT_LOG}"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
ALERTS_TRIGGERED=()

mkdir -p "${SCRIPT_DIR}/${LOG_DIR}"

# ── Threshold Checker ──────────────────────────────────────────
check_threshold() {
    local metric=$1
    local value=$2
    local warn=$3
    local crit=$4

    if (( $(echo "$value >= $crit" | bc -l) )); then
        local msg="[$TIMESTAMP] CRITICAL: $metric = $value (warn=$warn, crit=$crit)"
        echo "$msg" >> "$ALERT_FILE"
        ALERTS_TRIGGERED+=("$msg")

    elif (( $(echo "$value >= $warn" | bc -l) )); then
        local msg="[$TIMESTAMP] WARNING: $metric = $value (warn=$warn, crit=$crit)"
        echo "$msg" >> "$ALERT_FILE"
        ALERTS_TRIGGERED+=("$msg")
    fi
}

# ── Run All Checks ─────────────────────────────────────────────
check_threshold "CPU"    "$CPU"  "$CPU_WARN"    "$CPU_CRIT"
check_threshold "MEMORY" "$MEM"  "$MEMORY_WARN" "$MEMORY_CRIT"
check_threshold "DISK"   "$DISK" "$DISK_WARN"   "$DISK_CRIT"
check_threshold "LOAD"   "$LOAD" "$LOAD_WARN"   "$LOAD_CRIT"


# ── Email Alert ────────────────────────────────────────────────
send_email_alert() {
    local subject="${EMAIL_SUBJECT_PREFIX} System Alert on $(hostname)"
    local body=""

    for alert in "${ALERTS_TRIGGERED[@]}"; do
        body+="$alert\n"
    done

    if command -v mail &>/dev/null; then
        echo -e "$body" | mail -s "$subject" \
            -a "From: ${EMAIL_FROM}" "${EMAIL_RECIPIENT}"
    elif command -v sendmail &>/dev/null; then
        echo -e "Subject: $subject\n$body" | sendmail "${EMAIL_RECIPIENT}"
    fi
}

# ── Trigger Email If Alerts Exist ─────────────────────────────
if (( ${#ALERTS_TRIGGERED[@]} > 0 )); then
    if [[ "$EMAIL_ENABLED" == "true" ]]; then
        send_email_alert
    fi
fi
