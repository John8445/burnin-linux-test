#!/bin/bash

echo "🌡️  Thermal & Power Log Analyzer"
echo "════════════════════════════════════════════════════════════════════════════════"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Find thermal log files
LOG_FILES=$(ls -t burnin_*.txt 2>/dev/null | grep -v "_summary.txt" | grep -v "_readable.log" | head -20)

if [ -z "$LOG_FILES" ]; then
    echo "❌ No thermal log files found"
    echo "   Looking for: burnin_*.txt"
    exit 1
fi

echo ""
echo "📊 Available thermal log files:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
printf "%-3s %-30s %-20s %8s %10s %s\n" "#" "Description" "Date/Time" "Size" "Duration" "Status"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Create arrays for file info
i=1
declare -a file_array
declare -a desc_array

for file in $LOG_FILES; do
    file_array[$i]=$file

    # Get file info
    size=$(du -h "$file" 2>/dev/null | cut -f1)
    date_time=$(date -r "$file" "+%Y-%m-%d %H:%M:%S" 2>/dev/null)
    lines=$(wc -l < "$file" 2>/dev/null)
    duration_mins=$((($lines - 1) * 10 / 60))

    # Parse filename for description
    # Format: burnin_hostname_YYYYMMDD_HHMMSS[_N].txt
    hostname=$(echo "$file" | cut -d'_' -f2)
    file_date=$(echo "$file" | cut -d'_' -f3)
    file_time=$(echo "$file" | cut -d'_' -f4 | cut -d'.' -f1)

    # Check if it's a numbered file
    num_underscores=$(echo "$file" | tr -cd '_' | wc -c)
    if [ "$num_underscores" -gt 3 ]; then
        # Has sequence number
        seq_num=$(echo "$file" | cut -d'_' -f5 | cut -d'.' -f1)
        # Check if seq_num is a number
        if [[ "$seq_num" =~ ^[0-9]+$ ]]; then
            description="$hostname Test #$((seq_num + 1))"
        else
            description="$hostname Test"
        fi
    else
        description="$hostname Test #1"
    fi

    # Add today marker if from today
    today_date=$(date +%Y%m%d)
    if [[ "$file_date" == "$today_date" ]]; then
        description="$description (Today)"
    fi

    # Check if file is still being written (modified in last 60 seconds)
    current_time=$(date +%s)
    file_mod_time=$(stat -c %Y "$file" 2>/dev/null || echo 0)
    age_seconds=$((current_time - file_mod_time))

    # Check if enhanced log (has power data)
    has_power="No"
    if head -1 "$file" | grep -q "Power_W"; then
        has_power="Yes"
    fi

    status=""
    if [ "$age_seconds" -lt 60 ]; then
        status="🔴 ACTIVE"
    elif [ "$duration_mins" -lt 10 ]; then
        status="⚠️  Short"
    else
        status="✅ Complete"
    fi

    # Add power indicator to status
    if [ "$has_power" = "Yes" ]; then
        status="$status ⚡"
    fi

    # Format duration
    if [ "$duration_mins" -ge 60 ]; then
        hours=$((duration_mins / 60))
        mins=$((duration_mins % 60))
        duration_str="${hours}h ${mins}m"
    else
        duration_str="${duration_mins}m"
    fi

    desc_array[$i]="$description"

    printf "%-3s %-30s %-20s %8s %10s %s\n" \
        "$i)" "$description" "$date_time" "$size" "$duration_str" "$status"

    i=$((i + 1))
done

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${CYAN}Legend: ⚡ = Power data available${NC}"
echo "$i) Enter custom filename"
echo ""

# File selection
while true; do
    read -p "Select file to analyze (1-$i): " choice

    if [ "$choice" = "$i" ]; then
        read -p "Enter log filename: " LOGFILE
        if [ ! -f "$LOGFILE" ]; then
            echo "❌ File not found: $LOGFILE"
            continue
        fi
        break
    elif [ "$choice" -ge 1 ] && [ "$choice" -lt "$i" ] 2>/dev/null; then
        LOGFILE="${file_array[$choice]}"
        SELECTED_DESC="${desc_array[$choice]}"
        break
    else
        echo "❌ Invalid choice. Please select 1-$i."
    fi
