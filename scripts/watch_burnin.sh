#!/bin/bash
# Pretty live monitoring viewer for consolidated burn-in data
# Usage: ./watch_burnin.sh

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# Find monitoring_data.csv
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOGFILE="${SCRIPT_DIR}/monitoring_data.csv"

if [ ! -f "$LOGFILE" ]; then
    echo "❌ No monitoring data found!"
    echo "   Looking for: monitoring_data.csv"
    exit 1
fi

echo -e "${CYAN}📊 Live Burn-in Monitor (Consolidated)${NC}"
echo -e "${GREEN}📁 Data file: monitoring_data.csv${NC}"
echo -e "${YELLOW}Press Ctrl+C to stop${NC}"
echo ""

# Function to format the display
format_line() {
    local line="$1"

    # Skip header or empty lines
    if [[ "$line" == "Timestamp,CPU_Temp"* ]] || [ -z "$line" ]; then
        return
    fi

    # Parse CSV fields: Timestamp,CPU_Temp,Power_W,CPU_%,RAM_%,Load_1m,Test_Status,Test_ID
    IFS=',' read -r timestamp temp power cpu ram load status test_id <<< "$line"

    # Color code temperature
    temp_color="${GREEN}"
    if [ "$temp" != "N/A" ] && [ ! -z "$temp" ]; then
        if (( $(echo "$temp > 85" | bc -l) )); then
            temp_color="${RED}"
        elif (( $(echo "$temp > 75" | bc -l) )); then
            temp_color="${YELLOW}"
        fi
    fi

    # Color code power
    power_color="${CYAN}"
    if [ "$power" != "N/A" ] && [ ! -z "$power" ]; then
        if (( $(echo "${power} > 500" | bc -l) )); then
            power_color="${RED}"
        elif (( $(echo "${power} > 400" | bc -l) )); then
            power_color="${YELLOW}"
        fi
    fi

    # Status indicator
    case "$status" in
        "BURNIN_RUNNING")
            status_icon="${RED}● BURN${NC}"
            status_color="${RED}"
            ;;
        "IDLE")
            status_icon="${GREEN}○ IDLE${NC}"
            status_color="${GREEN}"
            ;;
        "COMPLETED")
            status_icon="${YELLOW}✓ DONE${NC}"
            status_color="${YELLOW}"
            ;;
        *)
            status_icon="? ????"
            status_color="${NC}"
            ;;
    esac

    # Format the output
    printf "${BOLD}%s${NC} %s\n" "$timestamp" "$status_icon"
    printf "  🌡️  CPU: ${temp_color}%-6s${NC}  " "${temp}°C"
    printf "⚡ Power: ${power_color}%-7s${NC}  " "${power}W"
    printf "💻 CPU: %-4s  " "${cpu}%"
    printf "🧠 RAM: %-4s  " "${ram}%"
    printf "📊 Load: %s\n" "${load}"

    # Show test ID if running
    if [ "$status" = "BURNIN_RUNNING" ] && [ ! -z "$test_id" ]; then
        printf "  ${CYAN}Test: %s${NC}\n" "$test_id"
    fi

    echo ""
}

# Watch the file with tail and format each line
tail -f "$LOGFILE" | while IFS= read -r line; do
    format_line "$line"
done