#!/bin/bash

# Colors for beautiful output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

clear
echo -e "${RED}${BOLD}🔥 SERVER BURN-IN TEST LAUNCHER 🔥${NC}"
echo "════════════════════════════════════════════════════════════════════════════════"
echo ""

# Check if BurnInTest exists
if [ ! -f "./bit_cmd_line_x64" ]; then
    echo -e "${RED}❌ BurnInTest not found in current directory${NC}"
    echo "   Please run the installer first: ./enhanced-install-burnin.sh"
    exit 1
fi

# Check if libasound is available
if ! ldd ./bit_cmd_line_x64 2>&1 | grep -q "not found"; then
    :  # All good
else
    echo -e "${YELLOW}⚠️  Missing libraries detected${NC}"
    echo -e "   BurnInTest may not start properly"
    echo -e "   Try: ${GREEN}apt install libasound2${NC} or ${GREEN}dnf install alsa-lib${NC}"
    echo ""
fi

# System information with icons
HOSTNAME=$(hostname)
CPU_CORES=$(nproc)
CPU_MODEL=$(lscpu | grep "Model name" | cut -d: -f2 | xargs | head -1)
MEMORY_GB=$(free -g | awk '/^Mem:/{print $2}')
MEMORY_MB=$(free -m | awk '/^Mem:/{print $2}')

echo -e "${CYAN}🖥️  System Information:${NC}"
echo -e "   ${BOLD}Server:${NC} $HOSTNAME"
echo -e "   ${BOLD}CPU:${NC} $CPU_MODEL"
echo -e "   ${BOLD}Cores:${NC} $CPU_CORES"
echo -e "   ${BOLD}Memory:${NC} ${MEMORY_GB}GB (${MEMORY_MB}MB)"

# Check power monitoring capability
echo ""
echo -e "${CYAN}⚡ Power Monitoring:${NC}"
if command -v ipmitool >/dev/null 2>&1 && ipmitool dcmi power reading >/dev/null 2>&1; then
    current_power=$(ipmitool dcmi power reading 2>/dev/null | grep "Instantaneous power reading" | awk '{print $4}')
    echo -e "   ${GREEN}✓ IPMI Available (Current: ${current_power}W)${NC}"
elif [ -d /sys/class/powercap/intel-rapl ]; then
    echo -e "   ${GREEN}✓ Intel RAPL Available${NC}"
else
    echo -e "   ${YELLOW}⚠️  Limited power monitoring available${NC}"
fi

echo ""

# Check if thermal monitoring is already running
if pgrep -f "thermal_monitor_hwmon.sh\|thermal_power_monitor.sh" > /dev/null; then
    echo -e "${YELLOW}⚠️  Warning: Monitoring is already running${NC}"
    echo -e "   Another test may be in progress."
    read -p "   Stop it and continue? (y/N): " stop_thermal
    if [[ $stop_thermal =~ ^[Yy]$ ]]; then
        pkill -f "thermal_monitor_hwmon.sh\|thermal_power_monitor.sh"
        echo -e "${GREEN}   ✓ Previous monitoring stopped${NC}"
    else
        echo -e "${RED}   Test cancelled${NC}"
        exit 1
    fi
    echo ""
fi

# Duration selection with visual menu
echo -e "${YELLOW}⏱️  Select Test Duration:${NC}"
echo ""
echo -e "   ${BOLD}Quick Tests:${NC}"
echo -e "   ${CYAN}1)${NC} 10 minutes  - Quick hardware verification"
echo -e "   ${CYAN}2)${NC} 30 minutes  - Basic stability check"
echo ""
echo -e "   ${BOLD}Standard Tests:${NC}"
echo -e "   ${CYAN}3)${NC} 1 hour      - Recommended minimum"
echo -e "   ${CYAN}4)${NC} 4 hours     - Thorough validation"
echo ""
echo -e "   ${BOLD}Extended Tests:${NC}"
echo -e "   ${CYAN}5)${NC} 8 hours     - Overnight testing"
echo -e "   ${CYAN}6)${NC} 12 hours    - Extended validation"
echo -e "   ${CYAN}7)${NC} 24 hours    - Maximum reliability test"
echo ""
echo -e "   ${BOLD}Special:${NC}"
echo -e "   ${CYAN}8)${NC} Custom duration"
echo -e "   ${CYAN}9)${NC} Run forever (until stopped)"
echo ""