done

echo ""
echo "📈 Analyzing: $LOGFILE"
if [ ! -z "$SELECTED_DESC" ]; then
    echo "📋 Test: $SELECTED_DESC"
fi
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Check if it's an enhanced log with power data
HEADER=$(head -1 "$LOGFILE")
HAS_POWER=false
HAS_RESOURCES=false

if echo "$HEADER" | grep -q "Power_W"; then
    HAS_POWER=true
fi

if echo "$HEADER" | grep -q "CPU_Usage_%"; then
    HAS_RESOURCES=true
fi

# Analyze the file based on type
if [ "$HAS_POWER" = true ] || [ "$HAS_RESOURCES" = true ]; then
    # Enhanced analysis for logs with power/resource data
    awk -F',' '
    BEGIN {
        min_temp = 999; max_temp = 0; sum_temp = 0; count = 0
        min_power = 999999; max_power = 0; sum_power = 0; power_count = 0
        min_cpu = 100; max_cpu = 0; sum_cpu = 0; cpu_count = 0
        min_ram = 100; max_ram = 0; sum_ram = 0; ram_count = 0
        first_time = ""; last_time = ""
        min_power_time = ""; max_power_time = ""
        min_cpu_time = ""; max_cpu_time = ""
        min_ram_time = ""; max_ram_time = ""
    }
    NR > 1 && $2 != "N/A" && $2 != "" {
        temp = $2
        timestamp = $1

        # Temperature stats
        if (temp > max_temp) { max_temp = temp; max_time = timestamp }
        if (temp < min_temp) { min_temp = temp; min_time = timestamp }
        sum_temp += temp; count++

        if (first_time == "") first_time = timestamp
        last_time = timestamp

        # Power stats (column 3)
        if ($3 != "N/A" && $3 != "" && $3 > 0) {
            power = $3
            if (power < min_power) { min_power = power; min_power_time = timestamp }
            if (power > max_power) { max_power = power; max_power_time = timestamp }
            sum_power += power; power_count++
        }

        # CPU usage stats (column 4)
        if ($4 != "" && $4 >= 0) {
            cpu = $4
            if (cpu < min_cpu) { min_cpu = cpu; min_cpu_time = timestamp }
            if (cpu > max_cpu) { max_cpu = cpu; max_cpu_time = timestamp }
            sum_cpu += cpu; cpu_count++
        }

        # RAM usage stats (column 5)
        if ($5 != "" && $5 >= 0) {
            ram = $5
            if (ram < min_ram) { min_ram = ram; min_ram_time = timestamp }
            if (ram > max_ram) { max_ram = ram; max_ram_time = timestamp }
            sum_ram += ram; ram_count++
        }
    }
    END {
        if (count > 0) {
            avg_temp = sum_temp / count
            print ""
            print "📊 COMPREHENSIVE ANALYSIS SUMMARY"
            print "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            print ""
            print "🕐 Test Duration:"
            print "   Start Time: " first_time
            print "   End Time:   " last_time
            print ""

            # Calculate actual duration
            duration_mins = count * 10 / 60
            if (duration_mins >= 60) {
                hours = int(duration_mins / 60)
                mins = int(duration_mins % 60)
                print "   Duration:   " hours " hours " mins " minutes"
            } else {
                print "   Duration:   " int(duration_mins) " minutes"
            }

            print ""
            print "🌡️  CPU Temperature Statistics:"
            printf "   Minimum:    %.1f°C  (at %s)\n", min_temp, min_time
            printf "   Maximum:    %.1f°C  (at %s)\n", max_temp, max_time
            printf "   Average:    %.1f°C\n", avg_temp
            printf "   Range:      %.1f°C\n", max_temp - min_temp

            if (power_count > 0 && min_power < 999999) {
                avg_power = sum_power / power_count
                print ""
                print "⚡ Power Consumption Statistics:"
                printf "   Minimum:    %.1fW  (at %s)\n", min_power, min_power_time
                printf "   Maximum:    %.1fW  (at %s)\n", max_power, max_power_time
                printf "   Average:    %.1fW\n", avg_power
                printf "   Range:      %.1fW\n", max_power - min_power

                # Calculate total energy consumed
                energy_kwh = (avg_power * duration_mins) / (60 * 1000)
                printf "   Total Energy: %.3f kWh\n", energy_kwh
            }

            if (cpu_count > 0) {
                avg_cpu = sum_cpu / cpu_count
                print ""
                print "💻 CPU Usage Statistics:"
                printf "   Minimum:    %d%%  (at %s)\n", min_cpu, min_cpu_time
                printf "   Maximum:    %d%%  (at %s)\n", max_cpu, max_cpu_time
                printf "   Average:    %.1f%%\n", avg_cpu
            }

            if (ram_count > 0) {
                avg_ram = sum_ram / ram_count
                print ""
                print "🧠 RAM Usage Statistics:"
                printf "   Minimum:    %d%%  (at %s)\n", min_ram, min_ram_time
                printf "   Maximum:    %d%%  (at %s)\n", max_ram, max_ram_time
                printf "   Average:    %.1f%%\n", avg_ram
            }

            print ""
            print "📈 Data Points: " count " readings"
            print ""

            # Combined assessment
            print "🛡️  Overall Assessment:"

            # Temperature assessment
            if (max_temp < 85) {
                temp_status = "✅ EXCELLENT"
                temp_msg = "All temperatures in safe range"
            } else if (max_temp < 95) {
                temp_status = "✅ GOOD"
                temp_msg = "Temperatures acceptable"
            } else if (max_temp < 100) {
                temp_status = "⚠️  CAUTION"
                temp_msg = "High temperatures detected"
            } else {
                temp_status = "🔴 WARNING"
                temp_msg = "Excessive temperatures detected"
            }

            print "   Temperature: " temp_status " - " temp_msg

            # Power assessment
            if (power_count > 0 && avg_power > 0) {
                if (max_power < 300) {
                    print "   Power Usage: ✅ EFFICIENT - Low power consumption"
                } else if (max_power < 500) {
                    print "   Power Usage: ✅ NORMAL - Moderate power consumption"
                } else if (max_power < 700) {
                    print "   Power Usage: ⚠️  HIGH - Consider power optimization"
                } else {
                    print "   Power Usage: 🔴 VERY HIGH - Review cooling and workload"
                }
            }

            # Resource assessment
            if (cpu_count > 0 && avg_cpu > 0) {
                if (avg_cpu > 95) {
                    print "   CPU Load:    ✅ MAXIMUM - Full stress achieved"
                } else if (avg_cpu > 80) {
                    print "   CPU Load:    ✅ HIGH - Good stress level"
                } else {
                    print "   CPU Load:    ⚠️  MODERATE - Consider increasing load"
                }
            }

            print "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        } else {
            print "❌ No valid data found in log file"
            print "   Check that monitoring was running during the test"
        }
    }' "$LOGFILE"
