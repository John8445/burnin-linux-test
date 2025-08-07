#!/bin/bash

echo "🌡️  Thermal & Power Log Analyzer (Consolidated)"
echo "════════════════════════════════════════════════════════════════════════════════"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Look for monitoring_data.csv
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MASTER_LOG="${SCRIPT_DIR}/monitoring_data.csv"

if [ ! -f "$MASTER_LOG" ]; then
    echo "❌ No monitoring data found"
    echo "   Looking for: monitoring_data.csv"
    exit 1
fi

# Get total lines
total_lines=$(wc -l < "$MASTER_LOG")
data_points=$((total_lines - 1))

echo ""
echo "📊 Master Log Analysis"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "   File: ${GREEN}monitoring_data.csv${NC}"
echo -e "   Total data points: ${CYAN}${data_points}${NC}"
echo ""

# Find all unique test IDs
echo "📋 Test Sessions Found:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Get unique test IDs and their info
awk -F',' 'NR>1 && $8!="" && $7=="BURNIN_RUNNING" {print $8}' "$MASTER_LOG" | sort -u | while read test_id; do
    if [ ! -z "$test_id" ]; then
        # Get test info
        start_time=$(awk -F',' -v id="$test_id" '$8==id {print $1; exit}' "$MASTER_LOG")
        end_time=$(awk -F',' -v id="$test_id" '$8==id {time=$1} END {print time}' "$MASTER_LOG")
        duration=$(awk -F',' -v id="$test_id" '$8==id {count++} END {print count * 10 / 60}' "$MASTER_LOG")
        max_temp=$(awk -F',' -v id="$test_id" '$8==id && $2!="N/A" {if($2>max)max=$2} END {print max}' "$MASTER_LOG")
        max_power=$(awk -F',' -v id="$test_id" '$8==id && $3!="N/A" {if($3>max)max=$3} END {print max}' "$MASTER_LOG")

        # Format duration
        if (( $(echo "$duration >= 60" | bc -l) )); then
            hours=$(echo "$duration / 60" | bc)
            mins=$(echo "$duration % 60" | bc)
            duration_str="${hours}h ${mins}m"
        else
            duration_str="$(printf "%.0f" $duration)m"
        fi

        printf "%-3s %-25s %-20s %-10s Peak: %s°C / %sW\n" \
            "•" "$test_id" "$start_time" "$duration_str" "$max_temp" "$max_power"
    fi
done

# Also show IDLE periods summary
idle_count=$(awk -F',' '$7=="IDLE" {count++} END {print count}' "$MASTER_LOG")
if [ "$idle_count" -gt 0 ]; then
    echo ""
    echo -e "   ${YELLOW}Plus ${idle_count} idle monitoring points${NC}"
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Menu for analysis options
echo ""
echo "Analysis Options:"
echo "1) Analyze specific test session"
echo "2) Analyze all data (complete history)"
echo "3) Analyze last test"
echo "4) Export data"
echo "5) Exit"
echo ""

read -p "Select option (1-5): " choice

case $choice in
    1)
        # List tests for selection
        echo ""
        echo "Select test to analyze:"
        i=1
        declare -a test_array
        while read test_id; do
            if [ ! -z "$test_id" ]; then
                test_array[$i]=$test_id
                echo "$i) $test_id"
                ((i++))
            fi
        done < <(awk -F',' 'NR>1 && $8!="" && $7=="BURNIN_RUNNING" {print $8}' "$MASTER_LOG" | sort -u)

        echo ""
        read -p "Select test (1-$((i-1))): " test_choice

        if [ "$test_choice" -ge 1 ] && [ "$test_choice" -lt "$i" ] 2>/dev/null; then
            SELECTED_TEST="${test_array[$test_choice]}"
            analyze_test="$SELECTED_TEST"
        else
            echo "Invalid selection"
            exit 1
        fi
        ;;
    2)
        analyze_test="ALL"
        ;;
    3)
        # Get last test ID
        analyze_test=$(awk -F',' 'NR>1 && $8!="" && $7=="BURNIN_RUNNING" {print $8}' "$MASTER_LOG" | tail -1)
        if [ -z "$analyze_test" ]; then
            echo "No test sessions found"
            exit 1
        fi
        ;;
    4)
        # Export options
        echo ""
        echo "Export format:"
        echo "1) CSV (copy of master file)"
        echo "2) HTML report"
        echo "3) Test summary text"
        read -p "Choice: " export_choice

        case $export_choice in
            1) cp "$MASTER_LOG" "monitoring_data_export_$(date +%Y%m%d_%H%M%S).csv"
               echo "Exported to: monitoring_data_export_$(date +%Y%m%d_%H%M%S).csv" ;;
            2) echo "HTML export not yet implemented" ;;
            3) echo "Text summary not yet implemented" ;;
        esac
        exit 0
        ;;
    5)
        exit 0
        ;;
