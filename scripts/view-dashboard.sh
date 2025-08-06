#!/bin/bash

# Quick launcher for burn-in test web dashboard
# Usage: ./view-dashboard.sh [port]

PORT=${1:-8081}

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m'

# Check if dashboard is already running
if lsof -i :$PORT > /dev/null 2>&1; then
    echo -e "${YELLOW}⚠️  Port $PORT is already in use${NC}"
    echo -e "   Dashboard may already be running"
    echo -e "   Access it at: ${CYAN}http://localhost:$PORT${NC}"
    exit 1
fi

# Check if dashboard script exists
if [ ! -f "./burnin-web-dashboard.sh" ]; then
    echo -e "${RED}❌ Dashboard script not found${NC}"
    echo -e "   Looking for: ./burnin-web-dashboard.sh"
    exit 1
fi

# Check for active tests
ACTIVE_LOGS=$(find /tmp/burnin-* -name "burnin_*.txt" -mmin -1 2>/dev/null | wc -l)

if [ "$ACTIVE_LOGS" -gt 0 ]; then
    echo -e "${GREEN}✓ Found $ACTIVE_LOGS active burn-in test(s)${NC}"
else
    echo -e "${YELLOW}⚠️  No active burn-in tests detected${NC}"
    echo -e "   Dashboard will show historical data only"
fi

echo ""
echo -e "${CYAN}🔥 Starting Burn-in Test Web Dashboard${NC}"
echo ""

# Make sure it's executable
chmod +x burnin-web-dashboard.sh

# Start the dashboard
./burnin-web-dashboard.sh $PORT