else
    # Basic analysis for temperature-only logs
    awk -F',' '
    BEGIN {
        min_temp = 999; max_temp = 0; sum_temp = 0; count = 0
        first_time = ""; last_time = ""
    }
    NR > 1 && $2 != "N/A" && $2 != "" {
        temp = $2
        if (temp > max_temp) { max_temp = temp; max_time = $1 }
        if (temp < min_temp) { min_temp = temp; min_time = $1 }
        sum_temp += temp; count++
        if (first_time == "") first_time = $1
        last_time = $1
    }
    END {
        if (count > 0) {
            avg_temp = sum_temp / count
            print ""
            print "📊 THERMAL ANALYSIS SUMMARY"
            print "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            print ""
            print "🕐 Test Duration:"
            print "   Start Time: " first_time
            print "   End Time:   " last_time
            print ""

            # Calculate actual duration
            duration_mins = count * 10 / 60
            if (duration_mins >= 60) {
                hours = int(duration_mins / 60)
                mins = int(duration_mins % 60)
                print "   Duration:   " hours " hours " mins " minutes"
            } else {
                print "   Duration:   " int(duration_mins) " minutes"
            }

            print ""
            print "🌡️  Temperature Statistics:"
            printf "   Minimum:    %.1f°C  (at %s)\n", min_temp, min_time
            printf "   Maximum:    %.1f°C  (at %s)\n", max_temp, max_time
            printf "   Average:    %.1f°C\n", avg_temp
            printf "   Range:      %.1f°C\n", max_temp - min_temp
            print ""
            print "📈 Temperature Readings: " count " data points"
            print ""

            # Temperature assessment
            if (max_temp < 85) {
                print "🛡️  Status: ✅ EXCELLENT - All temperatures in safe range"
                print "   Analysis: System cooling is working perfectly"
            } else if (max_temp < 95) {
                print "🛡️  Status: ✅ GOOD - Temperatures acceptable"
                print "   Analysis: System is running within normal parameters"
            } else if (max_temp < 100) {
                print "🛡️  Status: ⚠️  CAUTION - High temperatures detected"
                print "   Analysis: Consider checking cooling system and airflow"
            } else {
                print "🛡️  Status: 🔴 WARNING - Excessive temperatures detected"
                print "   Analysis: Immediate cooling inspection recommended"
            }

            print ""
            print "💡 Note: This is a basic thermal log. For power monitoring,"
            print "   use the enhanced monitoring option in launch-burnin.sh"

            print "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        } else {
            print "❌ No valid temperature data found in log file"
            print "   Check that thermal monitoring was running during the test"
        }
    }' "$LOGFILE"
