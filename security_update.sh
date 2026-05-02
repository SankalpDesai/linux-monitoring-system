#!/usr/bin/env bash
# security_update.sh — Security-only patch installer

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/config.cfg"

# ── Setup ──────────────────────────────────────────────────────
mkdir -p "${SCRIPT_DIR}/${LOG_DIR}"
SEC_LOG="${SCRIPT_DIR}/${SECURITY_LOG}"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

# ── Logger Function ────────────────────────────────────────────
log_msg() {
    local level=$1
    local message=$2
    local entry="[$TIMESTAMP] $level: $message"
    echo "$entry" | tee -a "$SEC_LOG"
}

# ── Refresh timestamp ──────────────────────────────────────────
refresh_timestamp() {
    TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
}

# ── Email Alert on Failure ─────────────────────────────────────
send_failure_alert() {
    local message=$1
    local subject="${EMAIL_SUBJECT_PREFIX} Security Update FAILED on $(hostname)"

    if [[ "$EMAIL_ENABLED" == "true" ]]; then
        if command -v mail &>/dev/null; then
            echo "$message" | mail -s "$subject" \
                -a "From: ${EMAIL_FROM}" "${EMAIL_RECIPIENT}"
        fi
    fi
}

# ── Detect Distro ──────────────────────────────────────────────
if [[ -f /etc/os-release ]]; then
    source /etc/os-release
    DISTRO="${ID:-unknown}"
    DISTRO_VERSION="${VERSION_ID:-unknown}"
else
    DISTRO="unknown"
    DISTRO_VERSION="unknown"
fi

log_msg "INFO" "Starting security updates on $(hostname)"
log_msg "INFO" "Detected distro: $DISTRO $DISTRO_VERSION"
echo "======================================================"

# ── Run Security Updates ───────────────────────────────────────
START_TIME=$(date +%s)
log_msg "INFO" "Running security updates..."
echo "------------------------------------------------------"

case "$DISTRO" in
    ubuntu|debian)
        log_msg "INFO" "Running Ubuntu/Debian security updates..."

        # Refresh package list first
        sudo apt-get update -y 2>&1 | tail -3 | tee -a "$SEC_LOG"

        # Install security updates only
        if command -v unattended-upgrade &>/dev/null; then
            log_msg "INFO" "Using unattended-upgrade for security-only updates"
            UPDATE_OUTPUT=$(sudo unattended-upgrade -d 2>&1)
            RESULT=$?
        else
            log_msg "INFO" "Using apt-get with security sources only"
            UPDATE_OUTPUT=$(DEBIAN_FRONTEND=noninteractive \
                sudo apt-get upgrade -y \
                -o Dir::Etc::SourceList=/etc/apt/sources.list.d/ubuntu-esm-infra.list \
                2>&1)
            RESULT=$?
        fi

        echo "$UPDATE_OUTPUT" | tail -20 | tee -a "$SEC_LOG"

        if (( RESULT == 0 )); then
            refresh_timestamp
            log_msg "SUCCESS" "Ubuntu/Debian security updates completed"
        else
            refresh_timestamp
            log_msg "ERROR" "Ubuntu/Debian security updates failed!"
            send_failure_alert "Security update failed on $(hostname) at $TIMESTAMP"
        fi
        ;;

    centos|rhel|rocky|almalinux)
        log_msg "INFO" "Running CentOS/RHEL security updates..."

        if command -v yum &>/dev/null; then
            UPDATE_OUTPUT=$(sudo yum update --security -y 2>&1)
            RESULT=$?
        else
            UPDATE_OUTPUT=$(sudo dnf update --security -y 2>&1)
            RESULT=$?
        fi

        echo "$UPDATE_OUTPUT" | tail -20 | tee -a "$SEC_LOG"

        if (( RESULT == 0 )); then
            refresh_timestamp
            log_msg "SUCCESS" "CentOS/RHEL security updates completed"
        else
            refresh_timestamp
            log_msg "ERROR" "CentOS/RHEL security updates failed!"
            send_failure_alert "Security update failed on $(hostname) at $TIMESTAMP"
        fi
        ;;

    fedora)
        log_msg "INFO" "Running Fedora security updates..."

        UPDATE_OUTPUT=$(sudo dnf update --security -y 2>&1)
        RESULT=$?

        echo "$UPDATE_OUTPUT" | tail -20 | tee -a "$SEC_LOG"

        if (( RESULT == 0 )); then
            refresh_timestamp
            log_msg "SUCCESS" "Fedora security updates completed"
        else
            refresh_timestamp
            log_msg "ERROR" "Fedora security updates failed!"
            send_failure_alert "Security update failed on $(hostname) at $TIMESTAMP"
        fi
        ;;

    *)
        log_msg "WARNING" "Unsupported distro: $DISTRO. Skipping security updates."
        ;;
esac

echo "------------------------------------------------------"
END_TIME=$(date +%s)
DURATION=$(( END_TIME - START_TIME ))
refresh_timestamp
log_msg "INFO" "Security update process completed in ${DURATION} seconds"

# ── Check if Reboot Required ───────────────────────────────────
refresh_timestamp
echo "------------------------------------------------------"
log_msg "INFO" "Checking if reboot is required..."

if [[ -f /var/run/reboot-required ]]; then
    log_msg "WARNING" "REBOOT REQUIRED after security updates!"
    log_msg "WARNING" "Please schedule a reboot at your earliest convenience"

    if [[ "$EMAIL_ENABLED" == "true" ]]; then
        send_failure_alert "Reboot required on $(hostname) after security updates at $TIMESTAMP"
    fi
else
    log_msg "INFO" "No reboot required"
fi

echo "------------------------------------------------------"

# ── Final Summary ──────────────────────────────────────────────
refresh_timestamp
log_msg "INFO" "Security update finished"

echo ""
echo "======================================================"
echo "         SECURITY UPDATE SUMMARY"
echo "======================================================"
echo ""
echo "Distro       : $DISTRO $DISTRO_VERSION"
echo "Hostname     : $(hostname)"
echo "Completed at : $TIMESTAMP"
echo ""
echo "Last 10 log entries:"
tail -10 "$SEC_LOG"
echo ""
echo "======================================================"
log_msg "INFO" "Next run: Sunday 3AM (via cron)"
