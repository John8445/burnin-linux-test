#!/bin/bash

PORT=${1:-8081}
DASHBOARD_DIR="/tmp/burnin-dashboard"
UPDATE_INTERVAL=5

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

mkdir -p "$DASHBOARD_DIR"

# Function to generate dashboard with live data
generate_live_dashboard() {
    # Get latest log file
    LATEST_LOG=$(ls -t /tmp/burnin-*/burnin_*.txt 2>/dev/null | grep -v "_summary\|_readable" | head -1)

    if [ -z "$LATEST_LOG" ]; then
        CURRENT_TEMP="N/A"
        CURRENT_POWER="N/A"
        CPU_USAGE="N/A"
        RAM_USAGE="N/A"
        LOAD_AVG="N/A"
    else
        # Get latest data
        LATEST_LINE=$(tail -1 "$LATEST_LOG")
        IFS=',' read -r timestamp temp power cpu ram ram_used ram_total load1 load5 load15 <<< "$LATEST_LINE"

        CURRENT_TEMP="${temp}°C"
        CURRENT_POWER="${power}W"
        CPU_USAGE="${cpu}%"
        RAM_USAGE="${ram}%"
        LOAD_AVG="${load1}"
    fi

    # Generate HTML directly with data
    cat > "$DASHBOARD_DIR/index.html" << EOF
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <meta http-equiv="refresh" content="5">
    <title>🔥 Burn-in Test Dashboard</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            background: #1a1a2e;
            color: #eee;
            margin: 20px;
        }
        .container {
            max-width: 1200px;
            margin: 0 auto;
        }
        h1 {
            text-align: center;
            color: #ff6b6b;
        }
        .grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
            gap: 20px;
            margin: 20px 0;
        }
        .card {
            background: #16213e;
            padding: 20px;
            border-radius: 10px;
            box-shadow: 0 4px 6px rgba(0,0,0,0.3);
        }
        .metric {
            font-size: 2em;
            font-weight: bold;
            color: #4caf50;
            margin: 10px 0;
        }
        .label {
            color: #888;
            font-size: 0.9em;
        }
        .timestamp {
            text-align: center;
            color: #666;
            margin: 20px 0;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>🔥 Burn-in Test Dashboard</h1>
        <div class="timestamp">Last updated: $(date '+%Y-%m-%d %H:%M:%S')</div>

        <div class="grid">
            <div class="card">
                <h3>🌡️ Temperature</h3>
                <div class="label">Current CPU</div>
                <div class="metric">${CURRENT_TEMP}</div>
            </div>

            <div class="card">
                <h3>⚡ Power</h3>
                <div class="label">Current Draw</div>
                <div class="metric">${CURRENT_POWER}</div>
            </div>

            <div class="card">
                <h3>💻 CPU Usage</h3>
                <div class="label">Utilization</div>
                <div class="metric">${CPU_USAGE}</div>
            </div>

            <div class="card">
                <h3>🧠 RAM Usage</h3>
                <div class="label">Memory Used</div>
                <div class="metric">${RAM_USAGE}</div>
            </div>

            <div class="card">
                <h3>📊 Load Average</h3>
                <div class="label">1 Minute</div>
                <div class="metric">${LOAD_AVG}</div>
            </div>
        </div>

        <div style="text-align: center; margin-top: 40px;">
            <p>Auto-refreshes every 5 seconds</p>
        </div>
    </div>
</body>
</html>
EOF
}

# Cleanup
cleanup() {
    echo -e "\n${YELLOW}Stopping dashboard...${NC}"
    pkill -f "python3 -m http.server $PORT"
    exit 0
}

trap cleanup INT TERM

# Main
echo -e "${CYAN}🔥 Starting Simplified Burn-in Dashboard${NC}"
echo -e "${GREEN}📊 URL: http://$(hostname -I | awk '{print $1}'):${PORT}${NC}"

# Initial generation
generate_live_dashboard

# Start web server
cd "$DASHBOARD_DIR"
python3 -m http.server $PORT > /dev/null 2>&1 &

echo -e "${GREEN}✓ Dashboard started${NC}"
echo -e "${YELLOW}Press Ctrl+C to stop${NC}"

# Update loop
while true; do
    sleep $UPDATE_INTERVAL
    generate_live_dashboard
    echo -ne "\r${CYAN}Updated at $(date '+%H:%M:%S')${NC}"
done
