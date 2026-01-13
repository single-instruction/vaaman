# Vaaman FPGA Development Guide

## Project Goal
Program the Vaaman FPGA (Efinix Trion T120F324) with SHA3 and SHA256 cryptographic hash implementations.

---

## Table of Contents
- [Hardware Overview](#hardware-overview)
- [FPGA Specifications](#fpga-specifications)
- [Development Environment Setup](#development-environment-setup)
- [FPGA Development Workflow](#fpga-development-workflow)
- [Programming Methods](#programming-methods)
- [GPIO and Pin Mapping](#gpio-and-pin-mapping)
- [Example Projects](#example-projects)
- [SHA256/SHA3 Implementation Guidelines](#sha256sha3-implementation-guidelines)
- [Troubleshooting](#troubleshooting)
- [Resources](#resources)

---

## Hardware Overview

### Vaaman Single Board Computer
The Vaaman SBC combines a powerful ARM processor with an FPGA for hybrid computing applications.

**Main Processor:**
- Rockchip RK3399 SoC
- 6-core ARM (Cortex-A72 + Cortex-A53)
- Up to 2.0 GHz
- 4GB RAM, 16GB eMMC storage

**Board Features:**
- 40-pin Raspberry Pi-compatible GPIO header
- Additional 40-pin FPGA GPIO header (80 total GPIOs)
- HDMI 2.0 (4K@60Hz), MIPI DSI, USB-C DP
- Gigabit Ethernet (RTL8211E)
- WiFi 2.4G+5G & Bluetooth 5.0 (RTL8822CS)
- USB 2.0 (x2), USB 3.0, USB Type-C
- MIPI CSI camera interface
- Audio (3.5mm jack with mic)
- PCIe via FPC connector

**Physical:**
- Dimensions: 85mm x 85mm x 20mm
- Weight: 60 grams
- Power: 12V/5A (via USB-C PD cable)

**Critical:** Always use 12V power supply. 5V can damage the board.

---

## FPGA Specifications

### Efinix Trion T120F324

**Device Details:**
- Model: Efinix Trion T120F324
- Package: 324-ball FineLine BGA
- Timing Model: C3

**Memory & Storage:**
- DDR3 SDRAM: 4Gbit (256Mx16, 1.35V/1.5V)
- SPI NOR Flash: 128 Mbit (shared with processor)

**I/O Configuration:**
- Configurable voltage banks: 1.8V, 2.5V, 3.3V
- 40 dedicated FPGA GPIO pins
- LVDS/GPIO dual-mode pins
- PMOD-compatible pins (29-40)

**Clock Sources:**
Multiple on-board oscillators available:
- 10 MHz
- 20 MHz
- 25 MHz
- 30 MHz
- 50 MHz
- 74.25 MHz (up to 74.5 MHz)

**User Features:**
- 4 user-controllable LEDs
- 10-pin JTAG header for programming
- Camera Data Interface (CDI) pins

---

## Development Environment Setup

### Prerequisites

**Required:**
- Vaaman SBC with power adapter (12V/5A)
- USB-to-JTAG module (10-pin, color-coded)
- Micro HDMI to HDMI cable
- USB keyboard and mouse
- HDMI monitor

**Optional:**
- Serial adapter (for UART debugging at 1500000 baud)
- SD card or NVMe drive
- Network connection (Ethernet or WiFi)

### Software Installation

#### 1. Efinity IDE (Primary Development Tool)

**Linux Installation:**
```bash
# Download from https://www.efinixinc.com/support/efinity.php
# (Free license after registration)

# Extract the archive
tar -xvf efinity_<version>.tar.bz2

# Source the setup script
cd <efinix-folder>/bin/
source setup.sh

# Install USB drivers
sudo ./install_usb_driver.sh

# Launch Efinity
efinity
```

**Persistent Configuration:**
Add to `~/.bashrc`:
```bash
source /path/to/<efinix-folder>/bin/setup.sh
```

**Troubleshooting:**
On some Ubuntu versions, install required libraries:
```bash
sudo apt install libxcb*
```

**Windows Installation:**
```bash
# Run the .msi installer
# Optionally create desktop shortcut
cd <installation_directory>/bin/
install_desktop.sh

# Launch via desktop icon or command line
bin\setup.bat --run
```

**Windows USB Driver (Zadig):**
1. Download Zadig v2.7+ from https://zadig.akeo.ie/
2. Run as Administrator
3. Options → List All Devices
4. For each interface, select "libusb-win32" and click Replace Driver

#### 2. Simulation Tools

**iVerilog (Verilog Compiler/Simulator):**
- Download: https://bleyer.org/icarus or https://github.com/steveicarus/iverilog
- Free and open-source

**GTKWave (Waveform Viewer):**

Linux:
```bash
sudo apt-get update
sudo apt-get install gtkwave
```

Windows:
- Download from https://sourceforge.net/projects/gtkwave/files/
- Unzip and optionally add to system PATH

#### 3. Vaaman Board Setup

**First-Time Boot:**
```bash
# Default credentials
Username: vicharak
Password: 12345

# Access via SSH (after network setup)
ssh vicharak@<IP_address>

# Or via serial console (1500000 baud rate)
# Connect GND, TX, RX pins
```

**Boot Priority:**
1. NVMe drive (if present)
2. SD card (if present)
3. eMMC storage (default)

---

## FPGA Development Workflow

### 1. Project Creation

In Efinity IDE:
1. Create new project
2. Select FPGA: **Trion T120F324**
3. Select timing model: **C3**
4. Choose HDL language: Verilog, SystemVerilog, or VHDL

### 2. Design Implementation

**Adding Design Files:**
- Dashboard → Design tab → Right-click → Add/Create Verilog files
- Write RTL code in the built-in gedit editor
- Specify the top module

**Project Structure:**
```
project_name/
├── design/
│   ├── top_module.v
│   ├── submodule1.v
│   └── submodule2.v
├── constraints/
│   └── timing.sdc
└── outflow/
    └── (generated bitstream files)
```

### 3. Pin Mapping

**Interface Designer:**
1. Navigate to Interface Designer
2. Access Resource Assigner
3. Map pins according to board pinout

**GPIO Configuration:**
- Create GPIO blocks
- Configure as input/output per design requirements
- Use pinout guide for correct physical mapping

**Common Pin Assignments:**
- User LEDs: Via specific GPIO pins (see examples)
- UART TX/RX: For serial communication
- Clock input: From oscillator to GPIO pin

### 4. Clock Configuration

**Using On-Board Oscillators:**
1. Choose clock source (10-74.25 MHz)
2. Designate GPIO pin as `PLL_CLK_IN` connection type
3. Create PLL block in Interface Designer
4. Configure PLL to generate desired frequency

**Example:**
For 100 MHz clock from 74.25 MHz oscillator:
- Input: GPIOR_188 (74.25 MHz)
- PLL configuration: Multiply/divide to achieve 100 MHz

### 5. Timing Constraints (Optional)

Create SDC constraint file specifying:
- Clock definitions
- Input/output delays
- Virtual clocks
- Timing requirements

Helps guide placement and routing optimization.

### 6. Synthesis & Implementation

**Compilation Process:**
1. Click Synthesize button
2. Automatically runs complete flow:
   - Synthesis
   - Placement
   - Routing
   - Bitstream generation
3. Generated files appear in `outflow/` directory

**Output Files:**
- `.bit`: Bitstream file (for JTAG programming)
- `.hex`: Hex file (for command-line programming)

---

## Programming Methods

### Method 1: Efinity IDE (JTAG)

**Hardware Setup:**
1. Connect USB-to-JTAG module to Vaaman's 10-pin JTAG header
2. Ensure proper color-coded alignment
3. Power on Vaaman board (12V)

**Programming Steps:**
1. Open Efinity 2021.2 or later
2. Refresh USB target
3. Select bitstream file (`.bit`)
4. Choose JTAG programming mode
5. Initiate programming

**Verification:**
- Orange LED on Vaaman should blink (for LED demo)
- Four green LEDs may sequence during operation

### Method 2: Linux Command-Line (vaaman-ctl)

**Direct Programming:**
```bash
sudo vaaman-ctl -i /path/to/bitstream.hex
```

**Requirements:**
- Vicharak kernel and system image
- HEX file (not `.bit` file)

### Method 3: SPI Flash Programming (Persistent)

Store FPGA configuration in SPI flash for automatic loading on boot.

**Flash Programming:**
```bash
# Write hex file to SPI flash
sudo flashcp /path/to/bitstream.hex

# Configure FPGA to boot from SPI flash
sudo read_from_flash
```

**Advantages:**
- FPGA auto-configures on power-up
- No need to reprogram after reset
- Shared flash architecture (processor + FPGA)

**Requirements:**
- Vicharak kernel and system image
- Modified `flashcp` utility

---

## GPIO and Pin Mapping

### GPIO Voltage Levels

**Standard Header (40-pin):**
- Pin 32 (GPIO3_C0): 3.3V (~3.46V tolerance)
- Pin 26 (ADC_IN0): 1.8V (~1.98V tolerance)
- Other GPIOs: 3.0V (~3.15V tolerance)

**FPGA GPIO Header (40-pin):**
- Configurable: 1.8V, 2.5V, or 3.3V banks
- Pins 29-40: Standard PMOD pinout

### Notable Pins (Standard Header)

**I2C:**
- Pins 3 & 5: I2C7 (SDA/SCL) - cannot be used as GPIOs
- Pins 27-28: I2C2
- Pins 29-31: I2C6

**SPI:**
- Pin 7, 29, 31, 33: SPI2 (CLK, TXD, RXD, CSn)

**UART:**
- Pins 8 & 10: UART2 (TXD/RXD at 115200 baud or higher)
- Pin 7: Connected to MIPI CSI; used by UART2 (can be disabled via vicharak-config)

**ADC:**
- Pin 26: ADC input with voltage divider for monitoring

### GPIO Numbering

Software notation: GPIO0_A0 through GPIO4_D7
Translates to: GPIO numbers 0-159

### FPGA GPIO Header

**40 dedicated pins including:**
- Standard GPIO
- LVDS/GPIO dual-mode pins
- LED outputs (4 user LEDs)
- Camera Data Interface (CDI) pins
- PMOD-compatible pins (29-40)

---

## Example Projects

Vicharak provides reference implementations to accelerate development.

### 1. LED Blinking Demo

**Repository:**
```bash
git clone https://github.com/vicharak-in/LED_BLINKING_DEMO
```

**Features:**
- Basic output control using GPIO pins
- Clock: GPIOR_188 for clock source
- 4 user LEDs connected to specific GPIO pins
- Visual verification of FPGA operation

**Workflow:**
1. Clone repository
2. Open XML project file in Efinity
3. Configure PLL clock settings
4. Synthesize design
5. Load bitstream to board
6. Observe LED blinking pattern

### 2. UART Communication Demo

**Repository:**
```bash
git clone https://github.com/vicharak-in/UART_RX_TX_DEMO
```

**Features:**
- Data transmission and reception via UART
- Clock: GPIOR_188 set to 100 MHz
- TX/RX pins for serial communication
- Serial terminal testing

**Testing:**
1. Clone repository
2. Open XML project file in Efinity
3. Configure PLL for 100 MHz clock
4. Synthesize and load bitstream
5. Use GTKTERM serial terminal software
6. Send/receive data to verify operation

**GTKTERM Configuration:**
- Baud rate: 115200 (or as configured)
- Data bits: 8
- Stop bits: 1
- Parity: None

---

## SHA256/SHA3 Implementation Guidelines

### Overview

Implementing cryptographic hash functions on FPGAs leverages parallelism and pipelining for high-throughput applications.

**Target Algorithms:**
- **SHA-256**: Part of SHA-2 family, 256-bit output
- **SHA-3**: Based on Keccak, variable output length

### Design Considerations

#### 1. Resource Utilization

**Trion T120F324 Resources:**
Check Efinix documentation for exact specifications:
- Logic Elements (LEs)
- Embedded memory blocks
- DSP blocks (if applicable)

**SHA-256 Typical Requirements:**
- ~2,000-3,000 LEs (unrolled single round)
- ~10,000-20,000 LEs (fully pipelined)
- Minimal memory (constants and state registers)

**SHA-3 (Keccak) Typical Requirements:**
- ~15,000-30,000 LEs (depends on implementation)
- 1600-bit state array
- Permutation rounds can be pipelined or iterative

**Recommendation:** Start with iterative implementations to conserve resources, then optimize for throughput.

#### 2. Architecture Choices

**Iterative (Sequential):**
- Processes one round per clock cycle
- Lower resource usage
- Lower throughput (64 cycles for SHA-256, 24 rounds for SHA-3)
- Suitable for resource-constrained designs

**Unrolled/Pipelined:**
- Processes multiple rounds simultaneously
- Higher resource usage
- Higher throughput (one hash per few cycles)
- Suitable when performance is critical

**Hybrid:**
- Partial unrolling (e.g., 4 rounds at a time)
- Balance between resources and performance

#### 3. Clocking Strategy

**Target Clock Frequency:**
- Conservative: 50 MHz (use on-board oscillator)
- Moderate: 100 MHz (use PLL from 74.25 MHz source)
- Aggressive: 150+ MHz (requires careful timing closure)

**PLL Configuration:**
```verilog
// Example: 100 MHz from 74.25 MHz oscillator
input wire clk_in,  // GPIOR_188 connected to 74.25 MHz
output wire clk_100mhz
// Configure PLL block in Interface Designer
```

**Clock Domain Considerations:**
- Keep hash logic in single clock domain
- Use async FIFOs if interfacing with processor

#### 4. Interface Design

**Input/Output Options:**

**Option A: UART Interface**
- Serial data input/output
- Simple testing via terminal
- Lower throughput
- Good for initial validation

**Option B: Memory-Mapped Interface**
- Integrate with RK3399 processor
- Write data to FPGA memory
- Read hash results
- Higher throughput
- Requires bus interface (AXI, etc.)

**Option C: GPIO Parallel Interface**
- Direct GPIO pins for data/control
- Medium complexity
- Good for standalone operation

**Option D: SPI Interface**
- Serial protocol between processor and FPGA
- Moderate throughput
- Efficient pin usage

**Recommendation:** Start with UART (simplest), then migrate to memory-mapped or SPI for performance.

#### 5. HDL Implementation

**Verilog/SystemVerilog:**
```verilog
module sha256_core (
    input wire clk,
    input wire rst_n,
    input wire [511:0] data_in,
    input wire data_valid,
    output reg [255:0] hash_out,
    output reg hash_ready
);
    // State machine: IDLE, PROCESS, DONE
    // Round logic
    // Constants (K values)
    // Compression function
endmodule
```

**Key Components:**
- State machine for control
- Round function implementation
- Constant ROM (K values for SHA-256)
- Message schedule (W array)
- Output register

**SHA-3 Specific:**
- 1600-bit state array (5×5×64 bits)
- Theta, Rho, Pi, Chi, Iota round functions
- Absorption and squeezing phases

#### 6. Verification Strategy

**Simulation:**
```bash
# Use iVerilog for functional verification
iverilog -o outflow/sha256_sim sha256_core.v sha256_tb.v
vvp outflow/sha256_sim
gtkwave outflow/sha256_tb.vcd
```

**Test Vectors:**
Use NIST test vectors:
- SHA-256: https://csrc.nist.gov/projects/cryptographic-algorithm-validation-program
- SHA-3: https://csrc.nist.gov/projects/cryptographic-standards-and-guidelines

**Verification:**
```bash
# Automated test vector verification
python3 testbench/verify_testbench.py
```

**Hardware Testing:**
1. Implement UART interface for input/output
2. Send test vectors via serial terminal
3. Compare output hash with expected results
4. Verify timing and throughput

#### 7. Optimization Techniques

**For Throughput:**
- Pipeline rounds (register insertion between rounds)
- Unroll multiple rounds
- Parallel hash units (multiple instances)

**For Area:**
- Iterative design (reuse round logic)
- Share constants between rounds
- Use blockRAM efficiently

**For Power:**
- Clock gating for unused logic
- Reduce toggle rate on data paths
- Lower clock frequency where possible

#### 8. Integration with Vaaman

**Processor-FPGA Communication:**

**Method 1: Shared Memory**
- Use PCIe or custom bus
- Processor writes data to FPGA memory
- FPGA processes and writes back
- Requires complex interface

**Method 2: SPI Communication**
- Processor acts as SPI master
- FPGA acts as SPI slave
- Exchange data via SPI protocol
- Moderate complexity

**Method 3: UART**
- Simplest integration
- Lower performance
- Good for prototyping

**Example Workflow:**
1. Processor sends data to hash via UART/SPI
2. FPGA computes SHA-256/SHA-3
3. FPGA returns hash value
4. Processor validates or uses hash

### Recommended Implementation Steps

1. **Week 1-2: Basic Infrastructure**
   - Set up Efinity IDE
   - Create test project with LED blink
   - Verify JTAG programming
   - Test clock configuration

2. **Week 3-4: Algorithm Implementation**
   - Implement SHA-256 iterative core
   - Simulate with test vectors
   - Verify functionality in simulation

3. **Week 5-6: Hardware Integration**
   - Add UART interface
   - Synthesize and program FPGA
   - Test on hardware with real data
   - Debug and optimize

4. **Week 7-8: SHA-3 Implementation**
   - Implement SHA-3 (Keccak) core
   - Follow similar verification process
   - Optimize and compare performance

5. **Week 9+: Optimization & Documentation**
   - Pipeline or unroll for performance
   - Measure throughput and resource usage
   - Document design and results

### Reference Implementations

**Open-Source SHA-256:**
- Search GitHub: "SHA256 Verilog" or "SHA256 FPGA"
- Example: secworks/sha256 (https://github.com/secworks/sha256)

**Open-Source SHA-3:**
- Search GitHub: "SHA3 Verilog" or "Keccak FPGA"
- Example: secworks/sha3 (https://github.com/secworks/sha3)

**Adaptation for Efinix:**
- Most open-source cores are vendor-neutral
- May need to adapt constraints for Efinix
- Replace vendor-specific primitives with generic HDL

---

## Troubleshooting

### Common Issues

**Issue: Efinity IDE won't launch**
- Solution: Source setup.sh or run setup.bat
- Solution: Install missing libraries (libxcb* on Ubuntu)

**Issue: JTAG programming fails**
- Solution: Check USB-to-JTAG connection and color-coding
- Solution: Install/update USB drivers (Zadig on Windows)
- Solution: Verify Vaaman is powered on (12V)

**Issue: FPGA not configuring**
- Solution: Check bitstream file is for correct device (T120F324)
- Solution: Verify timing model (C3) matches hardware
- Solution: Check pin constraints don't conflict

**Issue: SPI flash programming fails**
- Solution: Ensure using Vicharak kernel and system image
- Solution: Check flashcp utility is modified version
- Solution: Verify SPI flash isn't locked or corrupted

**Issue: Clock not working**
- Solution: Verify PLL configuration in Interface Designer
- Solution: Check GPIO pin assigned to clock input
- Solution: Confirm oscillator frequency matches design

**Issue: Synthesis fails with resource errors**
- Solution: Simplify design (use iterative instead of pipelined)
- Solution: Check for accidental logic duplication
- Solution: Review resource utilization report

**Issue: Timing closure fails**
- Solution: Reduce target clock frequency
- Solution: Add pipeline registers
- Solution: Review critical paths in timing report
- Solution: Adjust SDC constraints

### Debug Techniques

**LED Debug:**
- Connect internal signals to user LEDs
- Observe state machine transitions
- Verify clock activity

**UART Debug:**
- Output intermediate values via UART
- Monitor state transitions
- Validate data flow

**Simulation:**
- Use GTKWave to inspect waveforms
- Add debug signals to testbench
- Verify against test vectors

**ChipScope/Logic Analyzer:**
- Check if Efinix provides equivalent debug tools
- Capture internal signals during operation
- Trigger on specific conditions

---

## Resources

### Official Documentation
- Vicharak Docs: https://docs.vicharak.in/
- Efinix Support: https://www.efinixinc.com/support/
- Efinity Software: https://www.efinixinc.com/support/efinity.php

### Hardware
- Vaaman Product Page: https://vicharak.in/products/vaaman
- Vaaman Downloads: https://docs.vicharak.in/vicharak_sbcs/vaaman/vaaman-downloads/

### Example Projects
- LED Blinking Demo: https://github.com/vicharak-in/LED_BLINKING_DEMO
- UART RX/TX Demo: https://github.com/vicharak-in/UART_RX_TX_DEMO

### Cryptographic Standards
- NIST FIPS 180-4 (SHA-256): https://csrc.nist.gov/publications/detail/fips/180/4/final
- NIST FIPS 202 (SHA-3): https://csrc.nist.gov/publications/detail/fips/202/final
- Keccak Team: https://keccak.team/

### HDL Resources
- iVerilog: https://github.com/steveicarus/iverilog
- GTKWave: https://sourceforge.net/projects/gtkwave/
- HDL Examples: https://www.asic-world.com/verilog/

### Open-Source Implementations
- secworks/sha256: https://github.com/secworks/sha256
- secworks/sha3: https://github.com/secworks/sha3
- Search "FPGA cryptography" on GitHub for more examples

### Community
- Vicharak GitHub: https://github.com/vicharak-in
- Efinix Forums: Check Efinix website for community links

---

## Quick Reference

### Default Credentials
```
Username: vicharak
Password: 12345
```

### Power Requirements
```
Voltage: 12V DC
Current: 5A
Connector: USB-C with PD cable
WARNING: Do not use 5V power
```

### FPGA Device Selection
```
Device: Trion T120F324
Package: 324-ball FineLine BGA
Timing Model: C3
```

### Programming Commands
```bash
# Command-line programming
sudo vaaman-ctl -i /path/to/bitstream.hex

# SPI flash programming
sudo flashcp /path/to/bitstream.hex
sudo read_from_flash
```

### Clock Frequencies
```
Available: 10, 20, 25, 30, 50, 74.25 MHz
Common PLL Output: 100 MHz
Maximum: Depends on design complexity
```

### Serial Console
```
Baud Rate: 1500000
Pins: GND, TX (pin 8), RX (pin 10)
```

### SSH Access
```bash
ssh vicharak@<IP_address>
# Password: 12345
```

---

## Next Steps

1. **Set up development environment:**
   - Install Efinity IDE
   - Install simulation tools (iVerilog, GTKWave)
   - Test JTAG programming with LED demo

2. **Study example projects:**
   - Clone and build LED blinking demo
   - Clone and build UART demo
   - Understand project structure and workflow

3. **Design SHA-256 core:**
   - Implement iterative SHA-256 in Verilog
   - Create testbench with NIST test vectors
   - Simulate and verify functionality

4. **Integrate with Vaaman:**
   - Add UART interface to SHA-256 core
   - Synthesize and program FPGA
   - Test with real hardware

5. **Implement SHA-3:**
   - Study Keccak algorithm
   - Implement SHA-3 core (iterative)
   - Verify and test on hardware

6. **Optimize for performance:**
   - Pipeline critical paths
   - Increase clock frequency
   - Measure throughput and compare

---

## Contact & Support

For issues or questions:
- Vicharak Support: Check https://vicharak.in for contact information
- GitHub Issues: https://github.com/vicharak-in
- Community Forums: See Vicharak and Efinix websites

---

*Document compiled from Vicharak official documentation (https://docs.vicharak.in/)*
*Last updated: 2026-01-09*
*Target: Programming Vaaman FPGA with SHA3 and SHA256 implementations*
