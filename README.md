# 🔥 Server Burn-in Testing Toolkit (Consolidated Edition)

A comprehensive, enterprise-grade server burn-in testing toolkit with consolidated monitoring, real-time thermal tracking, power consumption monitoring, and web dashboard.

## ✨ What's New in Consolidated Edition

- **Single `monitoring_data.csv`** - All test data in one place, no more hunting for files
- **Proper CPU temperature tracking** - IPMI first, then hwmon with CPU-only sensors
- **Test session management** - Each test gets a unique ID with status tracking
- **Historical data preservation** - All tests accumulate in one master file
- **Simplified monitoring** - No more choosing between basic/enhanced modes

## 🚀 Quick Start

```bash
wget http://69.46.20.130:8080/enhanced-install-burnin.sh && sudo bash enhanced-install-burnin.sh
```

## 📦 What's Included

### Core Scripts

- **enhanced-install-burnin.sh** - Automated installer with dependency management
- **launch-burnin.sh** - Interactive test launcher (simplified - no monitoring menu)
- **thermal_power_monitor.sh** - Consolidated monitoring to `monitoring_data.csv`
- **analyze-thermal.sh** - Comprehensive analyzer for consolidated data
- **watch_burnin.sh** - Pretty console viewer for live monitoring
- **burnin-web-dashboard.sh** - Web dashboard reading from consolidated data
- **view-dashboard.sh** - Quick dashboard launcher

### Key Features

- **Consolidated Monitoring** - All data goes to `monitoring_data.csv`
- **Test Status Tracking** - IDLE → BURNIN_RUNNING → COMPLETED
- **Unique Test IDs** - Each test session gets `test_YYYYMMDD_HHMMSS`
- **Professional stress testing** using PassMark BurnInTest
- **Real-time web dashboard** with 5-second refresh
- **IPMI power monitoring** on supported hardware
- **Cross-platform support** (RHEL/CentOS/Ubuntu/Debian)

## 💻 System Requirements

### Prerequisites
- **Working DNS** - Required for package installation
- **tar** command installed (check with `which tar`)
- **Port 8081 open** in firewall for web dashboard
- **Root/sudo access** for sensor configuration

### Supported Operating Systems
- RHEL/CentOS/AlmaLinux/Rocky 8+
- Ubuntu 20.04+
- Debian 10+
- Fedora 30+

### Dependencies (Auto-installed)
- Python 3 (web dashboard)
- bc (calculations)
- lm-sensors (thermal monitoring)
- ipmitool (power monitoring)
- libasound2/alsa-lib (BurnInTest requirement)
- Various system utilities

## 📖 Usage

### 1. Installation
```bash
wget http://69.46.20.130:8080/enhanced-install-burnin.sh
sudo bash enhanced-install-burnin.sh
```

### 2. Navigate to Installation Directory
```bash
cd /tmp/burnin-YYYYMMDD_HHMMSS
```

### 3. Run Tests
```bash
./launch-burnin.sh
```

Choose:
- **Duration**: 10 minutes to 24 hours (or run forever)
- **Components**: Basic (CPU+Memory+Disk) or Standard (+Network)
- **Web Dashboard**: Auto-offered on port 8081

### 4. Monitor Tests

**Option 1: Web Dashboard (Recommended)**
```bash
# When prompted, choose 'y' for web dashboard
# Access at: http://[server-ip]:8081
```

**Option 2: Pretty Console View**
```bash
./watch_burnin.sh
```

**Option 3: Raw Data**
```bash
tail -f monitoring_data.csv
```

### 5. Analyze Results
```bash
./analyze-thermal.sh
```

Options:
1. Analyze specific test session
2. Analyze all data (complete history)
3. Analyze last test
4. Export data

## 📊 Data Format

All monitoring data is stored in `monitoring_data.csv`:

```csv
Timestamp,CPU_Temp,Power_W,CPU_%,RAM_%,Load_1m,Test_Status,Test_ID
2025-08-07 05:30:13,42,178,0,1,0.00,IDLE,
2025-08-07 05:30:23,58,371,98,72,12.33,BURNIN_RUNNING,test_20250807_053013
2025-08-07 05:40:07,72,380,98,87,35.16,COMPLETED,test_20250807_053013
```

## 🌡️ Temperature Guidelines

| Range | Status | Description |
|-------|---------|-------------|
| < 70°C | 🟢 EXCELLENT | Optimal cooling performance |
| 70-80°C | 🟢 GOOD | Normal operating temperature |
| 80-90°C | 🟡 WARNING | Monitor closely |
| > 90°C | 🔴 CRITICAL | Cooling inspection needed |

## ⚡ Power Monitoring

- Requires IPMI-enabled server hardware
- Shows instantaneous power draw in watts
- Tracks min/max/average across test session
- VMs will show "N/A" (no BMC hardware)

## 🛠️ Troubleshooting

### Missing libasound.so.2
```bash
# Debian/Ubuntu
apt install libasound2

# RHEL/CentOS
dnf install alsa-lib
```

### No Power Readings
- IPMI only works on physical servers
- Check IPMI is enabled in BIOS
- Verify with: `ipmitool sensor list`

### Web Dashboard Not Accessible
```bash
# Open firewall port
firewall-cmd --permanent --add-port=8081/tcp
firewall-cmd --reload
```

### DNS Issues
```bash
# Add DNS servers if needed
echo "nameserver 8.8.8.8" >> /etc/resolv.conf
echo "nameserver 1.1.1.1" >> /etc/resolv.conf
```

## 📈 Example Results

**AMD EPYC 9175F (16-core)**
- Peak Temp: 93°C
- Peak Power: 400W
- Average: 85.9°C / 376.7W

**AMD EPYC 9555P (64-core)**
- Peak Temp: 73°C
- Peak Power: 673W
- Average: 72°C / 656W

## 🏗️ File Structure

```
/tmp/burnin-YYYYMMDD_HHMMSS/
├── monitoring_data.csv           # Consolidated data file (all tests)
├── bit_cmd_line_x64             # BurnInTest executable
├── launch-burnin.sh             # Test launcher
├── thermal_power_monitor.sh     # Consolidated monitor
├── analyze-thermal.sh           # Data analyzer
├── watch_burnin.sh             # Live viewer
├── burnin-web-dashboard.sh     # Web interface
└── system_info.txt             # System details
```

## 🤝 Contributing

Feel free to submit issues or pull requests to improve the toolkit.

## 📜 License

This toolkit is provided as-is for server validation purposes. BurnInTest is proprietary software from PassMark Software.

## 👨‍💻 Author

Enhanced burn-in toolkit with consolidated monitoring for enterprise server testing and validation.