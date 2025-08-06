# 🔥 Server Burn-in Testing Toolkit

A comprehensive, enterprise-grade server burn-in testing toolkit with real-time thermal monitoring, power consumption tracking, and web dashboard.

## ✨ Features

- **One-line installation** with automatic dependency management
- **Professional stress testing** using PassMark BurnInTest
- **Real-time monitoring** with web dashboard and console views
- **Power consumption tracking** via IPMI (on supported hardware)
- **CPU temperature monitoring** with intelligent sensor detection
- **Beautiful web interface** accessible from any device
- **Detailed analysis** with min/max/average statistics
- **Cross-platform support** (RHEL/CentOS/AlmaLinux/Ubuntu/Debian/Arch/openSUSE)

## 🚀 Quick Start

```bash
wget http://69.46.20.130:8080/enhanced-install-burnin.sh && sudo bash enhanced-install-burnin.sh
📦 What's Included
Core Scripts

enhanced-install-burnin.sh - Automated installer with dependency management
launch-burnin.sh - Interactive test launcher with duration/component selection
thermal_power_monitor.sh - Enhanced monitoring (temp + power + resources)
thermal_monitor_hwmon.sh - Basic temperature monitoring
analyze-thermal.sh - Comprehensive log analyzer with statistical analysis
watch_burnin.sh - Pretty console monitoring viewer
burnin-web-dashboard.sh - Web dashboard server
view-dashboard.sh - Quick dashboard launcher

New Web Dashboard

Real-time updates every 5 seconds
Clean, modern interface with dark theme
Mobile-friendly responsive design
Remote monitoring from any browser
No installation required on client side

Components Tested

CPU - Mathematical operations stress test
Memory - RAM read/write patterns
Disk - I/O operations on mounted filesystems
Network - Loopback network stress testing

💻 System Requirements
Supported Operating Systems

RHEL/CentOS/AlmaLinux 8+
Rocky Linux 8+
Ubuntu 20.04+
Debian 10+
openSUSE Leap 15+
Arch Linux
Fedora 30+

Dependencies (Auto-installed)

Python 3 - Web dashboard server
bc - Basic calculator for thermal monitoring
lm-sensors - Hardware monitoring support
ipmitool - IPMI interface for power monitoring
stress-ng - Alternative stress testing tool
Various system utilities (lsof, net-tools, pciutils, etc.)

📖 Usage
1. Installation
bashwget http://69.46.20.130:8080/enhanced-install-burnin.sh
sudo bash enhanced-install-burnin.sh
2. Navigate to Installation Directory
bashcd /tmp/burnin-YYYYMMDD_HHMMSS
3. Run Tests
bash./launch-burnin.sh
Choose:

Duration: 10 minutes to 24 hours (or run forever)
Components: Basic (CPU+Memory+Disk) or Standard (+Network)
Monitoring: Enhanced (with power) or Basic (temp only)
Web Dashboard: Start on port 8081 (optional)

4. Monitor Tests
Option 1: Web Dashboard (Recommended)
bash# When prompted during launch, choose 'y' for web dashboard
# Or start manually:
./view-dashboard.sh

# Access at: http://[server-ip]:8081
Option 2: Pretty Console View
bash./watch_burnin.sh
Option 3: Raw Log Monitoring
bashtail -f burnin_*.txt
5. Analyze Results
bash./analyze-thermal.sh
📊 Enhanced Monitoring Features
Power Monitoring (IPMI)

Real-time power consumption in watts
Min/max/average power statistics
Total energy consumed (kWh)
Works on servers with IPMI/BMC hardware

Resource Tracking

CPU usage percentage
RAM usage percentage
System load averages
All data logged to CSV format

Temperature Monitoring

Intelligent CPU sensor detection
Support for multiple sensor types (coretemp, k10temp, etc.)
Color-coded temperature warnings

⏱️ Test Duration Recommendations

Quick Check: 10-30 minutes - Basic hardware verification
Standard: 1-4 hours - Recommended for production servers
Thorough: 8-12 hours - Overnight validation
Maximum: 24 hours - Complete reliability testing

🌡️ Temperature Guidelines
RangeStatusDescription< 70°C🟢 EXCELLENTOptimal cooling performance70-80°C🟢 GOODNormal operating temperature80-90°C🟡 WARNINGMonitor closely> 90°C🔴 CRITICALCooling inspection needed
⚡ Power Consumption Guidelines
RangeStatusDescription< 300W🔵 EFFICIENTLow power consumption300-500W🟢 NORMALTypical server load500-700W🟡 HIGHConsider optimization> 700W🔴 VERY HIGHReview cooling and PSU
📁 Log File Format
Enhanced monitoring creates CSV logs with:
csvTimestamp,CPU_Temp_C,Power_W,CPU_Usage_%,RAM_Usage_%,RAM_Used_MB,RAM_Total_MB,Load_1m,Load_5m,Load_15m
2025-08-05 02:28:24,71.1,569,99,82,104768,127436,28.48,27.93,26.15
🛠️ Troubleshooting
No Power Readings

IPMI only works on physical servers with BMC hardware
Virtual machines will show "N/A" for power
Ensure IPMI is configured in BIOS/iDRAC/iLO

Web Dashboard Issues
bash# Check if Python 3 is installed
python3 --version

# Check if port 8081 is open
firewall-cmd --add-port=8081/tcp
Missing Dependencies
The installer handles all dependencies automatically. If issues persist:
bash# RHEL/CentOS/AlmaLinux
sudo dnf install python3 bc lm_sensors ipmitool

# Ubuntu/Debian  
sudo apt install python3 bc lm-sensors ipmitool
🏗️ File Structure
/tmp/burnin-YYYYMMDD_HHMMSS/
├── bit_cmd_line_x64              # BurnInTest executable
├── launch-burnin.sh              # Interactive launcher
├── thermal_power_monitor.sh      # Enhanced monitoring
├── thermal_monitor_hwmon.sh      # Basic monitoring
├── analyze-thermal.sh            # Analysis tool
├── watch_burnin.sh              # Console viewer
├── burnin-web-dashboard.sh      # Web dashboard
├── view-dashboard.sh            # Dashboard launcher
├── burnin_*.txt                 # Log files (created during tests)
├── *_summary.txt                # Test summaries
└── system_info.txt              # System information
📈 What's New
Version 2.0 (Current)

✨ Web dashboard with real-time monitoring
⚡ IPMI power consumption tracking
📊 Enhanced resource monitoring (CPU/RAM/Load)
🎨 Improved console output with color coding
🔧 Better sensor detection (CPU-only temps)
🐛 Fixed analyze script parsing errors
📦 Python 3 auto-installation

🤝 Contributing
Feel free to submit issues or pull requests to improve the toolkit.
📜 License
This toolkit is provided as-is for server validation purposes. BurnInTest is proprietary software from PassMark Software.
👨‍💻 Author
Enhanced burn-in toolkit with web dashboard capabilities for enterprise server testing and validation.

For support or questions, please open an issue in the repository.