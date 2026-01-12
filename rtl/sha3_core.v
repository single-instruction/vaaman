/*
 * SHA-3-256 (Keccak) Core Implementation
 *
 * This implements the SHA-3-256 hash function using the Keccak sponge construction.
 *
 * Features:
 * - SHA-3-256 (256-bit output)
 * - Rate (r) = 1088 bits
 * - Capacity (c) = 512 bits
 * - 24-round Keccak-f[1600] permutation
 * - Iterative design (one round per cycle)
 *
 * Timing:
 * - 1 cycle: IDLE → ABSORB
 * - Variable cycles: ABSORB (depending on message length)
 * - 24 cycles: PERMUTE (one round per cycle)
 * - 1 cycle: SQUEEZE
 * Total: ~26+ cycles per block
 *
 * Interface:
 * - For single-block operation:
 *   1. Assert 'start' with message_block and is_last=1
 *   2. Wait for 'ready'
 *   3. Read hash_out
 *
 * - For multi-block operation:
 *   1. Assert 'start' with first block, is_last=0
 *   2. Wait for 'ready'
 *   3. Provide next block with is_last=0
 *   4. Repeat until last block with is_last=1
 *   5. Wait for 'ready', read hash_out
 *
 * Note: This module expects PRE-PADDED input!
 * SHA-3 padding: message || 0x06 || 0x00...00 || 0x80
 */