esac

# Perform analysis
echo ""
echo "📊 ANALYSIS RESULTS"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ "$analyze_test" = "ALL" ]; then
    # Analyze all data
    awk -F',' '
    BEGIN {
        min_temp = 999; max_temp = 0; sum_temp = 0; temp_count = 0
        min_power = 999999; max_power = 0; sum_power = 0; power_count = 0
        first_time = ""; last_time = ""
    }
    NR > 1 {
        if (first_time == "") first_time = $1
        last_time = $1

        if ($2 != "N/A" && $2 != "") {
            temp = $2
            if (temp > max_temp) { max_temp = temp; max_temp_time = $1 }
            if (temp < min_temp) { min_temp = temp; min_temp_time = $1 }
            sum_temp += temp; temp_count++
        }

        if ($3 != "N/A" && $3 != "" && $3 > 0) {
            power = $3
            if (power > max_power) { max_power = power; max_power_time = $1 }
            if (power < min_power) { min_power = power; min_power_time = $1 }
            sum_power += power; power_count++
        }
    }
    END {
        print "\n🕐 Complete History:"
        print "   First Entry: " first_time
        print "   Last Entry:  " last_time
        print "   Total Points: " NR-1

        if (temp_count > 0) {
            avg_temp = sum_temp / temp_count
            print "\n🌡️  Temperature Statistics:"
            printf "   Minimum:    %.1f°C (at %s)\n", min_temp, min_temp_time
            printf "   Maximum:    %.1f°C (at %s)\n", max_temp, max_temp_time
            printf "   Average:    %.1f°C\n", avg_temp
        }

        if (power_count > 0) {
            avg_power = sum_power / power_count
            print "\n⚡ Power Statistics:"
            printf "   Minimum:    %.1fW (at %s)\n", min_power, min_power_time
            printf "   Maximum:    %.1fW (at %s)\n", max_power, max_power_time
            printf "   Average:    %.1fW\n", avg_power
        }
    }' "$MASTER_LOG"
else
    # Analyze specific test
    awk -F',' -v test_id="$analyze_test" '
    BEGIN {
        min_temp = 999; max_temp = 0; sum_temp = 0; temp_count = 0
        min_power = 999999; max_power = 0; sum_power = 0; power_count = 0
        min_cpu = 100; max_cpu = 0; sum_cpu = 0; cpu_count = 0
        min_ram = 100; max_ram = 0; sum_ram = 0; ram_count = 0
        first_time = ""; last_time = ""
    }
    NR > 1 && $8 == test_id {
        if (first_time == "") first_time = $1
        last_time = $1

        if ($2 != "N/A" && $2 != "") {
            temp = $2
            if (temp > max_temp) { max_temp = temp; max_temp_time = $1 }
            if (temp < min_temp) { min_temp = temp; min_temp_time = $1 }
            sum_temp += temp; temp_count++
        }

        if ($3 != "N/A" && $3 != "" && $3 > 0) {
            power = $3
            if (power > max_power) { max_power = power; max_power_time = $1 }
            if (power < min_power) { min_power = power; min_power_time = $1 }
            sum_power += power; power_count++
        }

        if ($4 != "" && $4 >= 0) {
            cpu = $4
            if (cpu > max_cpu) max_cpu = cpu
            if (cpu < min_cpu) min_cpu = cpu
            sum_cpu += cpu; cpu_count++
        }

        if ($5 != "" && $5 >= 0) {
            ram = $5
            if (ram > max_ram) max_ram = ram
            if (ram < min_ram) min_ram = ram
            sum_ram += ram; ram_count++
        }
    }
    END {
        print "\n🕐 Test: " test_id
        print "   Start: " first_time
        print "   End:   " last_time
        print "   Duration: " temp_count * 10 / 60 " minutes"

        if (temp_count > 0) {
            avg_temp = sum_temp / temp_count
            print "\n🌡️  CPU Temperature:"
            printf "   Min: %.1f°C | Max: %.1f°C | Avg: %.1f°C\n", min_temp, max_temp, avg_temp
        }

        if (power_count > 0) {
            avg_power = sum_power / power_count
            print "\n⚡ Power Consumption:"
            printf "   Min: %.1fW | Max: %.1fW | Avg: %.1fW\n", min_power, max_power, avg_power
        }

        if (cpu_count > 0) {
            avg_cpu = sum_cpu / cpu_count
            print "\n💻 CPU Usage:"
            printf "   Min: %d%% | Max: %d%% | Avg: %.1f%%\n", min_cpu, max_cpu, avg_cpu
        }

        if (ram_count > 0) {
            avg_ram = sum_ram / ram_count
            print "\n🧠 RAM Usage:"
            printf "   Min: %d%% | Max: %d%% | Avg: %.1f%%\n", min_ram, max_ram, avg_ram
        }
    }' "$MASTER_LOG"
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""