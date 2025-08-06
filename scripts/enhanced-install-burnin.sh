cat > enhanced-install-burnin.sh << 'EOF'
#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

clear
echo -e "${RED}${BOLD}🔥 Enhanced Server Burn-in Test Installer 🔥${NC}"
echo "════════════════════════════════════════════════════════════════════════════════"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}❌ Please run as root${NC}"
    echo "   Usage: sudo bash enhanced-install-burnin.sh"
    exit 1
fi

echo -e "${BLUE}📦 Installing dependencies...${NC}"

# Function to check and install package
install_if_missing() {
    local package=$1
    local package_manager=$2
    
    if ! command -v $package >/dev/null 2>&1 && ! $package_manager list installed $package >/dev/null 2>&1; then
        echo -e "   Installing $package..."
        $package_manager install -y $package >/dev/null 2>&1
    fi
}

# Install dependencies based on OS
if command -v dnf >/dev/null 2>&1; then
    echo "   Detected: RHEL/CentOS/AlmaLinux/Fedora"
    package_manager="dnf"
    
    # Core packages
    packages=(
        bc
        tar
        wget
        curl
        lm_sensors
        ipmitool
        alsa-lib
        stress-ng
        libaio
        numactl
        net-tools
        pciutils
        usbutils
        smartmontools
        sysstat
        dmidecode
        hdparm
        iotop
        htop
        powertop
        turbostat
        perf
        python3
        python3-pip
        lsof
    )
    
    # Install packages
    echo -e "${CYAN}   Installing RHEL/Fedora packages...${NC}"
    for pkg in "${packages[@]}"; do
        $package_manager install -y "$pkg" >/dev/null 2>&1 || true
    done
    
    # Enable and start necessary services
    systemctl enable --now ipmi >/dev/null 2>&1 || true
    
    echo -e "${GREEN}   ✓ RHEL packages installed${NC}"
    
elif command -v apt >/dev/null 2>&1; then
    echo "   Detected: Debian/Ubuntu"
    package_manager="apt"
    
    # Update package list
    echo -e "${CYAN}   Updating package lists...${NC}"
    apt update >/dev/null 2>&1
    
    # Core packages for Debian/Ubuntu
    packages=(
        bc
        tar
        wget
        curl
        lm-sensors
        ipmitool
        stress-ng
        libaio1
        numactl
        net-tools
        pciutils
        usbutils
        smartmontools
        sysstat
        dmidecode
        hdparm
        iotop
        htop
        powertop
        linux-tools-common
        linux-tools-generic
        python3
        python3-pip
        lsof
    )
    
    # Try to install libasound2 (might have different names on different versions)
    echo -e "${CYAN}   Installing Debian/Ubuntu packages...${NC}"
    apt install -y libasound2t64 >/dev/null 2>&1 || apt install -y libasound2 >/dev/null 2>&1
    
    # Install main packages
    for pkg in "${packages[@]}"; do
        apt install -y "$pkg" >/dev/null 2>&1 || true
    done
    
    echo -e "${GREEN}   ✓ Debian packages installed${NC}"
    
elif command -v zypper >/dev/null 2>&1; then
    echo "   Detected: openSUSE"
    package_manager="zypper"
    
    packages=(
        bc
        tar
        wget
        curl
        sensors
        ipmitool
        libasound2
        stress-ng
        libaio1
        numactl
        net-tools
        pciutils
        usbutils
        smartmontools
        sysstat
        dmidecode
        hdparm
        iotop
        htop
        powertop
        python3
        python3-pip
        lsof
    )
    
    echo -e "${CYAN}   Installing openSUSE packages...${NC}"
    for pkg in "${packages[@]}"; do
        zypper install -y "$pkg" >/dev/null 2>&1 || true
    done
    
    echo -e "${GREEN}   ✓ openSUSE packages installed${NC}"
    
elif command -v pacman >/dev/null 2>&1; then
    echo "   Detected: Arch Linux"
    
    packages=(
        bc
        tar
        wget
        curl
        lm_sensors
        ipmitool
        alsa-lib
        stress-ng
        libaio
        numactl
        net-tools
        pciutils
        usbutils
        smartmontools
        sysstat
        dmidecode
        hdparm
        iotop
        htop
        powertop
        perf
        python
        python-pip
        lsof
    )
    
    echo -e "${CYAN}   Installing Arch packages...${NC}"
    for pkg in "${packages[@]}"; do
        pacman -S --noconfirm "$pkg" >/dev/null 2>&1 || true
    done
    
    echo -e "${GREEN}   ✓ Arch packages installed${NC}"
