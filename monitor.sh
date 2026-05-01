#!/usr/bin/env bash
# monitor.sh — Real-time system monitoring dashboard

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/config.cfg"

mkdir -p "${SCRIPT_DIR}/${LOG_DIR}"
mkdir -p "${SCRIPT_DIR}/${REPORT_DIR}"

# ── Color Constants ────────────────────────────────────────────
RST="\033[0m"
BOLD="\033[1m"
RED="\033[1;31m"
YELLOW="\033[1;33m"
GREEN="\033[1;32m"
CYAN="\033[1;36m"
WHITE="\033[1;37m"
BLUE="\033[1;34m"
BG_RED="\033[41m"
BG_YELLOW="\033[43m"
BG_GREEN="\033[42m"

# ── Helper Functions ───────────────────────────────────────────

# Returns color code based on value vs thresholds
color_by_threshold() {
    local value=$1
    local warn=$2
    local crit=$3
    if (( $(echo "$value >= $crit" | bc -l) )); then
        echo -e "$RED"
    elif (( $(echo "$value >= $warn" | bc -l) )); then
        echo -e "$YELLOW"
    else
        echo -e "$GREEN"
    fi
}

# Returns status label based on value vs thresholds
status_label() {
    local value=$1
    local warn=$2
    local crit=$3
    if (( $(echo "$value >= $crit" | bc -l) )); then
        echo -e "${BG_RED}${WHITE} CRITICAL ${RST}"
    elif (( $(echo "$value >= $warn" | bc -l) )); then
        echo -e "${BG_YELLOW}${WHITE} WARNING  ${RST}"
    else
        echo -e "${BG_GREEN}${WHITE} NORMAL   ${RST}"
    fi
}

# Draws a progress bar
draw_bar() {
    local percent=$1
    local bar_length=30
    local filled=$(echo "$percent * $bar_length / 100" | bc)
    local empty=$(( bar_length - filled ))
    local bar=""
    for (( i=0; i<filled; i++ )); do
        bar+="█"
    done
    for (( i=0; i<empty; i++ )); do
        bar+="░"
    done
    echo "$bar"
}

# ── Metric Gathering Functions ─────────────────────────────────

# Get CPU usage percentage
get_cpu_usage() {
    local cpu_line1=$(cat /proc/stat | grep '^cpu ')
    sleep 1
    local cpu_line2=$(cat /proc/stat | grep '^cpu ')

    local idle1=$(echo $cpu_line1 | awk '{print $5}')
    local total1=$(echo $cpu_line1 | awk '{print $2+$3+$4+$5+$6+$7+$8}')
    local idle2=$(echo $cpu_line2 | awk '{print $5}')
    local total2=$(echo $cpu_line2 | awk '{print $2+$3+$4+$5+$6+$7+$8}')

    local diff_idle=$(( idle2 - idle1 ))
    local diff_total=$(( total2 - total1 ))
    local cpu_usage=$(echo "scale=1; (1 - $diff_idle / $diff_total) * 100" | bc -l)
    echo "$cpu_usage"
}

# Get memory usage percentage and details
get_memory_usage() {
    local mem_info=$(free -m | grep '^Mem:')
    local total=$(echo $mem_info | awk '{print $2}')
    local used=$(echo $mem_info | awk '{print $3}')
    local percent=$(echo "scale=1; $used * 100 / $total" | bc -l)
    echo "$percent|$used|$total"
}

# Get disk usage percentage
get_disk_usage() {
    local disk_info=$(df -h / | tail -1)
    local percent=$(echo $disk_info | awk '{print $5}' | tr -d '%')
    local used=$(echo $disk_info | awk '{print $3}')
    local total=$(echo $disk_info | awk '{print $2}')
    echo "$percent|$used|$total"
}

# Get load average
get_load_average() {
    local load=$(cat /proc/loadavg | awk '{print $1}')
    echo "$load"
}

# Get top 5 processes by CPU
get_top_processes() {
    ps -eo pid,comm,%cpu,%mem --sort=-%cpu | head -6
}


# ── Alert Triggering + Health Logging ─────────────────────────

# Trigger alerts by calling alerts.sh in background
trigger_alerts() {
    local cpu=$1
    local mem=$2
    local disk=$3
    local load=$4
    bash "${SCRIPT_DIR}/alerts.sh" "$cpu" "$mem" "$disk" "$load" &
}

