#!/bin/bash
# Enhanced thermal and power monitoring script with sequential file numbering
# Usage: ./thermal_power_monitor.sh [interval_seconds] [log_file]

INTERVAL=${1:-10}

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Function to find the next available sequential log file
find_next_logfile() {
    local hostname=$(hostname)
    local date_stamp=$(date +%Y%m%d_%H%M%S)
    local base_name="burnin_${hostname}_${date_stamp}"

    # Start with base filename
    local logfile="${base_name}.txt"

    # If base doesn't exist, use it
    if [ ! -f "$logfile" ]; then
        echo "$logfile"
        return
    fi

    # Otherwise, find the next available number
    local counter=1
    while true; do
        logfile="${base_name}_${counter}.txt"
        if [ ! -f "$logfile" ]; then
            echo "$logfile"
            return
        fi
        ((counter++))
    done
}

# Function to find CPU temperature sensor
find_cpu_temp_sensor() {
    local cpu_sensor=""
    local highest_temp=0

    # Look for sensors with CPU-related labels
    for sensor in $(find /sys/class/hwmon/*/temp*_input 2>/dev/null); do
        label_file=$(dirname $sensor)/$(basename $sensor _input)_label
        if [ -f "$label_file" ]; then
            label=$(cat "$label_file" 2>/dev/null)
            # Check for CPU-related labels
            if [[ "$label" =~ (CPU|Package|Core|Tdie|Tctl) ]]; then
                temp_raw=$(cat "$sensor" 2>/dev/null)
                if [ ! -z "$temp_raw" ] && [ "$temp_raw" -gt "$highest_temp" ]; then
                    highest_temp=$temp_raw
                    cpu_sensor=$sensor
                fi
            fi
        fi
    done

    # If no labeled CPU sensor found, use the hottest sensor (likely CPU)
    if [ -z "$cpu_sensor" ]; then
        for sensor in $(find /sys/class/hwmon/*/temp*_input 2>/dev/null); do
            temp_raw=$(cat "$sensor" 2>/dev/null)
            if [ ! -z "$temp_raw" ] && [ "$temp_raw" -gt "$highest_temp" ]; then
                highest_temp=$temp_raw
                cpu_sensor=$sensor
            fi
        done
    fi

    echo "$cpu_sensor"
}

# If no log file specified, generate next sequential one
if [ -z "$2" ]; then
    LOGFILE=$(find_next_logfile)
else
    LOGFILE="$2"
fi

echo -e "${CYAN}🌡️  Starting thermal & power monitoring every ${INTERVAL} seconds${NC}"
echo -e "${GREEN}📊 Logging to: ${LOGFILE}${NC}"
echo -e "${YELLOW}Press Ctrl+C to stop${NC}"
echo ""

# Initialize power tracking variables
power_sum=0
power_count=0
power_min=999999
power_max=0
power_min_time=""
power_max_time=""

# Initialize system resource tracking
cpu_usage_sum=0
ram_usage_sum=0
resource_count=0

# Create log file with comprehensive header
echo "Timestamp,CPU_Temp_C,Power_W,CPU_Usage_%,RAM_Usage_%,RAM_Used_MB,RAM_Total_MB,Load_1m,Load_5m,Load_15m" > "${LOGFILE}"

# Find CPU temperature sensor
CPU_SENSOR=$(find_cpu_temp_sensor)

if [ -z "$CPU_SENSOR" ]; then
    echo -e "${RED}❌ No CPU temperature sensor found!${NC}"
    exit 1
fi

# Get sensor label if available
SENSOR_LABEL="CPU"
label_file=$(dirname $CPU_SENSOR)/$(basename $CPU_SENSOR _input)_label
if [ -f "$label_file" ]; then
    SENSOR_LABEL=$(cat "$label_file" 2>/dev/null)
fi

echo -e "${GREEN}✓ Using temperature sensor: ${SENSOR_LABEL}${NC}"
echo -e "  Path: $CPU_SENSOR"

