# Verilog HDL Basics for FPGA Programming

## Introduction

This guide teaches Verilog from the ground up, focusing on practical FPGA design for cryptographic implementations.

**Key Principle**: Verilog describes **hardware circuits**, not sequential programs. Think in terms of wires, gates, and flip-flops, not instructions.

---

## Table of Contents

1. [Fundamental Concepts](#fundamental-concepts)
2. [Module Structure](#module-structure)
3. [Data Types](#data-types)
4. [Operators](#operators)
5. [Assignments](#assignments)
6. [Always Blocks](#always-blocks)
7. [Functions and Tasks](#functions-and-tasks)
8. [State Machines](#state-machines)
9. [Common Patterns](#common-patterns)
10. [Best Practices](#best-practices)
11. [Exercises](#exercises)

---

## 1. Fundamental Concepts

### Hardware vs Software Mindset

**Software (C/Python):**
```c
a = 5;
b = a + 3;  // b is now 8
a = 10;     // a changes, b stays 8
```

**Hardware (Verilog):**
```verilog
assign b = a + 3;  // b is ALWAYS a + 3
// When a changes, b changes automatically
// This describes a physical adder circuit
```

### Three Types of Logic

1. **Combinational Logic**: Output depends only on current inputs
   - Gates, adders, multiplexers
   - No memory
   - Instant response (within propagation delay)

2. **Sequential Logic**: Output depends on current input AND past state
   - Flip-flops, registers, counters
   - Has memory
   - Changes on clock edge

3. **Mixed**: Combination of both
   - State machines, controllers
   - Most real designs

### Parallelism

In Verilog, **everything happens at once**!

```verilog
// These execute simultaneously
assign y = a + b;
assign z = c & d;
assign w = e | f;

// NOT one after another like software
```

---

## 2. Module Structure

### Basic Template

```verilog
// Module declaration
module my_module (
    // Port declarations
    input wire clk,              // Clock input
    input wire rst_n,            // Active-low reset
    input wire [7:0] data_in,    // 8-bit input bus
    output reg [15:0] data_out,  // 16-bit output register
    output wire valid            // Control signal
);

    // Internal signals
    reg [7:0] counter;
    wire [7:0] next_counter;

    // Combinational logic
    assign next_counter = counter + 1;
    assign valid = (counter > 8'd100);

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            counter <= 8'd0;
        else
            counter <= next_counter;
    end

    // More logic...

endmodule
```

### Port Directions

```verilog
input      // Signal coming into module
output     // Signal going out of module
inout      // Bidirectional (rare in FPGA)
```

### Port Types

```verilog
wire       // Continuous connection (use for combinational)
reg        // Storage element (use for sequential)
```

**Important**: `reg` doesn't always mean flip-flop! It just means the signal is assigned in an `always` block.

---

## 3. Data Types

### Nets (wire)

```verilog
wire simple_wire;           // 1-bit wire
wire [7:0] bus;             // 8-bit bus [7:0] means MSB=7, LSB=0
wire [0:7] reverse_bus;     // 8-bit bus [0:7] means MSB=0, LSB=7

// Continuous assignment
assign simple_wire = a & b;
```

### Registers (reg)

```verilog
reg flip_flop;              // 1-bit register
reg [31:0] data;            // 32-bit register

// Assigned in always blocks
always @(posedge clk) begin
    flip_flop <= input_signal;
end
```

### Parameters and Localparams

```verilog
parameter WIDTH = 32;       // Can be overridden from outside
localparam STATE_IDLE = 2'b00;  // Cannot be overridden

reg [WIDTH-1:0] data;       // Parameterized width
```

### Number Representation

```verilog
8'd255         // 8-bit decimal: 11111111
8'hFF          // 8-bit hexadecimal: 11111111
8'b11111111    // 8-bit binary: 11111111
8'o377         // 8-bit octal: 11111111

32'd100        // 32-bit decimal: 100
4'b1010        // 4-bit binary: 1010
```

### Bit Selection and Slicing

```verilog
reg [7:0] byte;

byte[0]        // Select bit 0 (LSB)
byte[7]        // Select bit 7 (MSB)
byte[3:0]      // Select bits 3 down to 0 (lower nibble)
byte[7:4]      // Select bits 7 down to 4 (upper nibble)
```

---

## 4. Operators

### Arithmetic

```verilog
a + b          // Addition
a - b          // Subtraction
a * b          // Multiplication
a / b          // Division (avoid in FPGA if possible)
a % b          // Modulus (avoid in FPGA if possible)
```

**Note**: Division and modulus are expensive in hardware. Use power-of-2 when possible.

### Bitwise

```verilog
a & b          // AND
a | b          // OR
a ^ b          // XOR
~a             // NOT
a ~& b         // NAND
a ~| b         // NOR
a ~^ b or a ^~ b   // XNOR
```

### Logical

```verilog
a && b         // Logical AND (returns 1-bit: 1 or 0)
a || b         // Logical OR
!a             // Logical NOT
```

**Difference**:
```verilog
4'b1010 & 4'b1100    // Bitwise: 4'b1000
4'b1010 && 4'b1100   // Logical: 1'b1 (both non-zero)
```

### Comparison

```verilog
a == b         // Equality
a != b         // Inequality
a < b          // Less than
a > b          // Greater than
a <= b         // Less than or equal
a >= b         // Greater than or equal
```

### Shift

```verilog
a << n         // Logical left shift (fill with 0)
a >> n         // Logical right shift (fill with 0)
a <<< n        // Arithmetic left shift (same as <<)
a >>> n        // Arithmetic right shift (sign extend)
```

### Reduction

Operate on all bits of a single operand:

```verilog
&data          // AND all bits (is data all 1s?)
|data          // OR all bits (is data non-zero?)
^data          // XOR all bits (parity check)
```

Example:
```verilog
reg [7:0] byte = 8'b10110101;
wire parity = ^byte;  // 1^0^1^1^0^1^0^1 = 1
```

### Concatenation

```verilog
{a, b, c}      // Concatenate signals
{4{a}}         // Replicate: {a, a, a, a}
{2{2'b01}}     // 4'b0101
```

Example:
```verilog
reg [7:0] byte;
reg [3:0] upper, lower;

byte = {upper, lower};     // Combine nibbles
lower = byte[3:0];         // Extract lower
upper = byte[7:4];         // Extract upper
```

### Conditional (Ternary)

```verilog
condition ? true_value : false_value

// Example
assign result = (selector == 1) ? input_a : input_b;
```

---

## 5. Assignments

### Continuous Assignment (assign)

For **combinational** logic only:

```verilog
assign output = input1 & input2;
assign bus_out = enable ? bus_in : 8'bz;  // Tristate
```

Rules:
- Target must be `wire` type
- Always active (continuous)
- Cannot be in `always` block

### Procedural Assignment

Used in `always` blocks:

#### Blocking (=)

Executes in order, like software:

```verilog
always @(*) begin
    temp = a + b;
    result = temp * c;  // Uses new value of temp
end
```

Use for: **Combinational logic** in `always @(*)`

#### Non-Blocking (<=)

Schedules update for end of time step:

```verilog
always @(posedge clk) begin
    a <= b;
    b <= a;  // Swaps values (uses old value of a)
end
```

Use for: **Sequential logic** in `always @(posedge clk)`

### Golden Rule

```
Combinational always @(*)     → Use =
Sequential always @(posedge)  → Use <=
```

---

## 6. Always Blocks

### Combinational Always Block

```verilog
always @(*) begin  // Sensitive to all inputs (*)
    // Use blocking assignments (=)
    case (opcode)
        2'b00: result = a + b;
        2'b01: result = a - b;
        2'b10: result = a & b;
        2'b11: result = a | b;
    endcase
end
```

**Important**: List all outputs, or use default values to avoid latches!

```verilog
// BAD: Creates latch
always @(*) begin
    if (enable)
        output = input;
    // What if enable is 0? Inferred latch!
end

// GOOD: No latch
always @(*) begin
    if (enable)
        output = input;
    else
        output = previous_value;  // Always assigned
end
```

### Sequential Always Block

```verilog
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        // Asynchronous reset
        counter <= 0;
        state <= IDLE;
    end else begin
        // Synchronous logic
        counter <= counter + 1;
        state <= next_state;
    end
end
```

**Sensitivity list**:
- `posedge clk`: Trigger on rising clock edge
- `negedge clk`: Trigger on falling clock edge
- `negedge rst_n`: Trigger on falling reset (for async reset)

### Multiple Always Blocks

You can have many `always` blocks - they all run in parallel!

```verilog
// Block 1: State register
always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        state <= IDLE;
    else
        state <= next_state;
end

// Block 2: Next state logic
always @(*) begin
    case (state)
        IDLE: next_state = START;
        START: next_state = PROCESS;
        PROCESS: next_state = DONE;
        DONE: next_state = IDLE;
    endcase
end

// Block 3: Output logic
always @(*) begin
    case (state)
        IDLE: output = 8'd0;
        START: output = 8'd1;
        PROCESS: output = 8'd2;
        DONE: output = 8'd3;
    endcase
end
```

---

## 7. Functions and Tasks

### Functions

Pure combinational logic:

```verilog
function [31:0] rotate_right;
    input [31:0] value;
    input [4:0] amount;
begin
    rotate_right = {value[amount-1:0], value[31:amount]};
end
endfunction

// Usage
assign rotated = rotate_right(data, 5'd7);
```

Rules:
- Returns single value
- No timing controls (no @, #)
- Executes in zero simulation time
- Used for combinational logic

### Tasks

Can include timing and multiple outputs:

```verilog
task send_byte;
    input [7:0] data;
    output done;
begin
    // Task body
    uart_tx <= data;
    @(posedge clk);  // Can have timing
    done = 1'b1;
end
endtask

// Usage
send_byte(8'hAB, tx_done);
```

Rules:
- Can have timing controls
- Can have multiple outputs
- Can call other tasks

---

## 8. State Machines

### Finite State Machine (FSM) Template

```verilog
module fsm_example (
    input wire clk,
    input wire rst_n,
    input wire start,
    output reg done
);

    // State encoding
    localparam [1:0] IDLE    = 2'd0;
    localparam [1:0] PROCESS = 2'd1;
    localparam [1:0] FINISH  = 2'd2;

    reg [1:0] state, next_state;

    // State register (sequential)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            state <= IDLE;
        else
            state <= next_state;
    end

    // Next state logic (combinational)
    always @(*) begin
        next_state = state;  // Default: stay in current state
        case (state)
            IDLE: begin
                if (start)
                    next_state = PROCESS;
            end

            PROCESS: begin
                next_state = FINISH;
            end

            FINISH: begin
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

    // Output logic (combinational)
    always @(*) begin
        done = 1'b0;  // Default
        case (state)
            IDLE:    done = 1'b0;
            PROCESS: done = 1'b0;
            FINISH:  done = 1'b1;
            default: done = 1'b0;
        endcase
    end

endmodule
```

### Two Coding Styles

**1. Separate next-state and output logic** (shown above)
- Clearer
- Easier to debug
- Recommended for beginners

**2. Combined** (more compact)
```verilog
always @(*) begin
    // Defaults
    next_state = state;
    done = 1'b0;

    case (state)
        IDLE: begin
            if (start)
                next_state = PROCESS;
        end
        PROCESS: begin
            next_state = FINISH;
        end
        FINISH: begin
            done = 1'b1;
            next_state = IDLE;
        end
    endcase
end
```

---

## 9. Common Patterns

### Counter

```verilog
reg [7:0] counter;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        counter <= 8'd0;
    else if (enable)
        counter <= counter + 1;
end
```

### Shift Register

```verilog
reg [7:0] shift_reg;

always @(posedge clk) begin
    shift_reg <= {shift_reg[6:0], serial_in};  // Shift left, insert LSB
end
```

### Multiplexer

```verilog
// 2-to-1 mux
assign out = sel ? in1 : in0;

// 4-to-1 mux
always @(*) begin
    case (sel)
        2'd0: out = in0;
        2'd1: out = in1;
        2'd2: out = in2;
        2'd3: out = in3;
    endcase
end
```

### Register with Enable

```verilog
always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        data <= 8'd0;
    else if (write_enable)
        data <= data_in;
    // else: hold current value
end
```

### Edge Detection

```verilog
reg signal_prev;
wire rising_edge, falling_edge;

always @(posedge clk) begin
    signal_prev <= signal;
end

assign rising_edge = signal & ~signal_prev;
assign falling_edge = ~signal & signal_prev;
```

### Debouncer (for buttons)

```verilog
reg [15:0] debounce_counter;
reg debounced;

always @(posedge clk) begin
    if (button == debounced) begin
        debounce_counter <= 16'd0;
    end else begin
        debounce_counter <= debounce_counter + 1;
        if (debounce_counter == 16'hFFFF)
            debounced <= button;
    end
end
```

---

## 10. Best Practices

### 1. Use Meaningful Names

```verilog
// BAD
reg [7:0] r1, r2, r3;

// GOOD
reg [7:0] byte_count, checksum, state;
```

### 2. One Module, One File

```verilog
// File: uart_tx.v
module uart_tx (...);
    // ...
endmodule
```

### 3. Avoid Latches

Always assign outputs in all branches:

```verilog
always @(*) begin
    result = 8'd0;  // Default value
    if (condition)
        result = input_a;
    else
        result = input_b;
end
```

### 4. Synchronous Reset Preferred for FPGA

```verilog
always @(posedge clk) begin
    if (!rst_n)  // Synchronous reset
        // reset logic
    else
        // normal logic
end
```

### 5. Don't Mix Blocking and Non-Blocking

```verilog
// BAD
always @(posedge clk) begin
    a <= b;
    c = d;  // Mixed!
end

// GOOD
always @(posedge clk) begin
    a <= b;
    c <= d;
end
```

### 6. Use Parameters for Constants

```verilog
parameter DATA_WIDTH = 32;
parameter ADDR_WIDTH = 10;

reg [DATA_WIDTH-1:0] data;
reg [ADDR_WIDTH-1:0] address;
```

### 7. Comment Complex Logic

```verilog
// Compute SHA-256 Σ₀ function:
// ROTR²(x) ⊕ ROTR¹³(x) ⊕ ROTR²²(x)
assign sum0 = rotr(x, 2) ^ rotr(x, 13) ^ rotr(x, 22);
```

### 8. Avoid X and Z in Synthesizable Code

```verilog
// X (unknown) and Z (high-impedance) are for simulation only
// Don't use in logic that will go to FPGA
```

---

## 11. Exercises

### Exercise 1: LED Blinker

Create a module that blinks an LED at 1 Hz given a 100 MHz clock.

```verilog
module led_blinker (
    input wire clk,       // 100 MHz
    input wire rst_n,
    output reg led
);

// Your code here

endmodule
```

<details>
<summary>Solution</summary>

```verilog
module led_blinker (
    input wire clk,       // 100 MHz
    input wire rst_n,
    output reg led
);

    // 100 MHz / 100,000,000 = 1 Hz
    reg [26:0] counter;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            counter <= 27'd0;
            led <= 1'b0;
        end else begin
            if (counter == 27'd49_999_999) begin
                counter <= 27'd0;
                led <= ~led;  // Toggle
            end else begin
                counter <= counter + 1;
            end
        end
    end

endmodule
```
</details>

### Exercise 2: 8-bit Parity Generator

Create a module that outputs even parity bit for 8-bit input.

```verilog
module parity_gen (
    input wire [7:0] data_in,
    output wire parity_out
);

// Your code here

endmodule
```

<details>
<summary>Solution</summary>

```verilog
module parity_gen (
    input wire [7:0] data_in,
    output wire parity_out
);

    assign parity_out = ^data_in;  // XOR reduction

endmodule
```
</details>

### Exercise 3: Simple State Machine

Create a traffic light controller with states: GREEN(3s) → YELLOW(1s) → RED(3s) → repeat.

```verilog
module traffic_light (
    input wire clk,       // 1 Hz clock
    input wire rst_n,
    output reg [2:0] light  // 3 bits: {red, yellow, green}
);

// Your code here

endmodule
```

<details>
<summary>Solution</summary>

```verilog
module traffic_light (
    input wire clk,       // 1 Hz clock
    input wire rst_n,
    output reg [2:0] light  // {red, yellow, green}
);

    localparam [1:0] GREEN  = 2'd0;
    localparam [1:0] YELLOW = 2'd1;
    localparam [1:0] RED    = 2'd2;

    reg [1:0] state;
    reg [2:0] counter;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= GREEN;
            counter <= 3'd0;
        end else begin
            counter <= counter + 1;

            case (state)
                GREEN: begin
                    light <= 3'b001;  // Green on
                    if (counter == 3'd2) begin
                        state <= YELLOW;
                        counter <= 3'd0;
                    end
                end

                YELLOW: begin
                    light <= 3'b010;  // Yellow on
                    if (counter == 3'd0) begin
                        state <= RED;
                        counter <= 3'd0;
                    end
                end

                RED: begin
                    light <= 3'b100;  // Red on
                    if (counter == 3'd2) begin
                        state <= GREEN;
                        counter <= 3'd0;
                    end
                end

                default: state <= GREEN;
            endcase
        end
    end

endmodule
```
</details>

### Exercise 4: FIFO Buffer

Create a simple 4-deep FIFO (First-In-First-Out) buffer.

```verilog
module fifo #(
    parameter WIDTH = 8,
    parameter DEPTH = 4
)(
    input wire clk,
    input wire rst_n,
    input wire [WIDTH-1:0] data_in,
    input wire write_en,
    input wire read_en,
    output reg [WIDTH-1:0] data_out,
    output wire full,
    output wire empty
);

// Your code here

endmodule
```

<details>
<summary>Solution</summary>

```verilog
module fifo #(
    parameter WIDTH = 8,
    parameter DEPTH = 4
)(
    input wire clk,
    input wire rst_n,
    input wire [WIDTH-1:0] data_in,
    input wire write_en,
    input wire read_en,
    output reg [WIDTH-1:0] data_out,
    output wire full,
    output wire empty
);

    reg [WIDTH-1:0] memory [0:DEPTH-1];
    reg [1:0] write_ptr, read_ptr;
    reg [2:0] count;

    assign full = (count == DEPTH);
    assign empty = (count == 0);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            write_ptr <= 2'd0;
            read_ptr <= 2'd0;
            count <= 3'd0;
            data_out <= {WIDTH{1'b0}};
        end else begin
            // Write
            if (write_en && !full) begin
                memory[write_ptr] <= data_in;
                write_ptr <= write_ptr + 1;
                count <= count + 1;
            end

            // Read
            if (read_en && !empty) begin
                data_out <= memory[read_ptr];
                read_ptr <= read_ptr + 1;
                count <= count - 1;
            end

            // Simultaneous read/write
            if (write_en && read_en && !full && !empty) begin
                count <= count;  // No change
            end
        end
    end

endmodule
```
</details>

---

## Summary

**Key Takeaways**:

1. Verilog describes **hardware**, not software
2. Everything runs in **parallel**
3. Use `=` for combinational, `<=` for sequential
4. Always assign all outputs to avoid latches
5. Think in terms of **wires and registers**, not variables
6. State machines are your friend for control logic
7. Test everything in simulation before synthesis

**Next Steps**:
- Read the SHA256/SHA3 implementations
- Simulate the testbenches
- Modify the code and observe changes
- Create your own modules

**Resources**:
- ASIC World Verilog Tutorial: http://www.asic-world.com/verilog/
- HDLBits (Practice): https://hdlbits.01xz.net/wiki/Main_Page
- IEEE 1364-2005 Verilog Standard (Reference)

Happy hardware designing!