module sha3_core (
    input wire clk,
    input wire rst_n,

    // Input interface
    input wire [1087:0] message_block,  // Rate: 1088 bits (136 bytes)
    input wire start,                    // Start processing
    input wire is_last,                  // Last block flag

    // Output interface
    output reg [255:0] hash_out,        // 256-bit hash output
    output reg ready                     // Ready for new input
);

    // ========================================================================
    // State Machine States
    // ========================================================================
    localparam [1:0] IDLE     = 2'd0;  // Waiting for input
    localparam [1:0] ABSORB   = 2'd1;  // Absorbing input
    localparam [1:0] PERMUTE  = 2'd2;  // Running Keccak-f permutation
    localparam [1:0] SQUEEZE  = 2'd3;  // Squeezing output

    reg [1:0] state;
    reg [4:0] round_counter;  // 0-23 for 24 rounds
    reg last_block;           // Remember if this is the last block

    // ========================================================================
    // Keccak State: 5x5 array of 64-bit lanes (1600 bits total)
    // ========================================================================
    reg [63:0] A [0:4][0:4];  // State array A[x][y]
    integer x, y;             // Loop variables

    // ========================================================================
    // Temporary arrays for permutation steps
    // ========================================================================
    reg [63:0] C [0:4];       // Column parity
    reg [63:0] D [0:4];       // Theta step
    reg [63:0] B [0:4][0:4];  // Intermediate state

    // ========================================================================
    // Rotation Offsets for Rho step
    // ========================================================================
    function [5:0] rho_offset;
        input [2:0] xi;  // x coordinate
        input [2:0] yi;  // y coordinate
        begin
            case ({xi, yi})
                6'b000_000: rho_offset = 6'd0;
                6'b001_000: rho_offset = 6'd1;
                6'b010_000: rho_offset = 6'd62;
                6'b011_000: rho_offset = 6'd28;
                6'b100_000: rho_offset = 6'd27;
                6'b000_001: rho_offset = 6'd36;
                6'b001_001: rho_offset = 6'd44;
                6'b010_001: rho_offset = 6'd6;
                6'b011_001: rho_offset = 6'd55;
                6'b100_001: rho_offset = 6'd20;
                6'b000_010: rho_offset = 6'd3;
                6'b001_010: rho_offset = 6'd10;
                6'b010_010: rho_offset = 6'd43;
                6'b011_010: rho_offset = 6'd25;
                6'b100_010: rho_offset = 6'd39;
                6'b000_011: rho_offset = 6'd41;
                6'b001_011: rho_offset = 6'd45;
                6'b010_011: rho_offset = 6'd15;
                6'b011_011: rho_offset = 6'd21;
                6'b100_011: rho_offset = 6'd8;
                6'b000_100: rho_offset = 6'd18;
                6'b001_100: rho_offset = 6'd2;
                6'b010_100: rho_offset = 6'd61;
                6'b011_100: rho_offset = 6'd56;
                6'b100_100: rho_offset = 6'd14;
                default:    rho_offset = 6'd0;
            endcase
        end
    endfunction

    // ========================================================================
    // Round Constants for Iota step
    // ========================================================================
    function [63:0] RC;
        input [4:0] round;
        begin
            case (round)
                5'd0:  RC = 64'h0000000000000001;
                5'd1:  RC = 64'h0000000000008082;
                5'd2:  RC = 64'h800000000000808A;
                5'd3:  RC = 64'h8000000080008000;
                5'd4:  RC = 64'h000000000000808B;
                5'd5:  RC = 64'h0000000080000001;
                5'd6:  RC = 64'h8000000080008081;
                5'd7:  RC = 64'h8000000000008009;
                5'd8:  RC = 64'h000000000000008A;
                5'd9:  RC = 64'h0000000000000088;
                5'd10: RC = 64'h0000000080008009;
                5'd11: RC = 64'h000000008000000A;
                5'd12: RC = 64'h000000008000808B;
                5'd13: RC = 64'h800000000000008B;
                5'd14: RC = 64'h8000000000008089;
                5'd15: RC = 64'h8000000000008003;
                5'd16: RC = 64'h8000000000008002;
                5'd17: RC = 64'h8000000000000080;
                5'd18: RC = 64'h000000000000800A;
                5'd19: RC = 64'h800000008000000A;
                5'd20: RC = 64'h8000000080008081;
                5'd21: RC = 64'h8000000000008080;
                5'd22: RC = 64'h0000000080000001;
                5'd23: RC = 64'h8000000080008008;
                default: RC = 64'h0000000000000000;
            endcase
        end
    endfunction

    // ========================================================================
    // Rotate Left Function (for 64-bit lanes)
    // ========================================================================
    function [63:0] rotl64;
        input [63:0] x;
        input [5:0] n;
        begin
            rotl64 = (x << n) | (x >> (64 - n));
        end
    endfunction

    // ========================================================================
    // Byte Swap Function (convert between big-endian and little-endian)
    // ========================================================================
    function [63:0] byte_swap64;
        input [63:0] x;
        begin
            byte_swap64 = {x[7:0], x[15:8], x[23:16], x[31:24],
                          x[39:32], x[47:40], x[55:48], x[63:56]};
        end
    endfunction

    // ========================================================================
    // Keccak-f[1600] Permutation (One Round)
    // ========================================================================
    // This executes one complete round of theta, rho, pi, chi, iota
    // We'll implement this as combinational logic that updates A in one cycle

    task keccak_round;
        input [4:0] round_idx;
        integer xi, yi;
        begin
            // ================================================================
            // Step 1: Theta (θ)
            // ================================================================
            // Compute column parity: C[x] = A[x,0] ⊕ A[x,1] ⊕ A[x,2] ⊕ A[x,3] ⊕ A[x,4]
            for (xi = 0; xi < 5; xi = xi + 1) begin
                C[xi] = A[xi][0] ^ A[xi][1] ^ A[xi][2] ^ A[xi][3] ^ A[xi][4];
            end

            // Compute D[x] = C[x-1] ⊕ ROT(C[x+1], 1)
            for (xi = 0; xi < 5; xi = xi + 1) begin
                D[xi] = C[(xi + 4) % 5] ^ rotl64(C[(xi + 1) % 5], 6'd1);
            end

            // Apply: A[x,y] = A[x,y] ⊕ D[x]
            for (xi = 0; xi < 5; xi = xi + 1) begin
                for (yi = 0; yi < 5; yi = yi + 1) begin
                    A[xi][yi] = A[xi][yi] ^ D[xi];
                end
            end

            // ================================================================
            // Step 2: Rho (ρ) and Pi (π) combined
            // ================================================================
            // Rho: Rotate each lane by fixed offset
            // Pi: Rearrange lanes
            // Combined: B[y, 2x+3y] = ROT(A[x,y], r[x,y])

            for (xi = 0; xi < 5; xi = xi + 1) begin
                for (yi = 0; yi < 5; yi = yi + 1) begin
                    B[yi][(2*xi + 3*yi) % 5] = rotl64(A[xi][yi], rho_offset(xi[2:0], yi[2:0]));
                end
            end

            // ================================================================
            // Step 3: Chi (χ)
            // ================================================================
            // A[x,y] = B[x,y] ⊕ ((~B[x+1,y]) & B[x+2,y])
            for (xi = 0; xi < 5; xi = xi + 1) begin
                for (yi = 0; yi < 5; yi = yi + 1) begin
                    A[xi][yi] = B[xi][yi] ^ ((~B[(xi+1) % 5][yi]) & B[(xi+2) % 5][yi]);
                end
            end

            // ================================================================
            // Step 4: Iota (ι)
            // ================================================================
            // A[0,0] = A[0,0] ⊕ RC[round]
            A[0][0] = A[0][0] ^ RC(round_idx);
        end
    endtask

    // ========================================================================
    // Main State Machine
    // ========================================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            ready <= 1'b1;
            round_counter <= 5'd0;
            last_block <= 1'b0;
            hash_out <= 256'd0;

            // Initialize state array to zeros
            for (x = 0; x < 5; x = x + 1) begin
                for (y = 0; y < 5; y = y + 1) begin
                    A[x][y] <= 64'd0;
                end
            end

        end else begin
            case (state)
                // ============================================================
                // IDLE: Wait for start signal
                // ============================================================
                IDLE: begin
                    ready <= 1'b1;
                    if (start) begin
                        state <= ABSORB;
                        ready <= 1'b0;
                        last_block <= is_last;
                    end
                end

                // ============================================================
                // ABSORB: XOR message block into state (first r=1088 bits)
                // ============================================================
                ABSORB: begin
                    // XOR message into first 1088 bits of state (17 64-bit lanes)
                    // SHA-3 uses little-endian lane ordering, so byte-swap each lane

                    // Lane [0,0]
                    A[0][0] <= A[0][0] ^ byte_swap64(message_block[1087:1024]);
                    // Lane [1,0]
                    A[1][0] <= A[1][0] ^ byte_swap64(message_block[1023:960]);
                    // Lane [2,0]
                    A[2][0] <= A[2][0] ^ byte_swap64(message_block[959:896]);
                    // Lane [3,0]
                    A[3][0] <= A[3][0] ^ byte_swap64(message_block[895:832]);
                    // Lane [4,0]
                    A[4][0] <= A[4][0] ^ byte_swap64(message_block[831:768]);
                    // Lane [0,1]
                    A[0][1] <= A[0][1] ^ byte_swap64(message_block[767:704]);
                    // Lane [1,1]
                    A[1][1] <= A[1][1] ^ byte_swap64(message_block[703:640]);
                    // Lane [2,1]
                    A[2][1] <= A[2][1] ^ byte_swap64(message_block[639:576]);
                    // Lane [3,1]
                    A[3][1] <= A[3][1] ^ byte_swap64(message_block[575:512]);
                    // Lane [4,1]
                    A[4][1] <= A[4][1] ^ byte_swap64(message_block[511:448]);
                    // Lane [0,2]
                    A[0][2] <= A[0][2] ^ byte_swap64(message_block[447:384]);
                    // Lane [1,2]
                    A[1][2] <= A[1][2] ^ byte_swap64(message_block[383:320]);
                    // Lane [2,2]
                    A[2][2] <= A[2][2] ^ byte_swap64(message_block[319:256]);
                    // Lane [3,2]
                    A[3][2] <= A[3][2] ^ byte_swap64(message_block[255:192]);
                    // Lane [4,2]
                    A[4][2] <= A[4][2] ^ byte_swap64(message_block[191:128]);
                    // Lane [0,3]
                    A[0][3] <= A[0][3] ^ byte_swap64(message_block[127:64]);
                    // Lane [1,3] - last lane (1088 bits = 17 lanes exactly)
                    A[1][3] <= A[1][3] ^ byte_swap64(message_block[63:0]);

                    round_counter <= 5'd0;
                    state <= PERMUTE;
                end

                // ============================================================
                // PERMUTE: Execute 24 rounds of Keccak-f[1600]
                // ============================================================
                PERMUTE: begin
                    // Execute one round
                    keccak_round(round_counter);

                    if (round_counter == 5'd23) begin
                        // Permutation complete
                        if (last_block) begin
                            state <= SQUEEZE;
                        end else begin
                            state <= IDLE;  // Wait for next block
                        end
                    end else begin
                        round_counter <= round_counter + 1;
                    end
                end

                // ============================================================
                // SQUEEZE: Extract output (first 256 bits)
                // ============================================================
                SQUEEZE: begin
                    // Extract first 256 bits (4 lanes) as hash output
                    // Byte-swap each lane back to big-endian for output
                    hash_out <= {byte_swap64(A[0][0]), byte_swap64(A[1][0]),
                                byte_swap64(A[2][0]), byte_swap64(A[3][0])};

                    // Reset state for next hash
                    for (x = 0; x < 5; x = x + 1) begin
                        for (y = 0; y < 5; y = y + 1) begin
                            A[x][y] <= 64'd0;
                        end
                    end

                    state <= IDLE;
                end

                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule
