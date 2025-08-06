#!/bin/bash
# Enhanced R6715 Thermal monitoring script with sequential file numbering
# Usage: ./thermal_monitor_hwmon.sh [interval_seconds] [log_file]

INTERVAL=${1:-10}

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

# If no log file specified, generate next sequential one
if [ -z "$2" ]; then
    LOGFILE=$(find_next_logfile)
else
    LOGFILE="$2"
fi

echo "Starting thermal monitoring every ${INTERVAL} seconds"
echo "Logging to: ${LOGFILE}"
echo "Press Ctrl+C to stop"

# Create log file with header
echo "Timestamp,CPU_Temp_C,Sensor_Path" > "${LOGFILE}"

# Find temperature sensors
TEMP_SENSORS=$(find /sys/class/hwmon/*/temp*_input 2>/dev/null)

if [ -z "$TEMP_SENSORS" ]; then
    echo "No temperature sensors found!"
    exit 1
fi

echo "Found temperature sensors:"
for sensor in $TEMP_SENSORS; do
    label_file=$(dirname $sensor)/$(basename $sensor _input)_label
    if [ -f "$label_file" ]; then
        label=$(cat "$label_file" 2>/dev/null)
        echo "  $sensor: $label"
    else
        echo "  $sensor: (no label)"
    fi
done

# Cleanup function
cleanup() {
    echo ""
    echo "Monitoring stopped. Log saved to: ${LOGFILE}"
    exit 0
}

trap cleanup INT TERM

# Main monitoring loop
while true; do
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    for sensor in $TEMP_SENSORS; do
        if [ -r "$sensor" ]; then
            temp_raw=$(cat "$sensor" 2>/dev/null)
            
            if [ ! -z "$temp_raw" ] && [ "$temp_raw" -gt 0 ]; then
                temp_c=$(echo "scale=1; $temp_raw/1000" | bc)
                echo "${timestamp},${temp_c},${sensor}" >> "${LOGFILE}"
                echo "${timestamp}: ${temp_c}°C (${sensor})"
            fi
        fi
    done
    
    sleep "${INTERVAL}"
done
