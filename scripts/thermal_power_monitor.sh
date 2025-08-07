#!/bin/bash
# thermal_power_monitor.sh - Consolidated monitoring to single CSV
# Writes to monitoring_data.csv in the same directory

INTERVAL=${1:-10}
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MASTER_LOG="${SCRIPT_DIR}/monitoring_data.csv"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}🌡️  Thermal & Power Monitor (Consolidated)${NC}"
echo -e "${GREEN}📊 Logging to: ${MASTER_LOG}${NC}"
echo -e "${YELLOW}Press Ctrl+C to stop${NC}"
echo ""

# Initialize tracking variables
power_sum=0
power_count=0
power_min=999999
power_max=0
test_start_time=""
current_test_id=""
test_status="IDLE"

# Create CSV with header if it doesn't exist
if [ ! -f "$MASTER_LOG" ]; then
    echo "Timestamp,CPU_Temp,Power_W,CPU_%,RAM_%,Load_1m,Test_Status,Test_ID" > "$MASTER_LOG"
    echo -e "${GREEN}✓ Created monitoring_data.csv${NC}"
else
    echo -e "${CYAN}✓ Appending to existing monitoring_data.csv${NC}"
    # Check how many lines already exist
    existing_lines=$(wc -l < "$MASTER_LOG")
    echo -e "${CYAN}   Existing data points: $((existing_lines - 1))${NC}"
fi