# Log health snapshot every HEALTH_LOG_INTERVAL seconds
LAST_LOG_TIME=0
log_health() {
    local cpu=$1
    local mem=$2
    local disk=$3
    local load=$4
    local current_time=$(date +%s)
    local elapsed=$(( current_time - LAST_LOG_TIME ))

    if (( elapsed >= HEALTH_LOG_INTERVAL )); then
        local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
        echo "$timestamp | CPU=$cpu% | MEM=$mem% | DISK=$disk% | LOAD=$load" \
            >> "${SCRIPT_DIR}/${HEALTH_LOG}"
        LAST_LOG_TIME=$current_time
    fi
}


# ── Dashboard Renderer ─────────────────────────────────────────

render_dashboard() {
    # Gather all metrics
    local cpu=$(get_cpu_usage)
    local mem_raw=$(get_memory_usage)
    local disk_raw=$(get_disk_usage)
    local load=$(get_load_average)

    # Split pipe-delimited values
    local mem=$(echo $mem_raw | cut -d'|' -f1)
    local mem_used=$(echo $mem_raw | cut -d'|' -f2)
    local mem_total=$(echo $mem_raw | cut -d'|' -f3)

    local disk=$(echo $disk_raw | cut -d'|' -f1)
    local disk_used=$(echo $disk_raw | cut -d'|' -f2)
    local disk_total=$(echo $disk_raw | cut -d'|' -f3)

    # Trigger alerts and log health
    trigger_alerts "$cpu" "$mem" "$disk" "$load"
    log_health "$cpu" "$mem" "$disk" "$load"

    # Clear screen and draw dashboard
    clear
    echo -e "${BOLD}${CYAN}"
    echo "╔══════════════════════════════════════════════╗"
    echo "║       LINUX SYSTEM MONITOR DASHBOARD        ║"
    echo "╚══════════════════════════════════════════════╝"
    echo -e "${RST}"

    # CPU
    local cpu_color=$(color_by_threshold "$cpu" "$CPU_WARN" "$CPU_CRIT")
    local cpu_bar=$(draw_bar "$cpu")
    local cpu_label=$(status_label "$cpu" "$CPU_WARN" "$CPU_CRIT")
    echo -e "${BOLD}CPU Usage   :${RST} ${cpu_color}[${cpu_bar}]${RST} ${cpu_color}${cpu}%${RST}  ${cpu_label}"

    # Memory
    local mem_color=$(color_by_threshold "$mem" "$MEMORY_WARN" "$MEMORY_CRIT")
    local mem_bar=$(draw_bar "$mem")
    local mem_label=$(status_label "$mem" "$MEMORY_WARN" "$MEMORY_CRIT")
    echo -e "${BOLD}Memory      :${RST} ${mem_color}[${mem_bar}]${RST} ${mem_color}${mem}%${RST}  ${mem_label}  (${mem_used}MB / ${mem_total}MB)"

    # Disk
    local disk_color=$(color_by_threshold "$disk" "$DISK_WARN" "$DISK_CRIT")
    local disk_bar=$(draw_bar "$disk")
    local disk_label=$(status_label "$disk" "$DISK_WARN" "$DISK_CRIT")
    echo -e "${BOLD}Disk Usage  :${RST} ${disk_color}[${disk_bar}]${RST} ${disk_color}${disk}%${RST}  ${disk_label}  (${disk_used} / ${disk_total})"

    # Load Average
    local load_color=$(color_by_threshold "$load" "$LOAD_WARN" "$LOAD_CRIT")
    local load_label=$(status_label "$load" "$LOAD_WARN" "$LOAD_CRIT")
    echo -e "${BOLD}Load Avg    :${RST} ${load_color}${load}${RST}  ${load_label}"

    echo ""
    echo -e "${BOLD}${CYAN}── Top Processes ──────────────────────────────────${RST}"
    get_top_processes

    echo ""
    echo -e "${BOLD}${CYAN}── Health Log ─────────────────────────────────────${RST}"
    echo -e "${WHITE}Logging every ${HEALTH_LOG_INTERVAL}s → ${HEALTH_LOG}${RST}"

    echo ""
    echo -e "${YELLOW}Last refresh: $(date '+%Y-%m-%d %H:%M:%S') | Press Ctrl+C to stop${RST}"
}

# ── Main Loop ──────────────────────────────────────────────────
trap "echo -e '\n${GREEN}Dashboard stopped.${RST}'; exit 0" SIGINT SIGTERM

while true; do
    render_dashboard
    sleep "${REFRESH_INTERVAL}"
done