else
    echo -e "${YELLOW}   ⚠️  Unknown OS - manual package installation may be needed${NC}"
fi

# Check Python availability
echo -e "${BLUE}🐍 Checking Python installation...${NC}"
if command -v python3 >/dev/null 2>&1; then
    PYTHON_CMD="python3"
    echo -e "${GREEN}   ✓ Python 3 found${NC}"
elif command -v python >/dev/null 2>&1; then
    # Check if it's Python 3
    if python --version 2>&1 | grep -q "Python 3"; then
        PYTHON_CMD="python"
        echo -e "${GREEN}   ✓ Python 3 found${NC}"
    else
        echo -e "${YELLOW}   ⚠️  Python 3 not found - web dashboard may not work${NC}"
    fi
else
    echo -e "${YELLOW}   ⚠️  Python not found - web dashboard will not work${NC}"
    echo -e "${YELLOW}      Install python3 manually for web dashboard support${NC}"
fi

# Configure sensors
echo -e "${BLUE}🌡️  Configuring sensors...${NC}"
sensors-detect --auto >/dev/null 2>&1 || true
modprobe coretemp >/dev/null 2>&1 || true
modprobe k10temp >/dev/null 2>&1 || true

# Load IPMI modules for power monitoring
echo -e "${BLUE}⚡ Configuring power monitoring...${NC}"
modprobe ipmi_devintf >/dev/null 2>&1 || true
modprobe ipmi_si >/dev/null 2>&1 || true
modprobe ipmi_msghandler >/dev/null 2>&1 || true

# Try to start IPMI service if available
if command -v ipmitool >/dev/null 2>&1; then
    # For systemd systems
    systemctl enable ipmi >/dev/null 2>&1 || true
    systemctl start ipmi >/dev/null 2>&1 || true
    systemctl enable ipmievd >/dev/null 2>&1 || true
    systemctl start ipmievd >/dev/null 2>&1 || true
    
    # Test IPMI
    if ipmitool sensor list >/dev/null 2>&1; then
        echo -e "${GREEN}   ✓ IPMI configured and working${NC}"
    else
        echo -e "${YELLOW}   ⚠️  IPMI installed but not responding (normal for VMs)${NC}"
    fi
else
    echo -e "${YELLOW}   ⚠️  IPMI tools not available${NC}"
fi

# Load IPMI modules for power monitoring
echo -e "${BLUE}⚡ Configuring power monitoring...${NC}"
modprobe ipmi_devintf >/dev/null 2>&1 || true
modprobe ipmi_si >/dev/null 2>&1 || true
modprobe ipmi_msghandler >/dev/null 2>&1 || true

# Enable MSR for advanced CPU monitoring
modprobe msr >/dev/null 2>&1 || true

# Create symbolic links for libraries if needed
if [ -f /lib/x86_64-linux-gnu/libasound.so.2 ] && [ ! -f /usr/lib/libasound.so.2 ]; then
    ln -sf /lib/x86_64-linux-gnu/libasound.so.2 /usr/lib/libasound.so.2 2>/dev/null || true
fi

# Create rapl permissions for power monitoring
if [ -d /sys/class/powercap/intel-rapl ]; then
    chmod -R a+r /sys/class/powercap/intel-rapl* 2>/dev/null || true
fi

echo -e "${GREEN}   ✓ Dependencies ready${NC}"

# Create unique work directory
WORK_DIR="/tmp/burnin-$(date +%Y%m%d_%H%M%S)"
mkdir -p "$WORK_DIR"
cd "$WORK_DIR"

echo -e "${BLUE}⬇️  Downloading burn-in toolkit...${NC}"

# Try primary server first
DOWNLOAD_URL="http://69.46.20.130:8080/burnin-complete.tar.gz"
DOWNLOAD_SUCCESS=false

# Download with progress indication and timeout
if wget --timeout=30 --tries=2 -q --show-progress "$DOWNLOAD_URL" 2>/dev/null; then
    DOWNLOAD_SUCCESS=true