# Function to get CPU temperature from IPMI first, then fallback
get_cpu_temp() {
    local temp="N/A"

    # Try IPMI first (most accurate for servers)
    if command -v ipmitool >/dev/null 2>&1; then
        temp=$(ipmitool sensor get "CPU0 Temp" 2>/dev/null | grep "Sensor Reading" | awk '{print $4}')
        if [ ! -z "$temp" ] && [[ "$temp" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
            echo "$temp"
            return
        fi
    fi

    # Fallback to hwmon sensors
    for sensor in $(find /sys/class/hwmon/*/temp*_input 2>/dev/null); do
        label_file=$(dirname $sensor)/$(basename $sensor _input)_label
        if [ -f "$label_file" ]; then
            label=$(cat "$label_file" 2>/dev/null)
            if [[ "$label" =~ (CPU|Package|Core|Tdie|Tctl) ]]; then
                temp_raw=$(cat "$sensor" 2>/dev/null)
                if [ ! -z "$temp_raw" ] && [ "$temp_raw" -gt 0 ]; then
                    temp=$(echo "scale=1; $temp_raw/1000" | bc)
                    echo "$temp"
                    return
                fi
            fi
        fi
    done

    echo "N/A"
}

# Function to get power reading
get_power_reading() {
    local power="N/A"

    if command -v ipmitool >/dev/null 2>&1; then
        power=$(ipmitool dcmi power reading 2>/dev/null | grep "Instantaneous power reading" | awk '{print $4}')
        if [ ! -z "$power" ] && [ "$power" != "Not" ]; then
            echo "$power"
            return
        fi
    fi

    echo "N/A"
}

# Function to get system stats
get_cpu_usage() {
    top -b -n1 | grep '%Cpu(s):' | awk '{print $2 + $4}' | cut -d'.' -f1
}

get_ram_usage() {
    free | grep Mem | awk '{print int($3/$2 * 100)}'
}

get_load_avg() {
    uptime | awk -F'load average:' '{print $2}' | awk -F',' '{print $1}' | tr -d ' '
}

# Check monitoring capabilities
echo -e "${CYAN}🔍 Checking monitoring capabilities...${NC}"

# Test CPU temp
test_temp=$(get_cpu_temp)
if [ "$test_temp" != "N/A" ]; then
    echo -e "${GREEN}✓ CPU temperature monitoring available (${test_temp}°C)${NC}"
    if command -v ipmitool >/dev/null 2>&1 && ipmitool sensor get "CPU0 Temp" >/dev/null 2>&1; then
        echo -e "   Using: IPMI CPU0 Temp sensor${NC}"
    else
        echo -e "   Using: hwmon sensors${NC}"
    fi
else
    echo -e "${YELLOW}⚠️  CPU temperature monitoring not available${NC}"
fi

# Test power
test_power=$(get_power_reading)
if [ "$test_power" != "N/A" ]; then
    echo -e "${GREEN}✓ Power monitoring available (${test_power}W)${NC}"
else
    echo -e "${YELLOW}⚠️  Power monitoring not available${NC}"
fi

echo ""

# Cleanup function
cleanup() {
    echo ""
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

    # Log final status
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "${timestamp},N/A,N/A,N/A,N/A,N/A,STOPPED,${current_test_id}" >> "$MASTER_LOG"

    # Quick summary
    if [ $power_count -gt 0 ] && [ "$power_min" != "999999" ]; then
        power_avg=$(echo "scale=1; $power_sum / $power_count" | bc)
        echo -e "${GREEN}⚡ Power Statistics:${NC}"
        echo -e "   Average: ${power_avg}W | Min: ${power_min}W | Max: ${power_max}W"
    fi

    echo -e "${GREEN}📁 Data saved to: ${MASTER_LOG}${NC}"
    echo -e "${CYAN}   Total readings in file: $(wc -l < "$MASTER_LOG")${NC}"
    exit 0
}

trap cleanup INT TERM

# Main monitoring loop
while true; do
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    # Get current readings
    cpu_temp=$(get_cpu_temp)
    power_watts=$(get_power_reading)
    cpu_usage=$(get_cpu_usage)
    ram_usage=$(get_ram_usage)
    load_1m=$(get_load_avg)

    # Determine test status and ID
    if pgrep -f "bit_cmd_line_x64" > /dev/null; then
        if [ "$test_status" != "BURNIN_RUNNING" ]; then
            # Test just started
            test_status="BURNIN_RUNNING"
            current_test_id="test_$(date +%Y%m%d_%H%M%S)"
            test_start_time="$timestamp"
            echo -e "${GREEN}🔥 Burn-in test detected - ID: ${current_test_id}${NC}"
        fi
    else
        if [ "$test_status" = "BURNIN_RUNNING" ]; then
            # Test just ended
            test_status="COMPLETED"
            echo -e "${YELLOW}✓ Burn-in test completed - ID: ${current_test_id}${NC}"
        else
            test_status="IDLE"
        fi
    fi

    # Update power statistics if valid
    if [ "$power_watts" != "N/A" ] && [ "$power_watts" -gt 0 ] 2>/dev/null; then
        power_sum=$(echo "$power_sum + $power_watts" | bc)
        power_count=$((power_count + 1))

        if (( $(echo "$power_watts < $power_min" | bc -l) )); then
            power_min="$power_watts"
        fi
        if (( $(echo "$power_watts > $power_max" | bc -l) )); then
            power_max="$power_watts"
        fi
    fi

    # Write to CSV
    echo "${timestamp},${cpu_temp},${power_watts},${cpu_usage},${ram_usage},${load_1m},${test_status},${current_test_id}" >> "$MASTER_LOG"

    # Display with color coding
    temp_display="${cpu_temp}°C"
    if [ "$cpu_temp" != "N/A" ]; then
        if (( $(echo "$cpu_temp > 85" | bc -l) )); then
            temp_display="${RED}${cpu_temp}°C${NC}"
        elif (( $(echo "$cpu_temp > 75" | bc -l) )); then
            temp_display="${YELLOW}${cpu_temp}°C${NC}"
        else
            temp_display="${GREEN}${cpu_temp}°C${NC}"
        fi
    fi

    power_display="${power_watts}W"
    if [ "$power_watts" != "N/A" ]; then
        if (( $(echo "${power_watts} > 500" | bc -l) )); then
            power_display="${RED}${power_watts}W${NC}"
        elif (( $(echo "${power_watts} > 400" | bc -l) )); then
            power_display="${YELLOW}${power_watts}W${NC}"
        else
            power_display="${CYAN}${power_watts}W${NC}"
        fi
    fi

    # Status icon
    case $test_status in
        "BURNIN_RUNNING") status_icon="${RED}●${NC}" ;;
        "IDLE") status_icon="${GREEN}○${NC}" ;;
        *) status_icon="${YELLOW}◐${NC}" ;;
    esac

    echo -e "${timestamp} ${status_icon} CPU=${temp_display} Power=${power_display} Load=${load_1m} CPU=${cpu_usage}% RAM=${ram_usage}% [${test_status}]"

    sleep "${INTERVAL}"
done