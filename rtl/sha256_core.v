/*
 * SHA-256 Core Implementation
 *
 * This is an iterative implementation that processes one 512-bit block at a time.
 * It performs 64 rounds sequentially (one round per clock cycle).
 *
 * Features:
 * - Processes one 512-bit message block per operation
 * - Outputs 256-bit hash
 * - Resource-efficient iterative design
 * - Simple ready/start handshake interface
 *
 * Timing:
 * - 1 cycle: IDLE → LOAD
 * - 1 cycle: LOAD → PREPARE
 * - 48 cycles: PREPARE (computing W[16..63])
 * - 64 cycles: PROCESS (64 rounds)
 * - 1 cycle: DONE
 * Total: ~115 cycles per block
 *
 * Interface:
 * - Assert 'start' when ready=1 to begin hashing
 * - Provide 512-bit message block (already padded)
 * - Wait for ready=1, read hash_out
 *
 * Note: This module expects PRE-PADDED input!
 * You must handle padding externally.
 */

module sha256_core (
    input wire clk,
    input wire rst_n,

    // Input interface
    input wire [511:0] message_block,  // 512-bit input block (big-endian)
    input wire start,                   // Start processing

    // Output interface
    output reg [255:0] hash_out,       // 256-bit hash output
    output reg ready                    // Ready for new input
);

    // State Machine States
    localparam [2:0] IDLE    = 3'd0;  // Waiting for input
    localparam [2:0] LOAD    = 3'd1;  // Loading message into W[0..15]
    localparam [2:0] PREPARE = 3'd2;  // Computing W[16..63]
    localparam [2:0] PROCESS = 3'd3;  // Processing 64 rounds
    localparam [2:0] DONE    = 3'd4;  // Finalizing hash

    reg [2:0] state, next_state;
    reg [6:0] round_counter;           // 0-63 for rounds, 16-63 for prepare

    // Hash Values (H) - Persistent across blocks
    reg [31:0] H0, H1, H2, H3, H4, H5, H6, H7;

    // Working Variables (a-h) - Updated each round
    reg [31:0] a, b, c, d, e, f, g, h;

    // Message Schedule (W) - 64 32-bit words
    reg [31:0] W [0:63];
    integer i;  // For loop variable

    // Round Constants (K) - First 32 bits of cube roots of first 64 primes
    function [31:0] K;
        input [5:0] t;
        begin
            case (t)
                6'd0:  K = 32'h428a2f98;
                6'd1:  K = 32'h71374491;
                6'd2:  K = 32'hb5c0fbcf;
                6'd3:  K = 32'he9b5dba5;
                6'd4:  K = 32'h3956c25b;
                6'd5:  K = 32'h59f111f1;
                6'd6:  K = 32'h923f82a4;
                6'd7:  K = 32'hab1c5ed5;
                6'd8:  K = 32'hd807aa98;
                6'd9:  K = 32'h12835b01;
                6'd10: K = 32'h243185be;
                6'd11: K = 32'h550c7dc3;
                6'd12: K = 32'h72be5d74;
                6'd13: K = 32'h80deb1fe;
                6'd14: K = 32'h9bdc06a7;
                6'd15: K = 32'hc19bf174;
                6'd16: K = 32'he49b69c1;
                6'd17: K = 32'hefbe4786;
                6'd18: K = 32'h0fc19dc6;
                6'd19: K = 32'h240ca1cc;
                6'd20: K = 32'h2de92c6f;
                6'd21: K = 32'h4a7484aa;
                6'd22: K = 32'h5cb0a9dc;
                6'd23: K = 32'h76f988da;
                6'd24: K = 32'h983e5152;
                6'd25: K = 32'ha831c66d;
                6'd26: K = 32'hb00327c8;
                6'd27: K = 32'hbf597fc7;
                6'd28: K = 32'hc6e00bf3;
                6'd29: K = 32'hd5a79147;
                6'd30: K = 32'h06ca6351;
                6'd31: K = 32'h14292967;
                6'd32: K = 32'h27b70a85;
                6'd33: K = 32'h2e1b2138;
                6'd34: K = 32'h4d2c6dfc;
                6'd35: K = 32'h53380d13;
                6'd36: K = 32'h650a7354;
                6'd37: K = 32'h766a0abb;
                6'd38: K = 32'h81c2c92e;
                6'd39: K = 32'h92722c85;
                6'd40: K = 32'ha2bfe8a1;
                6'd41: K = 32'ha81a664b;
                6'd42: K = 32'hc24b8b70;
                6'd43: K = 32'hc76c51a3;
                6'd44: K = 32'hd192e819;
                6'd45: K = 32'hd6990624;
                6'd46: K = 32'hf40e3585;
                6'd47: K = 32'h106aa070;
                6'd48: K = 32'h19a4c116;
                6'd49: K = 32'h1e376c08;
                6'd50: K = 32'h2748774c;
                6'd51: K = 32'h34b0bcb5;
                6'd52: K = 32'h391c0cb3;
                6'd53: K = 32'h4ed8aa4a;
                6'd54: K = 32'h5b9cca4f;
                6'd55: K = 32'h682e6ff3;
                6'd56: K = 32'h748f82ee;
                6'd57: K = 32'h78a5636f;
                6'd58: K = 32'h84c87814;
                6'd59: K = 32'h8cc70208;
                6'd60: K = 32'h90befffa;
                6'd61: K = 32'ha4506ceb;
                6'd62: K = 32'hbef9a3f7;
                6'd63: K = 32'hc67178f2;
                default: K = 32'h00000000;
            endcase
        end
    endfunction

    // SHA-256 Functions

    // Rotate right by n bits
    function [31:0] rotr;
        input [31:0] x;
        input [4:0] n;
        begin
            rotr = (x >> n) | (x << (32 - n));
        end
    endfunction

    // Shift right by n bits (logical)
    function [31:0] shr;
        input [31:0] x;
        input [4:0] n;
        begin
            shr = x >> n;
        end
    endfunction

    // Ch(x,y,z) = (x AND y) XOR (NOT x AND z)
    // "Choose": If x then y, else z
    function [31:0] ch;
        input [31:0] x, y, z;
        begin
            ch = (x & y) ^ (~x & z);
        end
    endfunction

    // Maj(x,y,z) = (x AND y) XOR (x AND z) XOR (y AND z)
    // "Majority": Return majority bit value
    function [31:0] maj;
        input [31:0] x, y, z;
        begin
            maj = (x & y) ^ (x & z) ^ (y & z);
        end
    endfunction

    // Σ₀(x) = ROTR²(x) XOR ROTR¹³(x) XOR ROTR²²(x)
    function [31:0] sum0;
        input [31:0] x;
        begin
            sum0 = rotr(x, 5'd2) ^ rotr(x, 5'd13) ^ rotr(x, 5'd22);
        end
    endfunction

    // Σ₁(x) = ROTR⁶(x) XOR ROTR¹¹(x) XOR ROTR²⁵(x)
    function [31:0] sum1;
        input [31:0] x;
        begin
            sum1 = rotr(x, 5'd6) ^ rotr(x, 5'd11) ^ rotr(x, 5'd25);
        end
    endfunction

    // σ₀(x) = ROTR⁷(x) XOR ROTR¹⁸(x) XOR SHR³(x)
    function [31:0] sigma0;
        input [31:0] x;
        begin
            sigma0 = rotr(x, 5'd7) ^ rotr(x, 5'd18) ^ shr(x, 5'd3);
        end
    endfunction

    // σ₁(x) = ROTR¹⁷(x) XOR ROTR¹⁹(x) XOR SHR¹⁰(x)
    function [31:0] sigma1;
        input [31:0] x;
        begin
            sigma1 = rotr(x, 5'd17) ^ rotr(x, 5'd19) ^ shr(x, 5'd10);
        end
    endfunction

    // Temporary Variables for Round Computation
    reg [31:0] T1, T2;

    // Main State Machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset to initial state
            state <= IDLE;
            ready <= 1'b1;
            round_counter <= 7'd0;
            hash_out <= 256'd0;

            // Initialize H values (first 32 bits of fractional parts of sqrt of first 8 primes)
            H0 <= 32'h6a09e667;
            H1 <= 32'hbb67ae85;
            H2 <= 32'h3c6ef372;
            H3 <= 32'ha54ff53a;
            H4 <= 32'h510e527f;
            H5 <= 32'h9b05688c;
            H6 <= 32'h1f83d9ab;
            H7 <= 32'h5be0cd19;

            // Initialize W array
            for (i = 0; i < 64; i = i + 1) begin
                W[i] <= 32'd0;
            end

            a <= 32'd0;
            b <= 32'd0;
            c <= 32'd0;
            d <= 32'd0;
            e <= 32'd0;
            f <= 32'd0;
            g <= 32'd0;
            h <= 32'd0;

        end else begin
            case (state)
                // IDLE: Wait for start signal
                IDLE: begin
                    ready <= 1'b1;
                    if (start) begin
                        state <= LOAD;
                        ready <= 1'b0;
                    end
                end

                // LOAD: Load message block into W[0..15]
                LOAD: begin
                    // Reset H values for new hash (single-block mode)
                    H0 <= 32'h6a09e667;
                    H1 <= 32'hbb67ae85;
                    H2 <= 32'h3c6ef372;
                    H3 <= 32'ha54ff53a;
                    H4 <= 32'h510e527f;
                    H5 <= 32'h9b05688c;
                    H6 <= 32'h1f83d9ab;
                    H7 <= 32'h5be0cd19;

                    // Split 512-bit message into 16 32-bit words (big-endian)
                    // message_block[511:480] is first word, etc.
                    W[0]  <= message_block[511:480];
                    W[1]  <= message_block[479:448];
                    W[2]  <= message_block[447:416];
                    W[3]  <= message_block[415:384];
                    W[4]  <= message_block[383:352];
                    W[5]  <= message_block[351:320];
                    W[6]  <= message_block[319:288];
                    W[7]  <= message_block[287:256];
                    W[8]  <= message_block[255:224];
                    W[9]  <= message_block[223:192];
                    W[10] <= message_block[191:160];
                    W[11] <= message_block[159:128];
                    W[12] <= message_block[127:96];
                    W[13] <= message_block[95:64];
                    W[14] <= message_block[63:32];
                    W[15] <= message_block[31:0];

                    round_counter <= 7'd16;
                    state <= PREPARE;
                end

                // PREPARE: Compute W[16..63] using message schedule
                PREPARE: begin
                    // W[t] = σ₁(W[t-2]) + W[t-7] + σ₀(W[t-15]) + W[t-16]
                    W[round_counter] <= sigma1(W[round_counter - 2]) +
                                       W[round_counter - 7] +
                                       sigma0(W[round_counter - 15]) +
                                       W[round_counter - 16];

                    if (round_counter == 7'd63) begin
                        // Message schedule complete, initialize working variables
                        a <= H0;
                        b <= H1;
                        c <= H2;
                        d <= H3;
                        e <= H4;
                        f <= H5;
                        g <= H6;
                        h <= H7;

                        round_counter <= 7'd0;
                        state <= PROCESS;
                    end else begin
                        round_counter <= round_counter + 1;
                    end
                end

                // PROCESS: Execute 64 compression rounds
                PROCESS: begin
                    // Compute T1 and T2
                    // T₁ = h + Σ₁(e) + Ch(e,f,g) + K[t] + W[t]
                    T1 = h + sum1(e) + ch(e, f, g) + K(round_counter[5:0]) + W[round_counter];

                    // T₂ = Σ₀(a) + Maj(a,b,c)
                    T2 = sum0(a) + maj(a, b, c);

                    // Update working variables
                    h <= g;
                    g <= f;
                    f <= e;
                    e <= d + T1;
                    d <= c;
                    c <= b;
                    b <= a;
                    a <= T1 + T2;

                    if (round_counter == 7'd63) begin
                        state <= DONE;
                    end else begin
                        round_counter <= round_counter + 1;
                    end
                end

                // DONE: Add working variables to hash values and output
                DONE: begin
                    // Add working variables to hash values
                    H0 <= H0 + a;
                    H1 <= H1 + b;
                    H2 <= H2 + c;
                    H3 <= H3 + d;
                    H4 <= H4 + e;
                    H5 <= H5 + f;
                    H6 <= H6 + g;
                    H7 <= H7 + h;

                    // Concatenate hash values for output
                    hash_out <= {H0 + a, H1 + b, H2 + c, H3 + d,
                                H4 + e, H5 + f, H6 + g, H7 + h};

                    state <= IDLE;
                end

                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule
