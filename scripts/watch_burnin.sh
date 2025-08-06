#!/bin/bash
# Pretty live monitoring viewer for burn-in tests
# Usage: ./watch-burnin.sh [log_file]

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# Find the latest log file if not specified
if [ -z "$1" ]; then
    LOGFILE=$(ls -t burnin_*.txt 2>/dev/null | head -1)
    if [ -z "$LOGFILE" ]; then
        echo "No burn-in log files found!"
        exit 1
    fi
else
    LOGFILE="$1"
fi

echo -e "${CYAN}📊 Live Burn-in Monitor - ${LOGFILE}${NC}"
echo -e "${YELLOW}Press Ctrl+C to stop${NC}"
echo ""

# Function to format the display
format_line() {
    local line="$1"
    
    # Skip header or empty lines
    if [[ "$line" == "Timestamp,CPU_Temp_C"* ]] || [ -z "$line" ]; then
        return
    fi
    
    # Parse CSV fields
    IFS=',' read -r timestamp temp power cpu ram ram_used ram_total load1 load5 load15 sensor <<< "$line"
    
    # Color code temperature
    if (( $(echo "$temp > 85" | bc -l) )); then
        temp_color="${RED}"
    elif (( $(echo "$temp > 75" | bc -l) )); then
        temp_color="${YELLOW}"
    else
        temp_color="${GREEN}"
    fi
    
    # Color code power
    if (( $(echo "${power:-0} > 400" | bc -l) )); then
        power_color="${RED}"
    elif (( $(echo "${power:-0} > 300" | bc -l) )); then
        power_color="${YELLOW}"
    else
        power_color="${CYAN}"
    fi
    
    # Format the output
    printf "${BOLD}%s${NC}\n" "$timestamp"
    printf "  🌡️  Temp: ${temp_color}%-6s${NC}  " "${temp}°C"
    printf "⚡ Power: ${power_color}%-7s${NC}  " "${power}W"
    printf "💻 CPU: %-4s  " "${cpu}%"
    printf "🧠 RAM: %-4s  " "${ram}%"
    printf "📊 Load: %s\n" "${load1}"
    echo ""
}

# Watch the file with tail and format each line
tail -f "$LOGFILE" | while IFS= read -r line; do
    format_line "$line"
done