# Function to get power readings
get_power_reading() {
    local power_watts="N/A"

    # Try IPMI first (most accurate for servers)
    if command -v ipmitool >/dev/null 2>&1; then
        # Try to get power consumption via IPMI
        power_reading=$(ipmitool dcmi power reading 2>/dev/null | grep "Instantaneous power reading" | awk '{print $4}')
        if [ ! -z "$power_reading" ] && [ "$power_reading" != "Not" ]; then
            power_watts="$power_reading"
        fi
    fi

    # Try Intel RAPL (Running Average Power Limit)
    if [ "$power_watts" = "N/A" ]; then
        rapl_path="/sys/class/powercap/intel-rapl:0/energy_uj"
        if [ -r "$rapl_path" ]; then
            # Read energy twice and calculate power
            energy1=$(cat "$rapl_path" 2>/dev/null)
            sleep 0.1
            energy2=$(cat "$rapl_path" 2>/dev/null)
            if [ ! -z "$energy1" ] && ! -z "$energy2" ]; then
                # Calculate power in watts
                power_uj=$((energy2 - energy1))
                power_watts=$(echo "scale=1; $power_uj / 100000" | bc)
            fi
        fi
    fi

    # Try ACPI power_supply
    if [ "$power_watts" = "N/A" ]; then
        for ps in /sys/class/power_supply/*/power_now; do
            if [ -r "$ps" ]; then
                power_uw=$(cat "$ps" 2>/dev/null)
                if [ ! -z "$power_uw" ] && [ "$power_uw" -gt 0 ]; then
                    power_watts=$(echo "scale=1; $power_uw / 1000000" | bc)
                    break
                fi
            fi
        done
    fi

    echo "$power_watts"
}

# Function to get CPU usage
get_cpu_usage() {
    top -b -n1 | grep '%Cpu(s):' | awk '{print $2 + $4}' | cut -d'.' -f1
}

# Function to get RAM usage
get_ram_info() {
    free -m | grep Mem: | awk '{print $3","$2","int(($3/$2)*100)}'
}

# Cleanup function
cleanup() {
    echo ""
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}📊 Monitoring Summary:${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

    if [ $power_count -gt 0 ] && [ "$power_min" != "999999" ]; then
        power_avg=$(echo "scale=1; $power_sum / $power_count" | bc)
        echo ""
        echo -e "${GREEN}⚡ Power Statistics:${NC}"
        echo -e "   ${BLUE}Minimum:${NC} ${power_min}W at ${power_min_time}"
        echo -e "   ${BLUE}Maximum:${NC} ${power_max}W at ${power_max_time}"
        echo -e "   ${BLUE}Average:${NC} ${power_avg}W"
        echo -e "   ${BLUE}Range:${NC}   $(echo "scale=1; $power_max - $power_min" | bc)W"
    fi

    if [ $resource_count -gt 0 ]; then
        cpu_avg=$(echo "scale=1; $cpu_usage_sum / $resource_count" | bc)
        ram_avg=$(echo "scale=1; $ram_usage_sum / $resource_count" | bc)
        echo ""
        echo -e "${GREEN}💻 Resource Usage:${NC}"
        echo -e "   ${BLUE}Average CPU:${NC} ${cpu_avg}%"
        echo -e "   ${BLUE}Average RAM:${NC} ${ram_avg}%"
    fi

    echo ""
    echo -e "${GREEN}📁 Log saved to: ${LOGFILE}${NC}"

    # Create a summary file
    summary_file="${LOGFILE%.txt}_summary.txt"
    {
        echo "Burn-in Test Summary"
        echo "===================="
        echo "Test completed: $(date)"
        echo "Log file: ${LOGFILE}"
        echo ""
        if [ $power_count -gt 0 ] && [ "$power_min" != "999999" ]; then
            echo "Power Statistics:"
            echo "  Minimum: ${power_min}W at ${power_min_time}"
            echo "  Maximum: ${power_max}W at ${power_max_time}"
            echo "  Average: ${power_avg}W"
            echo "  Range: $(echo "scale=1; $power_max - $power_min" | bc)W"
        fi
        if [ $resource_count -gt 0 ]; then
            echo ""
            echo "Resource Usage:"
            echo "  Average CPU: ${cpu_avg}%"
            echo "  Average RAM: ${ram_avg}%"
        fi
    } > "$summary_file"

    echo -e "${GREEN}📝 Summary saved to: ${summary_file}${NC}"
    exit 0
}

trap cleanup INT TERM

# Check if power monitoring is available
echo ""
echo -e "${CYAN}🔌 Checking power monitoring capabilities...${NC}"
test_power=$(get_power_reading)
if [ "$test_power" != "N/A" ]; then
    echo -e "${GREEN}✓ Power monitoring available (${test_power}W detected)${NC}"
    echo -e "   Method: IPMI DCM${NC}"
else
    echo -e "${YELLOW}⚠️  Power monitoring not available on this system${NC}"
    echo -e "   Install ipmitool for server power monitoring"
fi
echo ""

# Main monitoring loop
while true; do
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    # Get power reading
    power_watts=$(get_power_reading)

    # Update power statistics if valid reading
    if [ "$power_watts" != "N/A" ]; then
        # Remove any decimal for comparison
        power_int=$(echo "$power_watts" | cut -d'.' -f1)

        if [ "$power_int" -gt 0 ] 2>/dev/null; then
            power_sum=$(echo "$power_sum + $power_watts" | bc)
            power_count=$((power_count + 1))

            # Check for min/max
            if (( $(echo "$power_watts < $power_min" | bc -l) )); then
                power_min="$power_watts"
                power_min_time="$timestamp"
            fi

            if (( $(echo "$power_watts > $power_max" | bc -l) )); then
                power_max="$power_watts"
                power_max_time="$timestamp"
            fi
        fi
    fi

    # Get system resource usage
    cpu_usage=$(get_cpu_usage)
    ram_info=$(get_ram_info)
    ram_used=$(echo "$ram_info" | cut -d',' -f1)
    ram_total=$(echo "$ram_info" | cut -d',' -f2)
    ram_percent=$(echo "$ram_info" | cut -d',' -f3)

    # Get load averages
    load_avg=$(uptime | awk -F'load average:' '{print $2}' | tr -d ' ')
    load_1m=$(echo "$load_avg" | cut -d',' -f1)
    load_5m=$(echo "$load_avg" | cut -d',' -f2)
    load_15m=$(echo "$load_avg" | cut -d',' -f3)

    # Update resource statistics
    if [ ! -z "$cpu_usage" ]; then
        cpu_usage_sum=$(echo "$cpu_usage_sum + $cpu_usage" | bc)
        ram_usage_sum=$(echo "$ram_usage_sum + $ram_percent" | bc)
        resource_count=$((resource_count + 1))
    fi

    # Read CPU temperature
    if [ -r "$CPU_SENSOR" ]; then
        temp_raw=$(cat "$CPU_SENSOR" 2>/dev/null)

        if [ ! -z "$temp_raw" ] && [ "$temp_raw" -gt 0 ]; then
            temp_c=$(echo "scale=1; $temp_raw/1000" | bc)

            # Log all data to CSV (single line per reading)
            echo "${timestamp},${temp_c},${power_watts},${cpu_usage},${ram_percent},${ram_used},${ram_total},${load_1m},${load_5m},${load_15m}" >> "${LOGFILE}"

            # Display with color coding
            temp_display="${temp_c}°C"
            if (( $(echo "$temp_c > 85" | bc -l) )); then
                temp_display="${RED}${temp_c}°C${NC}"
            elif (( $(echo "$temp_c > 75" | bc -l) )); then
                temp_display="${YELLOW}${temp_c}°C${NC}"
            else
                temp_display="${GREEN}${temp_c}°C${NC}"
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

            echo -e "${timestamp}: ${SENSOR_LABEL}=${temp_display} Power=${power_display} CPU=${cpu_usage}% RAM=${ram_percent}% Load=${load_1m}"
        fi
    fi

    sleep "${INTERVAL}"
done
