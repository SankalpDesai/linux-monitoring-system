#!/usr/bin/env bash
# log_rotation.sh — Log cleanup, compression and pruning

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/config.cfg"

# ── Setup ──────────────────────────────────────────────────────
mkdir -p "${SCRIPT_DIR}/${LOG_DIR}"
mkdir -p "${SCRIPT_DIR}/${REPORT_DIR}"

TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
ROTATION_LOG="${SCRIPT_DIR}/${LOG_DIR}/rotation.log"

# ── Logger Function ────────────────────────────────────────────
log_msg() {
    local level=$1
    local message=$2
    local entry="[$TIMESTAMP] $level: $message"
    echo "$entry" | tee -a "$ROTATION_LOG"
}

# ── Get file size in bytes (cross-platform) ────────────────────
get_file_size() {
    local file=$1
    if stat -c%s "$file" &>/dev/null; then
        stat -c%s "$file"
    else
        stat -f%z "$file"
    fi
}

log_msg "INFO" "Starting log rotation..."
echo "------------------------------------------------------"

# ── Operation 1: Delete Old Logs ──────────────────────────────
log_msg "INFO" "Operation 1: Deleting logs older than ${LOG_RETENTION_DAYS} days..."

find "${SCRIPT_DIR}/${LOG_DIR}" -name "*.log" \
    -mtime "+${LOG_RETENTION_DAYS}" -delete

find "${SCRIPT_DIR}/${LOG_DIR}" -name "*.gz" \
    -mtime "+${LOG_RETENTION_DAYS}" -delete

log_msg "INFO" "Old log deletion complete"
echo "------------------------------------------------------"

# ── Operation 2: Compress Large Logs ──────────────────────────
log_msg "INFO" "Operation 2: Compressing logs larger than ${LOG_MAX_SIZE_MB}MB..."

MAX_SIZE_BYTES=$(echo "$LOG_MAX_SIZE_MB * 1024 * 1024" | bc)

find "${SCRIPT_DIR}/${LOG_DIR}" -name "*.log" -print0 | \
while read -r -d '' file; do
    file_size=$(get_file_size "$file")
    if (( $(echo "$file_size >= $MAX_SIZE_BYTES" | bc -l) )); then
        log_msg "INFO" "Compressing: $file (${file_size} bytes)"
        gzip "$file"
        log_msg "SUCCESS" "Compressed: ${file}.gz"
    fi
done

log_msg "INFO" "Compression complete"
echo "------------------------------------------------------"

# ── Operation 3: Prune Excess Rotated Files ────────────────────
log_msg "INFO" "Operation 3: Pruning excess compressed files (keeping ${MAX_ROTATED_FILES} newest)..."

for family in health_history alerts self_heal security_update rotation; do
    files=$(ls -t "${SCRIPT_DIR}/${LOG_DIR}/${family}"*.gz 2>/dev/null)
    if [[ -z "$files" ]]; then
        continue
    fi

    file_count=$(echo "$files" | wc -l)
    if (( file_count > MAX_ROTATED_FILES )); then
        excess=$(echo "$files" | tail -n "+$(( MAX_ROTATED_FILES + 1 ))")
        while read -r old_file; do
            rm "$old_file"
            log_msg "INFO" "Removed excess file: $old_file"
        done <<< "$excess"
    fi
done

log_msg "INFO" "Pruning complete"
echo "------------------------------------------------------"

# ── Operation 4: Clean Old Reports ────────────────────────────
log_msg "INFO" "Operation 4: Cleaning reports older than ${LOG_RETENTION_DAYS} days..."

find "${SCRIPT_DIR}/${REPORT_DIR}" -name "report_*" \
    -mtime "+${LOG_RETENTION_DAYS}" -delete

log_msg "INFO" "Old report cleanup complete"
echo "------------------------------------------------------"

# ── Final Summary ──────────────────────────────────────────────
log_msg "INFO" "Log rotation completed successfully"

echo ""
echo "======================================================"
echo "           LOG ROTATION SUMMARY"
echo "======================================================"

echo ""
echo "Current log files:"
ls -lh "${SCRIPT_DIR}/${LOG_DIR}/" 2>/dev/null || echo "No log files found"

echo ""
echo "Current reports:"
ls -lh "${SCRIPT_DIR}/${REPORT_DIR}/" 2>/dev/null || echo "No reports found"

echo ""
echo "Disk usage after rotation:"
df -h "${SCRIPT_DIR}"

echo "======================================================"
log_msg "INFO" "Log rotation finished"
