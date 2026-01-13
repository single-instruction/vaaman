# FPGA Simulation and Testing Guide

## Introduction

This guide covers how to simulate and verify your Verilog designs using iVerilog and GTKWave before programming your FPGA.

**Why Simulate?**
- Find bugs early (before synthesis)
- Verify functionality with test vectors
- Understand timing behavior
- Debug complex logic
- Free and fast (no hardware needed)

---

## Table of Contents

1. [Tools Overview](#tools-overview)
2. [Installing Tools](#installing-tools)
3. [Basic Simulation Workflow](#basic-simulation-workflow)
4. [Running SHA-256 Simulation](#running-sha-256-simulation)
5. [Running SHA-3 Simulation](#running-sha-3-simulation)
6. [Analyzing Waveforms](#analyzing-waveforms)
7. [Writing Testbenches](#writing-testbenches)
8. [Debugging Techniques](#debugging-techniques)
9. [Advanced Topics](#advanced-topics)
10. [Troubleshooting](#troubleshooting)

---

## 1. Tools Overview

### iVerilog (Icarus Verilog)

**What it does**: Compiles and simulates Verilog code

**Features**:
- Open source and free
- Fast compilation
- IEEE 1364 compliant
- Cross-platform (Linux, Windows, Mac)
- Produces VCD (Value Change Dump) files

### GTKWave

**What it does**: Visualizes simulation waveforms

**Features**:
- Open source and free
- Reads VCD files
- Interactive waveform viewer
- Signal searching and filtering
- Measurement tools

---

## 2. Installing Tools

### Linux (Ubuntu/Debian)

```bash
# Update package list
sudo apt-get update

# Install iVerilog
sudo apt-get install iverilog

# Install GTKWave
sudo apt-get install gtkwave

# Verify installation
iverilog -v
gtkwave --version
```

### Windows

#### iVerilog:
1. Download from https://bleyer.org/icarus/
2. Run installer
3. Add to PATH: `C:\iverilog\bin`

#### GTKWave:
1. Download from https://sourceforge.net/projects/gtkwave/files/
2. Extract to folder (e.g., `C:\gtkwave`)
3. Add to PATH: `C:\gtkwave\bin`

### macOS

```bash
# Using Homebrew
brew install icarus-verilog
brew install gtkwave

# Verify
iverilog -v
gtkwave --version
```

---

## 3. Basic Simulation Workflow

### Step-by-Step Process

```
1. Write Design (module.v)
   ↓
2. Write Testbench (module_tb.v)
   ↓
3. Compile with iVerilog
   ↓
4. Run Simulation
   ↓
5. View Waveforms in GTKWave
   ↓
6. Debug and Iterate
```

### Simple Example

**Design: counter.v**
```verilog
module counter (
    input wire clk,
    input wire rst_n,
    output reg [7:0] count
);

always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        count <= 8'd0;
    else
        count <= count + 1;
end

endmodule
```

**Testbench: counter_tb.v**
```verilog
`timescale 1ns / 1ps

module counter_tb;

reg clk;
reg rst_n;
wire [7:0] count;

// Instantiate DUT (Design Under Test)
counter dut (
    .clk(clk),
    .rst_n(rst_n),
    .count(count)
);

// Clock generation: 10ns period (100 MHz)
initial begin
    clk = 0;
    forever #5 clk = ~clk;
end

// VCD dump for waveform viewing
initial begin
    $dumpfile("counter_tb.vcd");
    $dumpvars(0, counter_tb);
end

// Test stimulus
initial begin
    $display("Starting counter test...");

    // Reset
    rst_n = 0;
    #100;
    rst_n = 1;

    // Run for 1000ns
    #1000;

    // Check result
    if (count == 8'd100)
        $display("PASS: Counter reached 100");
    else
        $display("FAIL: Counter is %d", count);

    $finish;
end

endmodule
```

**Compile and Run:**
```bash
# Compile
iverilog -o outflow/counter_sim counter.v counter_tb.v

# Run simulation
vvp outflow/counter_sim

# View waveforms
gtkwave outflow/counter_tb.vcd
```

---

## 4. Running SHA-256 Simulation

### Navigate to Project

```bash
cd /home/zyzyzynn/dev/vaaman
```

### Compile SHA-256

```bash
# Compile design and testbench
iverilog -o outflow/sha256_sim rtl/sha256_core.v testbench/sha256_tb.v

# Check for compilation errors
# If successful, no output means compilation passed
```

### Run Simulation

```bash
# Execute simulation
vvp outflow/sha256_sim
```

**Expected Output:**
```
========================================
SHA-256 Core Testbench
========================================

Test 1: Empty string
[PASS] Test 1: Hash matches expected value

Test 2: 'abc'
[PASS] Test 2: Hash matches expected value

Test 3: 'abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq'
[PASS] Test 3: Hash matches expected value

Test 4: Block of zeros with length 0
[PASS] Test 4: Hash matches expected value

Test 5: 'The quick brown fox jumps over the lazy dog'
[PASS] Test 5: Hash matches expected value

Test 6: Back-to-back 'abc' hashes
[PASS] Test 6: Hash matches expected value
[PASS] Test 7: Hash matches expected value

========================================
Test Summary
========================================
Total Tests: 7
Passed:      7
Failed:      0

*** ALL TESTS PASSED! ***

========================================
```

### View Waveforms

```bash
# Open GTKWave
gtkwave outflow/sha256_tb.vcd
```

In GTKWave:
1. Expand `sha256_tb` in left panel
2. Expand `dut` (Design Under Test)
3. Select signals: `clk`, `rst_n`, `start`, `ready`, `state`, `hash_out`
4. Click "Append" or drag to waveform viewer
5. Use zoom buttons to see details

---

## 5. Running SHA-3 Simulation

### Compile SHA-3

```bash
iverilog -o outflow/sha3_sim rtl/sha3_core.v testbench/sha3_tb.v
```

### Run Simulation

```bash
vvp outflow/sha3_sim
```

**Expected Output:**
```
========================================
SHA-3-256 Core Testbench
========================================

Test 1: Empty string
[PASS] Test 1: Hash matches expected value

Test 2: 'abc'
[PASS] Test 2: Hash matches expected value

... (more tests) ...

========================================
Test Summary
========================================
Total Tests: 7
Passed:      7
Failed:      0

*** ALL TESTS PASSED! ***

========================================
```

### View Waveforms

```bash
gtkwave outflow/sha3_tb.vcd
```

---

## 6. Analyzing Waveforms

### GTKWave Interface

```
┌─────────────────────────────────────────────────────┐
│ File  Edit  Search  Time  Markers  View  Help       │
├─────────────┬───────────────────────────────────────┤
│             │                                       │
│  Signal     │      Waveform Viewer                 │
│  Tree       │                                       │
│             │  clk   _|‾|_|‾|_|‾|_|‾|_             │
│ ○ sha256_tb │  rst_n _____|‾‾‾‾‾‾‾‾‾‾‾             │
│   ○ dut     │  start ______|‾|_______|‾|_          │
│     - clk   │  ready ‾‾‾‾‾‾|_______|‾‾‾‾           │
│     - rst_n │  state IDLE--LOAD-PREP-PROC-DONE     │
│     - start │                                       │
│     - ready │                                       │
│     - state │                                       │
│             │                                       │
├─────────────┴───────────────────────────────────────┤
│ Time cursor: 1.234 μs   Δt: 500 ns                 │
└─────────────────────────────────────────────────────┘
```

### Adding Signals

**Method 1: Click and Append**
1. Select signal in tree
2. Click "Append" button
3. Signal appears in waveform

**Method 2: Drag and Drop**
1. Drag signal from tree
2. Drop in waveform area

**Method 3: Search**
1. Edit → Search for Signal
2. Type signal name (e.g., "hash_out")
3. Click "Append"

### Signal Display Formats

Right-click signal → Data Format:

- **Binary**: See individual bits
- **Hexadecimal**: Compact for large buses
- **Decimal**: Human-readable numbers
- **ASCII**: For text data
- **Analog**: Smooth line graph

### Useful Operations

**Zoom:**
- Zoom In: `Alt + Scroll Up` or click magnifying glass
- Zoom Out: `Alt + Scroll Down`
- Zoom Fit: Click "Zoom Fit" button
- Zoom to Selection: Select region, click "Zoom to Selection"

**Markers:**
- Primary Marker: Click on waveform
- Secondary Marker: `Shift + Click`
- Measure Time: Δt shown in status bar

**Signal Groups:**
- Right-click signals → Insert Blank
- Right-click → Insert Comment → Name the group
- Organize related signals together

---

## 7. Writing Testbenches

### Testbench Structure

```verilog
`timescale 1ns / 1ps  // Time unit / Time precision

module module_name_tb;

    // 1. Declare signals
    reg input_signals;
    wire output_signals;

    // 2. Instantiate DUT
    module_name dut (
        .port1(signal1),
        .port2(signal2)
    );

    // 3. Clock generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk;  // 10ns period
    end

    // 4. VCD dump
    initial begin
        $dumpfile("module_name_tb.vcd");
        $dumpvars(0, module_name_tb);
    end

    // 5. Test stimulus
    initial begin
        // Initialize
        // Apply inputs
        // Check outputs
        $finish;
    end

endmodule
```

### System Tasks for Testbenches

```verilog
$display("Message: %d", value);      // Print to console
$monitor("sig=%b", signal);          // Auto-print on change
$time                                 // Current simulation time
$finish                              // End simulation
$stop                                // Pause simulation
$dumpfile("file.vcd")                // Set VCD filename
$dumpvars(0, module)                 // Dump all variables
```

### Format Specifiers

```verilog
%b  // Binary
%d  // Decimal
%h  // Hexadecimal
%o  // Octal
%t  // Time
%s  // String
```

### Delays and Timing

```verilog
#10         // Wait 10 time units
#10.5       // Wait 10.5 time units
@(posedge clk)       // Wait for rising edge
@(negedge rst_n)     // Wait for falling edge
@(signal)            // Wait for any change

wait (condition)     // Wait until condition true
```

### Example: Memory Test

```verilog
module memory_tb;

reg clk, rst_n, write_en;
reg [7:0] addr, data_in;
wire [7:0] data_out;

memory dut (
    .clk(clk),
    .rst_n(rst_n),
    .addr(addr),
    .data_in(data_in),
    .write_en(write_en),
    .data_out(data_out)
);

// Clock
initial begin
    clk = 0;
    forever #5 clk = ~clk;
end

// VCD
initial begin
    $dumpfile("memory_tb.vcd");
    $dumpvars(0, memory_tb);
end

// Test
initial begin
    // Reset
    rst_n = 0;
    write_en = 0;
    addr = 8'd0;
    data_in = 8'd0;
    #100;
    rst_n = 1;

    // Write test
    @(posedge clk);
    addr = 8'd10;
    data_in = 8'hAB;
    write_en = 1;
    @(posedge clk);
    write_en = 0;

    // Read test
    @(posedge clk);
    addr = 8'd10;
    @(posedge clk);
    @(posedge clk);

    if (data_out == 8'hAB)
        $display("PASS: Memory read correct");
    else
        $display("FAIL: Expected AB, got %h", data_out);

    #100;
    $finish;
end

endmodule
```

---

## 8. Debugging Techniques

### Using $display

```verilog
always @(posedge clk) begin
    if (state == PROCESS)
        $display("Round %d: a=%h e=%h", round, a, e);
end
```

### Conditional Breakpoints

```verilog
always @(*) begin
    if (hash_out == 256'h0) begin
        $display("WARNING: Zero hash at time %t", $time);
    end
end
```

### Waveform Analysis Checklist

**For SHA-256:**
1. ✓ Clock toggles regularly
2. ✓ Reset properly initializes state
3. ✓ `start` pulse triggers transition from IDLE
4. ✓ State progresses: IDLE → LOAD → PREPARE → PROCESS → DONE
5. ✓ `round_counter` increments 0-63 in PROCESS
6. ✓ `ready` deasserts during operation
7. ✓ `hash_out` matches expected value at end

**For SHA-3:**
1. ✓ State array XORs with input in ABSORB
2. ✓ 24 rounds execute in PERMUTE
3. ✓ `round_counter` increments 0-23
4. ✓ Output extracted in SQUEEZE

### Common Issues and Checks

| Problem | Check |
|---------|-------|
| Hash always zero | Inputs being applied? State machine running? |
| Simulation hangs | Timeout watchdog present? Infinite loop in FSM? |
| X (unknown) values | Uninitialized registers? Missing reset? |
| Wrong hash | Endianness? Test vector correct? Algorithm bug? |

---

## 9. Advanced Topics

### Test Vectors from Files

```verilog
reg [255:0] test_vectors [0:99];  // Array of test vectors
integer i;

initial begin
    $readmemh("test_vectors.hex", test_vectors);

    for (i = 0; i < 100; i = i + 1) begin
        // Apply test_vectors[i]
        // Check result
    end
end
```

### Self-Checking Testbenches

```verilog
task check_hash;
    input [255:0] expected;
    begin
        if (hash_out == expected) begin
            $display("✓ PASS");
            pass_count = pass_count + 1;
        end else begin
            $display("✗ FAIL: Expected %h, Got %h", expected, hash_out);
            fail_count = fail_count + 1;
        end
    end
endtask
```

### Code Coverage

```bash
# Compile with coverage
iverilog -g2009 -o sim design.v testbench.v

# Run
vvp sim

# Generate coverage report (if tool supports)
# Check which lines were executed
```

### Performance Measurement

```verilog
integer start_time, end_time, cycles;

initial begin
    wait(ready);
    start_time = $time;

    // Start operation
    start = 1;
    @(posedge clk);
    start = 0;

    wait(ready);
    end_time = $time;

    cycles = (end_time - start_time) / 10;  // Assuming 10ns clock
    $display("Operation took %d cycles", cycles);
end
```

---

## 10. Troubleshooting

### Compilation Errors

**Error: Undeclared identifier**
```
solution: Check spelling, declare variable before use
```

**Error: Port connection mismatch**
```
solution: Ensure DUT ports match instantiation
```

**Error: Syntax error**
```
solution: Missing semicolon, begin/end mismatch, check line number
```

### Simulation Errors

**Error: Too many errors**
```
solution: Fix first error, often cascades
```

**Warning: Assigned to 'x'**
```
solution: Initialize all registers in reset
```

**Error: $finish without $dumpfile**
```
solution: Add $dumpfile() before $dumpvars()
```

### Waveform Issues

**Problem: No VCD file generated**
```
solution: Check $dumpfile() and $dumpvars() are called
```

**Problem: GTKWave shows no signals**
```
solution: Load VCD file first, then append signals
```

**Problem: Can't find signal**
```
solution: Check hierarchy, signal might be in submodule
```

### Getting Help

**Check iVerilog manual:**
```bash
man iverilog
```

**Verbose compilation:**
```bash
iverilog -v -o sim design.v testbench.v
```

**GTKWave help:**
```
Help → Wave Navigator
Help → Manual
```

---

## Quick Reference

### Common Commands

```bash
# Compile
iverilog -o outflow/output_file design.v testbench.v

# Run simulation
vvp outflow/output_file

# View waveforms
gtkwave outflow/waveform.vcd

# Compile with warnings
iverilog -Wall -o outflow/sim design.v testbench.v

# List all modules
iverilog -M design.v
```

### Keyboard Shortcuts (GTKWave)

```
Ctrl+O      Open VCD file
Ctrl+F      Search for signal
Ctrl+G      Go to time
Alt+F       Zoom fit
Alt+S       Zoom to selection
+/-         Zoom in/out
←/→         Pan left/right
Ctrl+Z      Undo
```

---

## Practice Exercises

### Exercise 1: Test SHA-256 with Your Own Vector

1. Find online SHA-256 calculator
2. Hash your name
3. Add test case to `sha256_tb.v`
4. Simulate and verify

### Exercise 2: Add Timing Measurements

Modify `sha256_tb.v` to measure:
- Cycles per hash
- Throughput (bits/cycle)
- Print statistics

### Exercise 3: Create Minimal Testbench

Write a testbench that:
- Tests only "abc" input
- Prints only PASS/FAIL
- Under 30 lines of code

### Exercise 4: Visualize State Transitions

1. Run SHA-256 simulation
2. In GTKWave, find `state` signal
3. Change to Analog display
4. Observe state progression
5. Take screenshot

---

## Summary

You now know how to:
- ✓ Install iVerilog and GTKWave
- ✓ Compile Verilog designs
- ✓ Run simulations
- ✓ View and analyze waveforms
- ✓ Write testbenches
- ✓ Debug designs
- ✓ Verify SHA-256 and SHA-3 implementations

**Next Steps:**
1. Simulate the provided SHA implementations
2. Experiment with different test vectors
3. Modify code and observe effects
4. When board arrives, synthesize in Efinity IDE

**Remember**: Simulation is your friend! Always simulate before synthesizing. It's faster, free, and catches bugs early.

Happy simulating!
