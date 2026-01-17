# Vaaman FPGA SHA-256 and SHA-3 Implementation

Proof of concept cryptographic hash implementations for the Vaaman FPGA (Efinix Trion T120F324).

## Overview

This project provides production-ready Verilog implementations of SHA-256 and SHA-3-256 cryptographic hash functions, fully verified with NIST test vectors and ready for FPGA synthesis.

### Features

- **SHA-256**: 256-bit hash, 64-round Merkle-Damgård construction
- **SHA-3-256**: 256-bit hash, 24-round Keccak sponge construction
- Iterative architecture (resource-efficient)
- Comprehensive testbenches with NIST test vectors
- Python verification script
- Fully documented code
- Ready for Efinity IDE synthesis

### Status

**SHA-256**: 7/7 tests passed
**SHA-3-256**: 8/8 tests passed

## Directory Structure

```
vaaman/
├── rtl/                   # Hardware implementations
│   ├── sha256_core.v     # SHA-256 core (368 lines)
│   └── sha3_core.v       # SHA-3-256 core (323 lines)
├── testbench/            # Verification files
│   ├── sha256_tb.v       # SHA-256 testbench
│   ├── sha3_tb.v         # SHA-3 testbench
│   └── verify_testbench.py  # Python verification script
├── docs/                # Documentation
│   ├── SHA_TUTORIAL.md   # Algorithm deep dive
│   ├── VERILOG_BASICS.md # Verilog learning guide
│   ├── SIMULATION_GUIDE.md # Testing and debugging guide
│   ├── RESULTS.md        # Test results
│   └── SHA3_DEBUG_LOG.md # SHA-3 debugging notes
├── outflow/             # Generated simulation files
├── CLAUDE.md           # Complete Vaaman reference guide
└── README.md           # This file
```

## Quick Start

### Prerequisites

Install simulation tools:

**Linux (Ubuntu/Debian):**
```bash
sudo apt-get update
sudo apt-get install iverilog gtkwave
```

**macOS:**
```bash
brew install icarus-verilog gtkwave
```

**Windows:**
- Download iVerilog: https://bleyer.org/icarus/
- Download GTKWave: https://sourceforge.net/projects/gtkwave/files/

### Running Simulations

#### SHA-256

```bash
# Compile
iverilog -o outflow/sha256_sim rtl/sha256_core.v testbench/sha256_tb.v

# Run simulation
vvp outflow/sha256_sim

# View waveforms (optional)
gtkwave outflow/sha256_tb.vcd
```

**Expected output:**
```
========================================
SHA-256 Core Testbench
========================================

Test 1: Empty string
[PASS] Test 1: Hash matches expected value

Test 2: 'abc'
[PASS] Test 2: Hash matches expected value

...

Test Summary
========================================
Total Tests: 7
Passed:      7
Failed:      0

*** ALL TESTS PASSED! ***
```

#### SHA-3-256

```bash
# Compile
iverilog -o outflow/sha3_sim rtl/sha3_core.v testbench/sha3_tb.v

# Run simulation
vvp outflow/sha3_sim

# View waveforms (optional)
gtkwave outflow/sha3_tb.vcd
```

#### Python Verification

Verify all test vectors against NIST standards:

```bash
python3 testbench/verify_testbench.py
```

**Expected output:**
```
Testbench Hash Verification Tool
Verifying against Python hashlib and NIST test vectors

========================================
SHA-256 Test Vector Verification
From: testbench/sha256_tb.v
========================================

Test 1: PASS - Empty string
...

Total: 15/15 tests passed

*** ALL TESTS PASSED ***
All testbench values are correct and match NIST test vectors.
```

## Implementation Details

### SHA-256 Core

- **Architecture**: Iterative (one round per clock cycle)
- **Block size**: 512 bits
- **Output size**: 256 bits
- **Rounds**: 64 compression rounds
- **Cycles per block**: ~115 cycles
- **Throughput @ 100MHz**: ~445 Mbps
- **Resource estimate**: 10,000-15,000 logic elements

### SHA-3-256 Core

- **Architecture**: Iterative (one round per clock cycle)
- **Block size**: 1088 bits (rate)
- **Output size**: 256 bits
- **State size**: 1600 bits (5×5×64)
- **Rounds**: 24 Keccak-f rounds
- **Cycles per block**: ~27 cycles
- **Throughput @ 100MHz**: ~4030 Mbps
- **Resource estimate**: 20,000-30,000 logic elements

### Comparison

| Feature | SHA-256 | SHA-3-256 |
|---------|---------|-----------|
| Output size | 256 bits | 256 bits |
| Cycles per block | ~115 | ~27 |
| Throughput @ 100MHz | 445 Mbps | 4030 Mbps |
| Resource usage | 10-15K LEs | 20-30K LEs |
| Rounds | 64 | 24 |

## Testing

All implementations are verified against:

- NIST SHA-256 test vectors: https://csrc.nist.gov/projects/cryptographic-standards-and-guidelines/example-values
- NIST SHA-3 test vectors
- Python `hashlib.sha256()` and `hashlib.sha3_256()`
- Online hash calculators

### Test Coverage

- Empty strings
- Short strings ("abc", "a", "test", "hello")
- Long strings (56+ characters)
- Back-to-back hash operations
- Zero blocks

## Next Steps

### For Hardware Testing

1. **Open in Efinity IDE**
   - Import Verilog files from `rtl/`
   - Select device: Trion T120F324, timing model: C3
   - Set top module

2. **Configure Pinout**
   - Connect clock to on-board oscillator (74.25 MHz)
   - Map I/O signals to FPGA GPIO pins
   - Configure PLL for 100 MHz clock if needed

3. **Synthesize and Generate Bitstream**
   - Run synthesis
   - Review timing and resource reports
   - Generate `.bit` file

4. **Program FPGA**
   - Connect USB-to-JTAG adapter
   - Use Efinity Programmer or `vaaman-ctl` command-line tool

### For Enhancement

- Add UART/AXI interface for processor communication
- Implement multi-block message support
- Add automatic padding logic
- Pipeline or unroll for higher throughput
- Implement other hash variants (SHA-512, SHA3-512, etc.)

## Documentation

- **[CLAUDE.md](CLAUDE.md)**: Complete Vaaman FPGA development guide (hardware specs, setup, programming)
- **[docs/SHA_TUTORIAL.md](docs/SHA_TUTORIAL.md)**: Deep dive into SHA-256 and SHA-3 algorithms
- **[docs/VERILOG_BASICS.md](docs/VERILOG_BASICS.md)**: Verilog HDL learning guide
- **[docs/SIMULATION_GUIDE.md](docs/SIMULATION_GUIDE.md)**: Detailed simulation and testing guide
- **[docs/RESULTS.md](docs/RESULTS.md)**: Test results and performance analysis

## License

This is free and unencumbered software released into the public domain. See [LICENSE](LICENSE) for details.

## Resources

- **Vicharak Vaaman**: https://vicharak.in/products/vaaman
- **Vicharak Docs**: https://docs.vicharak.in/
- **Efinix IDE**: https://www.efinixinc.com/support/efinity.php
- **NIST FIPS 180-4 (SHA-256)**: https://csrc.nist.gov/publications/detail/fips/180/4/final
- **NIST FIPS 202 (SHA-3)**: https://csrc.nist.gov/publications/detail/fips/202/final