fi

echo ""
echo "💾 Analysis complete!"

# Check if summary file exists
SUMMARY_FILE="${LOGFILE%.txt}_summary.txt"
if [ -f "$SUMMARY_FILE" ]; then
    echo -e "${GREEN}📝 Summary file available: $SUMMARY_FILE${NC}"
fi

echo ""

# Export options
echo "Export Options:"
echo "1) Generate detailed report (HTML)"
echo "2) Generate CSV export"
echo "3) View another log file"
echo "4) Exit"
echo ""
read -p "Choice (1-4): " export_choice

case $export_choice in
    1)
        # Generate HTML report
        HTML_FILE="${LOGFILE%.txt}_report.html"
        {
            echo "<html><head><title>Burn-in Test Report - $SELECTED_DESC</title>"
            echo "<style>body{font-family:Arial;margin:20px;}table{border-collapse:collapse;width:100%;}th,td{border:1px solid #ddd;padding:8px;text-align:left;}th{background-color:#4CAF50;color:white;}</style></head><body>"
            echo "<h1>Burn-in Test Report</h1>"
            echo "<h2>$SELECTED_DESC</h2>"
            echo "<p>Generated: $(date)</p>"
            echo "<p>Log file: $LOGFILE</p>"
            echo "<h3>Summary</h3>"
            ./analyze-thermal.sh < <(echo -e "$choice\n4") | sed 's/\x1B\[[0-9;]*m//g' | sed 's/^/<p>/' | sed 's/$/<\/p>/'
            echo "</body></html>"
        } > "$HTML_FILE"
        echo -e "${GREEN}✓ HTML report saved to: $HTML_FILE${NC}"
        ;;
    2)
        # Generate CSV export
        CSV_FILE="${LOGFILE%.txt}_export.csv"
        if [ "$HAS_POWER" = true ]; then
            # Export with all columns
            cp "$LOGFILE" "$CSV_FILE"
        else
            # Export temperature data only
            cp "$LOGFILE" "$CSV_FILE"
        fi
        echo -e "${GREEN}✓ CSV export saved to: $CSV_FILE${NC}"
        ;;
    3)
        exec "$0"
        ;;
esac
