# Complete SHA-256 and SHA-3 FPGA Implementation Tutorial

## Table of Contents
1. [Introduction to Cryptographic Hashing](#introduction-to-cryptographic-hashing)
2. [SHA-256 Algorithm Deep Dive](#sha-256-algorithm-deep-dive)
3. [SHA-3 (Keccak) Algorithm Deep Dive](#sha-3-keccak-algorithm-deep-dive)
4. [Verilog HDL Basics](#verilog-hdl-basics)
5. [FPGA Design Considerations](#fpga-design-considerations)
6. [Implementation Strategy](#implementation-strategy)
7. [Step-by-Step Implementation](#step-by-step-implementation)
8. [Simulation and Verification](#simulation-and-verification)
9. [Optimization Techniques](#optimization-techniques)
10. [Common Pitfalls](#common-pitfalls)

---

## 1. Introduction to Cryptographic Hashing

### What is a Hash Function?

A cryptographic hash function takes an input of arbitrary length and produces a fixed-size output (digest/hash) with these properties:

1. **Deterministic**: Same input always produces same output
2. **Fast to Compute**: Efficient calculation
3. **One-Way**: Computationally infeasible to reverse
4. **Avalanche Effect**: Small input change drastically changes output
5. **Collision Resistant**: Hard to find two inputs with same hash

### Why Implement in FPGA?

**Advantages:**
- **Parallel Processing**: Hardware naturally parallel
- **High Throughput**: Process multiple hashes simultaneously
- **Low Latency**: Dedicated hardware faster than software
- **Energy Efficient**: More computations per watt than CPU
- **Customizable**: Tailor design for specific use cases

**Applications:**
- Cryptocurrency mining
- Network security appliances
- High-speed data integrity checking
- Secure boot systems
- Digital signatures

---

## 2. SHA-256 Algorithm Deep Dive

### Overview

SHA-256 (Secure Hash Algorithm 256-bit) is part of the SHA-2 family, designed by the NSA and published by NIST in 2001.

**Specifications:**
- Input: Any length (padded to multiple of 512 bits)
- Output: 256-bit hash
- Processing: 512-bit blocks
- Rounds: 64 rounds per block
- Based on: Merkle-Damgård construction

### Algorithm Structure

```
Input Message
    ↓
Padding & Length Encoding
    ↓
Split into 512-bit Blocks
    ↓
For Each Block:
    ↓
    Message Schedule (64 words)
    ↓
    64 Compression Rounds
    ↓
    Add to Hash Values
    ↓
Final 256-bit Hash
```

### Step 1: Message Padding

**Goal**: Make message length a multiple of 512 bits

**Process:**
1. Append bit '1' to message
2. Append '0' bits until length ≡ 448 (mod 512)
3. Append 64-bit big-endian message length

**Example:**
```
Original: "abc" (24 bits)
Hex: 0x61 62 63

After padding:
0x61626380 00000000 00000000 00000000
0x00000000 00000000 00000000 00000000
0x00000000 00000000 00000000 00000000
0x00000000 00000000 00000000 00000018
         ↑                           ↑
      '1' bit               Length = 24 bits
```

### Step 2: Initialize Hash Values

Eight 32-bit words (first 32 bits of fractional parts of square roots of first 8 primes):

```verilog
H[0] = 0x6a09e667
H[1] = 0xbb67ae85
H[2] = 0x3c6ef372
H[3] = 0xa54ff53a
H[4] = 0x510e527f
H[5] = 0x9b05688c
H[6] = 0x1f83d9ab
H[7] = 0x5be0cd19
```

### Step 3: Message Schedule

Expand 512-bit block into 64 32-bit words (W[0] to W[63]):

**First 16 words**: Direct from message block
```verilog
W[0..15] = Message_Block[0..15]
```

**Remaining 48 words**: Computed using:
```verilog
W[t] = σ₁(W[t-2]) + W[t-7] + σ₀(W[t-15]) + W[t-16]
```

**Where:**
```verilog
σ₀(x) = ROTR(x,7) ⊕ ROTR(x,18) ⊕ SHR(x,3)
σ₁(x) = ROTR(x,17) ⊕ ROTR(x,19) ⊕ SHR(x,10)

ROTR(x,n) = Rotate right by n bits
SHR(x,n) = Shift right by n bits (logical)
⊕ = XOR operation
```

### Step 4: Compression Function (64 Rounds)

**Initialize working variables:**
```verilog
a = H[0]
b = H[1]
c = H[2]
d = H[3]
e = H[4]
f = H[5]
g = H[6]
h = H[7]
```

**For each round t (0 to 63):**
```verilog
T₁ = h + Σ₁(e) + Ch(e,f,g) + K[t] + W[t]
T₂ = Σ₀(a) + Maj(a,b,c)
h = g
g = f
f = e
e = d + T₁
d = c
c = b
b = a
a = T₁ + T₂
```

**Functions:**
```verilog
Ch(x,y,z)  = (x & y) ⊕ (~x & z)      // Choose
Maj(x,y,z) = (x & y) ⊕ (x & z) ⊕ (y & z)  // Majority

Σ₀(x) = ROTR(x,2) ⊕ ROTR(x,13) ⊕ ROTR(x,22)
Σ₁(x) = ROTR(x,6) ⊕ ROTR(x,11) ⊕ ROTR(x,25)
```

**Round Constants K[0..63]:**
First 32 bits of fractional parts of cube roots of first 64 primes:
```verilog
K[0] = 0x428a2f98, K[1] = 0x71374491, K[2] = 0xb5c0fbcf, ...
(See full table in implementation)
```

### Step 5: Update Hash Values

After 64 rounds:
```verilog
H[0] = H[0] + a
H[1] = H[1] + b
H[2] = H[2] + c
H[3] = H[3] + d
H[4] = H[4] + e
H[5] = H[5] + f
H[6] = H[6] + g
H[7] = H[7] + h
```

### Step 6: Output

Final hash = H[0] || H[1] || H[2] || H[3] || H[4] || H[5] || H[6] || H[7]
(|| means concatenation)

### Example: "abc"

```
Input: "abc"
Padded: 0x61626380 00000000 ... 00000018

Final Hash:
ba7816bf 8f01cfea 414140de 5dae2223
b00361a3 96177a9c b410ff61 f20015ad
```

---

## 3. SHA-3 (Keccak) Algorithm Deep Dive

### Overview

SHA-3 is based on Keccak, selected through NIST competition (2007-2012). Different structure than SHA-2.

**Specifications:**
- Input: Any length
- Output: Variable (224, 256, 384, 512 bits)
- Processing: Sponge construction
- State: 1600 bits (5×5×64)
- Rounds: 24 rounds

### Algorithm Structure

```
                SPONGE CONSTRUCTION
┌─────────────────────────────────────────────┐
│  Absorbing Phase  │  Squeezing Phase        │
│                   │                         │
│  Input → XOR      │  Output ← Extract       │
│     ↓             │     ↑                   │
│  Keccak-f         │  Keccak-f              │
│     ↓             │     ↑                   │
│  (repeat)         │  (repeat)               │
└─────────────────────────────────────────────┘
```

### State Representation

**1600-bit state as 3D array:**
```
A[5][5][64]  // 5×5 lanes, each 64 bits

Indexing:
A[x][y][z] where:
  x, y ∈ {0,1,2,3,4}  (coordinates in 5×5 grid)
  z ∈ {0..63}          (bit position in lane)
```

**Visualization:**
```
     y=0  y=1  y=2  y=3  y=4
x=0 [ 64][ 64][ 64][ 64][ 64]
x=1 [ 64][ 64][ 64][ 64][ 64]
x=2 [ 64][ 64][ 64][ 64][ 64]
x=3 [ 64][ 64][ 64][ 64][ 64]
x=4 [ 64][ 64][ 64][ 64][ 64]

Each cell is a 64-bit lane
Total: 5×5×64 = 1600 bits
```

### Parameters for SHA-3-256

```
Capacity (c) = 512 bits  // Security parameter
Rate (r) = 1088 bits     // Input/output block size
c + r = 1600 bits        // State size
```

### Keccak-f[1600] Permutation

**24 rounds, each consisting of 5 steps:**

#### Step 1: θ (Theta) - Parity Mixing

```verilog
// Compute parity
for x in 0..4:
    C[x] = A[x][0] ⊕ A[x][1] ⊕ A[x][2] ⊕ A[x][3] ⊕ A[x][4]

// Compute D
for x in 0..4:
    D[x] = C[(x-1) mod 5] ⊕ ROT(C[(x+1) mod 5], 1)

// Update state
for x in 0..4, y in 0..4:
    A[x][y] = A[x][y] ⊕ D[x]
```

**Purpose**: Diffuse bits across columns

#### Step 2: ρ (Rho) - Rotation

```verilog
// Each lane rotated by fixed offset
A[x][y] = ROT(A[x][y], r[x][y])
```

**Rotation offsets table:**
```
r[x][y] = [ 0,  1, 62, 28, 27]
          [36, 44,  6, 55, 20]
          [ 3, 10, 43, 25, 39]
          [41, 45, 15, 21,  8]
          [18,  2, 61, 56, 14]
```

**Purpose**: Rotate bits within lanes

#### Step 3: π (Pi) - Permutation

```verilog
// Rearrange lane positions
B[y][(2*x + 3*y) mod 5] = A[x][y]
```

**Purpose**: Shuffle lane positions

#### Step 4: χ (Chi) - Non-linear Mixing

```verilog
for x in 0..4, y in 0..4:
    A[x][y] = B[x][y] ⊕ ((~B[(x+1) mod 5][y]) & B[(x+2) mod 5][y])
```

**Purpose**: Provide non-linearity (only non-linear step)

#### Step 5: ι (Iota) - Round Constant

```verilog
A[0][0] = A[0][0] ⊕ RC[round]
```

**Round constants (24 values):**
```verilog
RC[0]  = 0x0000000000000001
RC[1]  = 0x0000000000008082
RC[2]  = 0x800000000000808A
...
RC[23] = 0x8000000000008008
```

**Purpose**: Break symmetry between rounds

### Complete SHA-3-256 Process

#### 1. Padding

**SHA-3 uses different padding than SHA-2:**

```
Message || 0x06 || 0x00...00 || 0x80
           ↑                    ↑
        delimiter         end marker
```

Pad to multiple of rate (1088 bits for SHA-3-256)

#### 2. Initialize State

```verilog
A[x][y] = 0  for all x,y
```

#### 3. Absorbing Phase

```verilog
for each r-bit block M:
    A = A ⊕ (M || 0^c)  // XOR block into first r bits
    A = Keccak-f[1600](A)  // Apply 24-round permutation
```

#### 4. Squeezing Phase

```verilog
Extract first r bits of A
If more output needed:
    A = Keccak-f[1600](A)
    Extract more bits
```

For SHA-3-256, extract first 256 bits only.

### Example: "abc"

```
Input: "abc"
SHA-3-256 Output:
3a985da74fe225b2045c172d6bd390bd855f086e3e9d525b46bfe24511431532
```

---

## 4. Verilog HDL Basics

### What is Verilog?

Verilog is a **Hardware Description Language** (HDL), not a programming language. It describes **hardware circuits**, not sequential instructions.

**Key Concept**: Verilog describes parallel hardware that executes simultaneously, not sequential code.

### Basic Syntax

#### Module Declaration

```verilog
module module_name (
    input wire clk,           // Clock input
    input wire rst_n,         // Active-low reset
    input wire [31:0] data,   // 32-bit input
    output reg [7:0] result   // 8-bit output register
);

// Module body

endmodule
```

#### Data Types

```verilog
// Wire: Continuous connection (combinational)
wire [7:0] my_wire;

// Reg: Storage element (can be flip-flop or combinational)
reg [31:0] my_reg;

// Parameter: Constant
parameter WIDTH = 32;
```

**Important**: `reg` doesn't always mean flip-flop! It depends on context.

#### Assignments

```verilog
// Continuous assignment (combinational)
assign y = a & b;

// Procedural assignment (in always block)
always @(*) begin
    y = a & b;  // Combinational
end

// Clocked assignment (creates flip-flops)
always @(posedge clk) begin
    y <= a & b;  // Sequential
end
```

#### Always Blocks

**Combinational Logic:**
```verilog
always @(*) begin
    // Use blocking assignments (=)
    sum = a + b;
    result = sum & mask;
end
```

**Sequential Logic (Flip-Flops):**
```verilog
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        counter <= 0;
    end else begin
        // Use non-blocking assignments (<=)
        counter <= counter + 1;
    end
end
```

**Critical Rule**: Use `=` for combinational, `<=` for sequential!

#### Blocking vs Non-Blocking

```verilog
// BLOCKING (=): Executes in order
always @(*) begin
    a = 1;
    b = a;  // b gets 1
end

// NON-BLOCKING (<=): Schedules for end of time step
always @(posedge clk) begin
    a <= 1;
    b <= a;  // b gets OLD value of a
end
```

**When to use:**
- Blocking `=`: Combinational logic (always @(*))
- Non-blocking `<=`: Sequential logic (always @(posedge clk))

#### Operators

```verilog
// Arithmetic
+ - * / %

// Bitwise
& | ^ ~ (AND, OR, XOR, NOT)
~& ~| ~^ (NAND, NOR, XNOR)

// Logical
&& || ! (AND, OR, NOT) - returns 1-bit result

// Shift
<< >> (logical shift)
<<< >>> (arithmetic shift - sign extend)

// Rotate (not built-in, must implement)
// Example: rotate right by n
{data[n-1:0], data[WIDTH-1:n]}

// Reduction
&data (AND all bits)
|data (OR all bits)
^data (XOR all bits - parity)

// Comparison
== != < > <= >=

// Concatenation
{a, b, c}  // Combine signals

// Replication
{4{2'b01}}  // 8'b01010101
```

#### Functions

```verilog
function [31:0] rotate_right;
    input [31:0] value;
    input [4:0] amount;
begin
    rotate_right = {value[amount-1:0], value[31:amount]};
end
endfunction

// Usage
result = rotate_right(data, 5);
```

#### Case Statements

```verilog
always @(*) begin
    case (state)
        IDLE:   next_state = START;
        START:  next_state = PROCESS;
        PROCESS: next_state = DONE;
        default: next_state = IDLE;
    endcase
end
```

### Common Patterns for Cryptography

#### Rotate Right

```verilog
function [31:0] rotr;
    input [31:0] x;
    input [4:0] n;
begin
    rotr = {x[n-1:0], x[31:n]};
end
endfunction
```

#### XOR Multiple Values

```verilog
assign result = a ^ b ^ c ^ d;
```

#### Choice Function (SHA-256)

```verilog
function [31:0] ch;
    input [31:0] x, y, z;
begin
    ch = (x & y) ^ (~x & z);
end
endfunction
```

#### Majority Function (SHA-256)

```verilog
function [31:0] maj;
    input [31:0] x, y, z;
begin
    maj = (x & y) ^ (x & z) ^ (y & z);
end
endfunction
```

---

## 5. FPGA Design Considerations

### Resource Types

**Efinix Trion T120F324 has:**
- Logic Elements (LEs): ~120K
- Memory Blocks: Embedded RAM
- I/O Pins: Configurable
- DSP Blocks: For multiplication (if available)

### Design Tradeoffs

#### Area vs Speed

**Small & Slow (Iterative):**
```verilog
// One round per clock cycle
// Reuse same hardware 64 times
// Low resource usage
// 64+ cycles per block
```

**Large & Fast (Unrolled):**
```verilog
// All 64 rounds in one cycle
// Duplicate hardware 64 times
// High resource usage
// 1 cycle per block (+ pipeline)
```

**Balanced (Partially Unrolled):**
```verilog
// 4 rounds per cycle
// Duplicate hardware 4 times
// 16 cycles per block
```

### Timing Closure

**Critical Path**: Longest combinational delay between flip-flops

**Strategies:**
1. **Pipeline**: Insert registers to break long paths
2. **Reduce Logic Depth**: Simplify expressions
3. **Balance Paths**: Equalize delays
4. **Lower Clock**: Reduce frequency target

### Memory Usage

**Constants (K values, Round constants):**
- Option 1: ROM (uses memory blocks)
- Option 2: Hard-coded logic (uses LEs)

**For small constant arrays**: Hard-code is better

**State Storage:**
- Registers (flip-flops) for working variables
- No external memory needed for single hash

---

## 6. Implementation Strategy

### Architecture Choice: Iterative Design

**Why Iterative?**
1. **Resource Efficient**: Fits easily on T120F324
2. **Easier to Debug**: Simpler state machine
3. **Sufficient Performance**: Thousands of hashes/second
4. **Educational**: Clearer algorithm understanding

### State Machine Design

```
        ┌──────┐
        │ IDLE │◄───────────────┐
        └───┬──┘                │
            │                   │
         [start]                │
            │                   │
            ▼                   │
    ┌──────────────┐            │
    │ LOAD_MESSAGE │            │
    └──────┬───────┘            │
           │                    │
           ▼                    │
  ┌─────────────────┐           │
  │ PREPARE_SCHEDULE│           │
  └────────┬────────┘           │
           │                    │
           ▼                    │
     ┌─────────┐                │
     │ PROCESS │                │
     │(64 rnds)│                │
     └────┬────┘                │
          │                     │
     [round==63]                │
          │                     │
          ▼                     │
      ┌──────┐                  │
      │ DONE │──────────────────┘
      └──────┘
```

### Module Hierarchy

```
top_module
│
├── sha256_core
│   ├── message_schedule
│   ├── compression_round
│   └── control_fsm
│
└── uart_interface (optional)
```

---

## 7. Step-by-Step Implementation

### Phase 1: Create Basic Module Structure

```verilog
module sha256_core (
    input wire clk,
    input wire rst_n,

    // Input interface
    input wire [511:0] message_block,
    input wire start,

    // Output interface
    output reg [255:0] hash_out,
    output reg ready
);

// State machine states
localparam IDLE     = 3'd0;
localparam LOAD     = 3'd1;
localparam PREPARE  = 3'd2;
localparam PROCESS  = 3'd3;
localparam DONE     = 3'd4;

reg [2:0] state;
reg [6:0] round_counter;

// Working variables
reg [31:0] a, b, c, d, e, f, g, h;

// Hash values
reg [31:0] H [0:7];

// Message schedule
reg [31:0] W [0:63];

// ... implementation continues ...

endmodule
```

### Phase 2: Define Constants and Functions

```verilog
// SHA-256 constants (K values)
function [31:0] K;
    input [5:0] t;
begin
    case (t)
        6'd0:  K = 32'h428a2f98;
        6'd1:  K = 32'h71374491;
        6'd2:  K = 32'hb5c0fbcf;
        // ... all 64 values ...
        6'd63: K = 32'hc67178f2;
        default: K = 32'h00000000;
    endcase
end
endfunction

// Rotate right
function [31:0] rotr;
    input [31:0] x;
    input [4:0] n;
begin
    rotr = {x[n-1:0], x[31:n]};
end
endfunction

// Shift right
function [31:0] shr;
    input [31:0] x;
    input [4:0] n;
begin
    shr = x >> n;
end
endfunction

// SHA-256 functions
function [31:0] ch;
    input [31:0] x, y, z;
begin
    ch = (x & y) ^ (~x & z);
end
endfunction

function [31:0] maj;
    input [31:0] x, y, z;
begin
    maj = (x & y) ^ (x & z) ^ (y & z);
end
endfunction

function [31:0] sum0;
    input [31:0] x;
begin
    sum0 = rotr(x, 2) ^ rotr(x, 13) ^ rotr(x, 22);
end
endfunction

function [31:0] sum1;
    input [31:0] x;
begin
    sum1 = rotr(x, 6) ^ rotr(x, 11) ^ rotr(x, 25);
end
endfunction

function [31:0] sigma0;
    input [31:0] x;
begin
    sigma0 = rotr(x, 7) ^ rotr(x, 18) ^ shr(x, 3);
end
endfunction

function [31:0] sigma1;
    input [31:0] x;
begin
    sigma1 = rotr(x, 17) ^ rotr(x, 19) ^ shr(x, 10);
end
endfunction
```

### Phase 3: Implement State Machine

```verilog
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        ready <= 1'b1;
        round_counter <= 7'd0;

        // Initialize hash values
        H[0] <= 32'h6a09e667;
        H[1] <= 32'hbb67ae85;
        H[2] <= 32'h3c6ef372;
        H[3] <= 32'ha54ff53a;
        H[4] <= 32'h510e527f;
        H[5] <= 32'h9b05688c;
        H[6] <= 32'h1f83d9ab;
        H[7] <= 32'h5be0cd19;

    end else begin
        case (state)
            IDLE: begin
                ready <= 1'b1;
                if (start) begin
                    state <= LOAD;
                    ready <= 1'b0;
                end
            end

            LOAD: begin
                // Load message block into W[0..15]
                // (Implementation in next section)
                state <= PREPARE;
            end

            PREPARE: begin
                // Compute W[16..63]
                // (Implementation in next section)
                state <= PROCESS;
                round_counter <= 7'd0;
                // Initialize working variables
                a <= H[0];
                b <= H[1];
                c <= H[2];
                d <= H[3];
                e <= H[4];
                f <= H[5];
                g <= H[6];
                h <= H[7];
            end

            PROCESS: begin
                // One round per clock cycle
                // (Implementation in next section)
                round_counter <= round_counter + 1;
                if (round_counter == 7'd63) begin
                    state <= DONE;
                end
            end

            DONE: begin
                // Update hash values
                H[0] <= H[0] + a;
                H[1] <= H[1] + b;
                H[2] <= H[2] + c;
                H[3] <= H[3] + d;
                H[4] <= H[4] + e;
                H[5] <= H[5] + f;
                H[6] <= H[6] + g;
                H[7] <= H[7] + h;

                // Output final hash
                hash_out <= {H[0], H[1], H[2], H[3],
                           H[4], H[5], H[6], H[7]};

                state <= IDLE;
            end
        endcase
    end
end
```

This is the foundation. I'll create the complete implementations in separate files next.

---

## 8. Simulation and Verification

### Test Vector Strategy

**Use NIST test vectors:**
1. **Empty string** ""
2. **Short messages** "abc", "abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq"
3. **Long messages** Million 'a's

### Simulation Flow

```bash
# Compile design and testbench
iverilog -o sha256_sim sha256_core.v sha256_tb.v

# Run simulation
vvp sha256_sim

# View waveforms
gtkwave sha256_tb.vcd
```

### What to Check

1. **Functional Correctness**: Output matches expected hash
2. **Timing**: Ready signal behavior
3. **State Transitions**: FSM operates correctly
4. **Edge Cases**: Reset behavior, back-to-back operations

---

## 9. Optimization Techniques

### After Basic Implementation Works

1. **Pipeline Stages**: Add registers between rounds
2. **Parallel Message Schedule**: Compute W values in parallel
3. **Unroll Rounds**: Process multiple rounds per cycle
4. **Multiple Cores**: Instantiate multiple hash units

### Performance Metrics

```
Throughput = (Clock Frequency × Block Size) / Cycles per Block

Example (iterative, 100 MHz):
= (100 MHz × 512 bits) / 68 cycles
= 753 Mbps
```

---

## 10. Common Pitfalls

### 1. Endianness Issues

SHA-256 uses **big-endian** byte order. Most systems are little-endian.

```verilog
// Byte swap function
function [31:0] byte_swap;
    input [31:0] x;
begin
    byte_swap = {x[7:0], x[15:8], x[23:16], x[31:24]};
end
endfunction
```

### 2. Blocking vs Non-Blocking

```verilog
// WRONG: Using = in sequential block
always @(posedge clk) begin
    a = b;
    b = a;  // Creates combinational loop!
end

// CORRECT: Use <= for sequential
always @(posedge clk) begin
    a <= b;
    b <= a;  // Swaps values correctly
end
```

### 3. Sensitivity List

```verilog
// WRONG: Incomplete sensitivity list
always @(a) begin
    result = a + b;  // b missing from sensitivity
end

// CORRECT: Use @(*)
always @(*) begin
    result = a + b;
end
```

### 4. Bit Width Mismatches

```verilog
// WRONG: Overflow not considered
reg [7:0] sum;
sum = 8'd200 + 8'd100;  // Result wraps to 44

// CORRECT: Size result appropriately
reg [8:0] sum;
sum = 9'd200 + 9'd100;  // Result is 300
```

### 5. Reset Logic

```verilog
// GOOD: Async reset
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        // Reset logic
    end else begin
        // Normal logic
    end
end
```

### 6. X (Unknown) Values in Simulation

If simulation shows 'X' values:
- Uninitialized registers
- Multiple drivers
- Timing violations

---

## Next Steps

Now that you understand the theory and HDL basics, proceed to:

1. **Study the complete SHA-256 implementation** (sha256_core.v)
2. **Examine the testbench** (sha256_tb.v)
3. **Run simulations** to see it working
4. **Study the SHA-3 implementation** (sha3_core.v)
5. **Modify and experiment** with the code

When your board arrives, you'll:
1. Create project in Efinity IDE
2. Import the verified Verilog files
3. Configure pins and clocks
4. Synthesize and program
5. Test on hardware

---

**Remember**: FPGA design is about describing hardware, not writing software. Think in terms of parallel circuits, not sequential instructions!
