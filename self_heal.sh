#!/usr/bin/env bash
# self_heal.sh — Auto-restart critical services if they go down

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/config.cfg"

# ── Setup ──────────────────────────────────────────────────────
mkdir -p "${SCRIPT_DIR}/${LOG_DIR}"
HEAL_LOG="${SCRIPT_DIR}/${SELF_HEAL_LOG}"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

# ── Logger Function ────────────────────────────────────────────
log_msg() {
    local level=$1
    local message=$2
    local entry="[$TIMESTAMP] $level: $message"
    echo "$entry" | tee -a "$HEAL_LOG"
}

# ── Check systemctl availability ───────────────────────────────
if ! command -v systemctl &>/dev/null; then
    log_msg "ERROR" "systemctl not found. This script requires systemd."
    exit 1
fi

# ── Email Escalation ───────────────────────────────────────────
send_escalation_email() {
    local service=$1
    local subject="${EMAIL_SUBJECT_PREFIX} CRITICAL: $service failed on $(hostname)"
    local body="Service $service could not be restarted after $MAX_RESTART_RETRIES attempts on $(hostname) at $TIMESTAMP"

    if [[ "$EMAIL_ENABLED" == "true" ]]; then
        if command -v mail &>/dev/null; then
            echo "$body" | mail -s "$subject" \
                -a "From: ${EMAIL_FROM}" "${EMAIL_RECIPIENT}"
        fi
    fi
}

# ── Service Check + Heal ───────────────────────────────────────
check_and_heal() {
    local service=$1

    log_msg "INFO" "Checking service: $service"

    # Check if service unit exists on this system
    if ! systemctl list-unit-files | grep -q "^${service}"; then
        log_msg "INFO" "Service $service not found on this system. Skipping."
        return 0
    fi

    # Check if service is running
    if systemctl is-active --quiet "$service"; then
        log_msg "OK" "$service is running"
        return 0
    fi

    # Service is down — attempt restart
    log_msg "WARNING" "$service is down! Attempting restart..."

    local success=false
    for attempt in $(seq 1 "$MAX_RESTART_RETRIES"); do
        log_msg "INFO" "Restart attempt $attempt of $MAX_RESTART_RETRIES for $service"

        sudo systemctl restart "$service" 2>/dev/null
        sleep 2

        if systemctl is-active --quiet "$service"; then
            log_msg "SUCCESS" "$service restarted successfully on attempt $attempt"
            success=true
            break
        fi

        log_msg "WARNING" "Attempt $attempt failed for $service"
    done

    # If all retries failed
    if [[ "$success" == "false" ]]; then
        log_msg "ERROR" "$service could not be restarted after $MAX_RESTART_RETRIES attempts!"
        send_escalation_email "$service"
    fi
}

# ── Main Execution ─────────────────────────────────────────────
log_msg "INFO" "Starting self-heal check on $(hostname)"
log_msg "INFO" "Monitoring services: $CRITICAL_SERVICES"
echo "------------------------------------------------------"

# Loop through each critical service
for service in $CRITICAL_SERVICES; do
    check_and_heal "$service"
    echo "------------------------------------------------------"
done

log_msg "INFO" "Self-heal check completed"
