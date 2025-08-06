# Burnin Linux Test Suite

Automation scripts and tools for running PassMark's BurnInTest on Linux servers.

## Overview

This repository contains a collection of shell scripts designed to automate the deployment, execution, and monitoring of BurnInTest on Linux systems. It includes thermal monitoring, web dashboard functionality, and automated installation processes.

## Repository Structure

`
burnin-linux-test/
+-- scripts/           # Shell scripts for automation
¦   +-- launch-burnin.sh           # Main launcher for tests
¦   +-- enhanced-install-burnin.sh # Automated installation
¦   +-- watch_burnin.sh           # Monitor running tests
¦   +-- view-dashboard.sh         # View test dashboard
¦   +-- burnin-web-dashboard.sh   # Web interface server
¦   +-- thermal_monitor_hwmon.sh  # Hardware thermal monitoring
¦   +-- thermal_power_monitor.sh  # Power and thermal analysis
¦   +-- analyze-thermal.sh        # Thermal data analysis
+-- config/           # Configuration files
¦   +-- cmdline_config.txt        # BurnInTest CLI configuration
¦   +-- plugin_example/           # Example plugin configs
+-- docs/            # Documentation
`

## Prerequisites

- Linux system (Ubuntu/Debian recommended)
- BurnInTest Linux edition (obtain from PassMark Software)
- Bash shell
- Root/sudo access for hardware monitoring
- Web server (optional, for dashboard functionality)

## Installation

1. Clone this repository:
   `ash
   git clone https://github.com/yourusername/burnin-linux-test.git
   cd burnin-linux-test
   `

2. Download BurnInTest Linux from [PassMark Software](https://www.passmark.com/products/burnintest/index.php)

3. Place the BurnInTest binaries in the repository root:
   - it_cmd_line_x64
   - it_gui_x64 (if using GUI version)

4. Make scripts executable:
   `ash
   chmod +x scripts/*.sh
   `

5. Run the installation script:
   `ash
   sudo ./scripts/enhanced-install-burnin.sh
   `

## Usage

### Basic Test Execution
`ash
./scripts/launch-burnin.sh
`

### Monitor Running Tests
`ash
./scripts/watch_burnin.sh
`

### Thermal Monitoring
`ash
# Hardware-based monitoring
sudo ./scripts/thermal_monitor_hwmon.sh

# Combined thermal and power monitoring
sudo ./scripts/thermal_power_monitor.sh
`

### Web Dashboard
`ash
./scripts/burnin-web-dashboard.sh
# Access at http://localhost:8080
`

## Configuration

The main configuration file is located at config/cmdline_config.txt. This file controls:
- Test duration
- Test types to run
- Temperature thresholds
- Logging options

## Scripts Description

- **enhanced-install-burnin.sh**: Automated setup script that handles dependencies and configuration
- **launch-burnin.sh**: Primary script to start burn-in tests with proper configuration
- **watch_burnin.sh**: Real-time monitoring of test progress and results
- **thermal_monitor_hwmon.sh**: Monitors system temperatures using hwmon interface
- **thermal_power_monitor.sh**: Advanced monitoring including power consumption
- **analyze-thermal.sh**: Post-test thermal data analysis and reporting
- **burnin-web-dashboard.sh**: Starts a web server for remote monitoring
- **view-dashboard.sh**: Console-based dashboard viewer

## License

The scripts in this repository are provided under the MIT License. See LICENSE file for details.

**Note**: BurnInTest software is proprietary and licensed separately by PassMark Software Pty Ltd.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## Support

For issues with the scripts, please open a GitHub issue. For BurnInTest software support, contact PassMark Software.