read -p "$(echo -e ${BOLD})Enter choice (1-9):${NC} " choice

case $choice in
    1) DURATION=600; DESC="10 minutes"; RECOMMENDATION="Quick verification" ;;
    2) DURATION=1800; DESC="30 minutes"; RECOMMENDATION="Basic check" ;;
    3) DURATION=3600; DESC="1 hour"; RECOMMENDATION="Recommended" ;;
    4) DURATION=14400; DESC="4 hours"; RECOMMENDATION="Thorough" ;;
    5) DURATION=28800; DESC="8 hours"; RECOMMENDATION="Overnight" ;;
    6) DURATION=43200; DESC="12 hours"; RECOMMENDATION="Extended" ;;
    7) DURATION=86400; DESC="24 hours"; RECOMMENDATION="Maximum" ;;
    8)
        read -p "Enter duration in minutes: " mins
        DURATION=$((mins * 60))
        DESC="$mins minutes"
        RECOMMENDATION="Custom"
        ;;
    9) DURATION=0; DESC="Forever"; RECOMMENDATION="Continuous" ;;
    *) echo -e "${RED}Invalid choice!${NC}"; exit 1 ;;
esac

# Test type selection with descriptions
echo ""
echo -e "${YELLOW}🧪 Select Test Components:${NC}"
echo ""
echo -e "   ${CYAN}1)${NC} ${BOLD}Basic${NC} (CPU + Memory + Disk)"
echo -e "      Best for: General hardware validation"
echo ""
echo -e "   ${CYAN}2)${NC} ${BOLD}Standard${NC} (CPU + Memory + Disk + Network)"
echo -e "      Best for: Production server validation"
echo ""
echo -e "   ${CYAN}3)${NC} ${BOLD}CPU Only${NC}"
echo -e "      Best for: Processor stress testing"
echo ""
echo -e "   ${CYAN}4)${NC} ${BOLD}Memory Only${NC}"
echo -e "      Best for: RAM stability testing"
echo ""

read -p "$(echo -e ${BOLD})Enter choice (1-4):${NC} " test_choice

case $test_choice in
    1) TESTS="-C -M -K"; TEST_DESC="Basic (CPU+Memory+Disk)" ;;
    2) TESTS="-C -M -K -E"; TEST_DESC="Standard (All Components)" ;;
    3) TESTS="-C"; TEST_DESC="CPU Only" ;;
    4) TESTS="-M"; TEST_DESC="Memory Only" ;;
    *) echo -e "${RED}Invalid choice!${NC}"; exit 1 ;;
esac

# Summary and confirmation
echo ""
echo -e "${GREEN}📋 Test Configuration Summary:${NC}"
echo -e "   ${BOLD}Duration:${NC} $DESC ($RECOMMENDATION)"
echo -e "   ${BOLD}Components:${NC} $TEST_DESC"
echo -e "   ${BOLD}Monitoring:${NC} Consolidated (monitoring_data.csv)"
echo ""

read -p "$(echo -e ${YELLOW}${BOLD})Ready to start? (y/N):${NC} " confirm

if [[ ! $confirm =~ ^[Yy]$ ]]; then
    echo -e "${RED}❌ Test cancelled${NC}"
    exit 0
fi

# Start the test with visual feedback
echo ""
echo -e "${BLUE}🌡️  Starting monitoring...${NC}"

# Always use thermal_power_monitor.sh now (it's consolidated)
MONITOR_SCRIPT="./thermal_power_monitor.sh"
$MONITOR_SCRIPT 10 &
MONITOR_PID=$!

# Give monitor time to start
sleep 2

# Show where data is being logged
MASTER_LOG="$(pwd)/monitoring_data.csv"
echo -e "${GREEN}   ✓ Logging to: ${BOLD}monitoring_data.csv${NC}"
echo -e "${CYAN}   📊 All test data consolidated in one file${NC}"
echo ""

# Ask about web dashboard
echo ""
echo -e "${YELLOW}🌐 Web Dashboard:${NC}"
read -p "Start web dashboard on port 8081? (y/N): " start_web