else
    echo -e "${YELLOW}   Primary server failed, trying backup...${NC}"
    # You can add backup URLs here if needed
    BACKUP_URL="http://69.46.20.130:8080/burnin-complete.tar.gz"
    if wget --timeout=30 --tries=2 -q --show-progress "$BACKUP_URL" 2>/dev/null; then
        DOWNLOAD_SUCCESS=true
    fi
fi

if [ "$DOWNLOAD_SUCCESS" = false ] || [ ! -f "burnin-complete.tar.gz" ]; then
    echo -e "${RED}❌ Download failed!${NC}"
    echo "   Please check your internet connection"
    exit 1
fi

echo -e "${BLUE}📦 Extracting toolkit...${NC}"
tar -xzf burnin-complete.tar.gz
rm burnin-complete.tar.gz

# Make all scripts executable
chmod +x *.sh bit_cmd_line_x64 >/dev/null 2>&1

# Check system capabilities
echo ""
echo -e "${CYAN}🔍 System Capability Check:${NC}"

# Check thermal monitoring
if [ -n "$(find /sys/class/hwmon/*/temp*_input 2>/dev/null)" ]; then
    echo -e "${GREEN}   ✓ Thermal monitoring: Available${NC}"
else
    echo -e "${YELLOW}   ⚠️  Thermal monitoring: Not detected${NC}"
fi

# Check power monitoring
if command -v ipmitool >/dev/null 2>&1 && ipmitool dcmi power reading >/dev/null 2>&1; then
    echo -e "${GREEN}   ✓ IPMI power monitoring: Available${NC}"
elif [ -d /sys/class/powercap/intel-rapl ]; then
    echo -e "${GREEN}   ✓ Intel RAPL power monitoring: Available${NC}"
else
    echo -e "${YELLOW}   ⚠️  Power monitoring: Limited/Not available${NC}"
fi

# Check CPU frequency scaling
if [ -f /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor ]; then
    echo -e "${GREEN}   ✓ CPU frequency scaling: Available${NC}"
else
    echo -e "${YELLOW}   ⚠️  CPU frequency scaling: Not detected${NC}"
fi

# Check web dashboard capability
if [ ! -z "$PYTHON_CMD" ]; then
    echo -e "${GREEN}   ✓ Web dashboard: Available${NC}"
else
    echo -e "${YELLOW}   ⚠️  Web dashboard: Python 3 required${NC}"
fi

echo ""
echo -e "${GREEN}${BOLD}✅ Installation Complete!${NC}"
echo ""
echo -e "${YELLOW}📁 Location:${NC} $WORK_DIR"
echo ""
echo -e "${BLUE}🚀 Quick Start Commands:${NC}"
echo -e "   ${GREEN}cd $WORK_DIR${NC}"
echo -e "   ${GREEN}./launch-burnin.sh${NC}    # Interactive menu"
echo -e "   ${GREEN}./analyze-thermal.sh${NC}  # Analyze results"
echo -e "   ${GREEN}./view-dashboard.sh${NC}   # Start web dashboard"
echo ""
echo -e "${YELLOW}📖 Features:${NC}"
echo "   • Thermal monitoring with real-time display"
echo "   • Power consumption logging (if supported)"
echo "   • CPU & RAM usage tracking"
echo "   • System load monitoring"
echo "   • Automatic sequential log numbering"
echo "   • Comprehensive post-test analysis"
echo "   • Web dashboard on port 8081 (requires Python 3)"
echo ""
echo -e "${CYAN}💡 Pro Tips:${NC}"
echo "   • Run as root for best sensor access"
echo "   • Check logs in real-time: tail -f burnin_*.txt"
echo "   • Power monitoring works best on servers with IPMI"
echo "   • Access web dashboard at http://[server-ip]:8081"
echo "   • Use ./watch_burnin.sh for pretty console monitoring"
echo ""

# Create a simple system info file
{
    echo "System Information - $(date)"
    echo "================================"
    echo "Hostname: $(hostname)"
    echo "Kernel: $(uname -r)"
    echo "CPU: $(lscpu | grep "Model name" | cut -d: -f2 | xargs)"
    echo "Cores: $(nproc)"
    echo "Memory: $(free -h | grep Mem: | awk '{print $2}')"
    echo "Python: ${PYTHON_CMD:-Not found}"
    echo "================================"
} > system_info.txt

echo -e "${GREEN}📋 System info saved to: system_info.txt${NC}"
echo ""
EOF