if [[ $start_web =~ ^[Yy]$ ]]; then
    echo -e "${BLUE}Starting web dashboard...${NC}"
    ./burnin-web-dashboard.sh 8081 > /dev/null 2>&1 &
    WEB_PID=$!
    sleep 2

    echo -e "${GREEN}✓ Web dashboard available at:${NC}"
    echo -e "   ${CYAN}http://$(hostname -I | awk '{print $1}'):8081${NC}"
    echo -e "   ${CYAN}http://localhost:8081${NC}"
    echo ""
fi

# Countdown
echo -e "${YELLOW}🚀 Starting burn-in test in...${NC}"
for i in 3 2 1; do
    echo -e "   ${BOLD}$i${NC}"
    sleep 1
done

echo ""
echo -e "${RED}${BOLD}🔥 BURN-IN TEST RUNNING 🔥${NC}"
echo "════════════════════════════════════════════════════════════════════════════════"
echo ""
echo -e "${CYAN}💡 Helpful Commands:${NC}"
echo -e "   Monitor temps:  ${GREEN}tail -f monitoring_data.csv${NC}"
echo -e "   Live view:      ${GREEN}./watch_burnin.sh${NC}"
echo -e "   Stop test:      ${GREEN}Press Ctrl+C${NC}"
echo ""

# Show power monitoring tip
echo -e "${YELLOW}⚡ Power Monitoring Active:${NC}"
echo "   Tracking CPU temp, power consumption, and resources"
echo "   All data saved to monitoring_data.csv"
echo ""

echo "════════════════════════════════════════════════════════════════════════════════"
echo ""

# Run the burn-in test with correct options
if [ $DURATION -eq 0 ]; then
    # Run forever
    ./bit_cmd_line_x64 $TESTS
else
    # Convert seconds to minutes for BurnInTest (it expects minutes)
    DURATION_MINUTES=$((DURATION / 60))
    ./bit_cmd_line_x64 -D $DURATION_MINUTES $TESTS
fi

# Test completed - clean up
echo ""
echo -e "${YELLOW}🛑 Stopping monitoring...${NC}"
kill $MONITOR_PID 2>/dev/null || true
wait $MONITOR_PID 2>/dev/null || true

# Stop web dashboard if running
if [ ! -z "$WEB_PID" ]; then
    echo -e "${YELLOW}🛑 Stopping web dashboard...${NC}"
    kill $WEB_PID 2>/dev/null || true
fi

# Show results summary
echo ""
echo -e "${GREEN}${BOLD}✅ TEST COMPLETED!${NC}"
echo "════════════════════════════════════════════════════════════════════════════════"
echo ""

# Quick summary from monitoring_data.csv
if [ -f "monitoring_data.csv" ]; then
    # Get stats for the most recent test
    last_test_id=$(awk -F',' '$7=="BURNIN_RUNNING" {id=$8} END {print id}' monitoring_data.csv)
    
    if [ ! -z "$last_test_id" ]; then
        # Calculate stats for this test
        max_temp=$(awk -F',' -v id="$last_test_id" '$8==id && $2!="N/A" {if($2>max)max=$2} END {print max}' monitoring_data.csv)
        max_power=$(awk -F',' -v id="$last_test_id" '$8==id && $3!="N/A" {if($3>max)max=$3} END {print max}' monitoring_data.csv)
        avg_cpu=$(awk -F',' -v id="$last_test_id" '$8==id && $4!="" {sum+=$4; count++} END {if(count>0) print int(sum/count)}' monitoring_data.csv)
        
        echo -e "${CYAN}📊 Quick Summary:${NC}"
        echo -e "   Test ID: ${BOLD}$last_test_id${NC}"
        if [ ! -z "$max_temp" ]; then
            echo -e "   Peak CPU Temperature: ${BOLD}${max_temp}°C${NC}"
        fi
        if [ ! -z "$max_power" ] && [ "$max_power" != "N/A" ]; then
            echo -e "   Peak Power Draw: ${BOLD}${max_power}W${NC}"
        fi
        if [ ! -z "$avg_cpu" ]; then
            echo -e "   Average CPU Usage: ${BOLD}${avg_cpu}%${NC}"
        fi
    fi
    echo ""
fi

echo -e "${YELLOW}📈 Next Steps:${NC}"
echo -e "   1. Run ${GREEN}./analyze-thermal.sh${NC} for detailed analysis"
echo -e "   2. Check BurnInTest logs for any errors"
echo -e "   3. View all historical data in monitoring_data.csv"
echo -e "   4. Use ${GREEN}./watch_burnin.sh${NC} for live monitoring"
echo ""