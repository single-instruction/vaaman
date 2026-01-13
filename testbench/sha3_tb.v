/*
 * SHA-3-256 Testbench
 *
 * This testbench verifies the SHA-3-256 core against NIST test vectors.
 *
 * Test vectors from NIST:
 * https://csrc.nist.gov/projects/cryptographic-standards-and-guidelines/example-values
 *
 * How to run:
 *   iverilog -o ../outflow/sha3_sim ../rtl/sha3_core.v sha3_tb.v
 *   vvp ../outflow/sha3_sim
 *   gtkwave ../outflow/sha3_tb.vcd
 *
 * Expected behavior:
 *   - All test vectors should pass
 *   - No timing violations
 *   - Ready signal properly asserted/deasserted
 */

`timescale 1ns / 1ps

module sha3_tb;

    // Clock and Reset
    reg clk;
    reg rst_n;

    // DUT Interface
    reg [1087:0] message_block;  // 1088 bits = rate for SHA-3-256
    reg start;
    reg is_last;
    wire [255:0] hash_out;
    wire ready;

    // Test Control
    integer test_num;
    integer pass_count;
    integer fail_count;
    reg [255:0] expected_hash;

    // Instantiate DUT (Device Under Test)
    sha3_core dut (
        .clk(clk),
        .rst_n(rst_n),
        .message_block(message_block),
        .start(start),
        .is_last(is_last),
        .hash_out(hash_out),
        .ready(ready)
    );

    // Clock Generation: 100 MHz (10ns period)
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // VCD Dump for Waveform Viewing
    initial begin
        $dumpfile("outflow/sha3_tb.vcd");
        $dumpvars(0, sha3_tb);
    end

    // Helper Task: Perform one hash operation (single block)
    task hash_single_block;
        input [1087:0] msg;
        input [255:0] expected;
        begin
            test_num = test_num + 1;

            // Wait for ready
            while (!ready) @(posedge clk);

            // Apply input
            @(posedge clk);
            message_block = msg;
            is_last = 1'b1;  // Single block
            start = 1;

            @(posedge clk);
            start = 0;

            // Wait for completion
            while (!ready) @(posedge clk);

            @(posedge clk);

            // Check result
            if (hash_out == expected) begin
                $display("[PASS] Test %0d: Hash matches expected value", test_num);
                pass_count = pass_count + 1;
            end else begin
                $display("[FAIL] Test %0d: Hash mismatch!", test_num);
                $display("  Expected: %064x", expected);
                $display("  Got:      %064x", hash_out);
                fail_count = fail_count + 1;
            end
        end
    endtask

    // Main Test Sequence
    initial begin
        // Initialize
        rst_n = 0;
        start = 0;
        is_last = 0;
        message_block = 1088'd0;
        test_num = 0;
        pass_count = 0;
        fail_count = 0;

        $display("========================================");
        $display("SHA-3-256 Core Testbench");
        $display("========================================");

        // Reset sequence
        #100;
        rst_n = 1;
        #50;

        // Test 1: Empty string ""
        // SHA-3 padding for empty string: 0x06 || 0x00...00 || 0x80
        // For 1088-bit rate, padding is: 0x06 then zeros then 0x80 at bit 1087
        $display("\nTest 1: Empty string");
        hash_single_block(
            {8'h06, 1072'h0, 8'h80},
            256'ha7ffc6f8bf1ed76651c14756a061d662f580ff4de43b49fa82d80a4b80f8434a
        );

        // Test 2: "abc" (24 bits)
        // "abc" = 0x616263
        // Padding: 0x616263 || 0x06 || 0x00...00 || 0x80
        $display("\nTest 2: 'abc'");
        hash_single_block(
            {24'h616263, 8'h06, 1048'h0, 8'h80},
            256'h3a985da74fe225b2045c172d6bd390bd855f086e3e9d525b46bfe24511431532
        );

        // Test 3: "abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq"
        // This is 448 bits (56 bytes)
        // Hex: 6162636462636465636465666465666765666768666768696768696a68696a6b
        //      696a6b6c6a6b6c6d6b6c6d6e6c6d6e6f6d6e6f706e6f7071
        $display("\nTest 3: 'abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq'");
        hash_single_block(
            {448'h6162636462636465636465666465666765666768666768696768696a68696a6b696a6b6c6a6b6c6d6b6c6d6e6c6d6e6f6d6e6f706e6f7071,
             8'h06, 624'h0, 8'h80},
            256'h41c0dba2a9d6240849100376a8235e2c82e1b9998a999e21db32dd97496d3376
        );

        // Test 4: Very short message "a" (8 bits)
        $display("\nTest 4: 'a'");
        hash_single_block(
            {8'h61, 8'h06, 1064'h0, 8'h80},
            256'h80084bf2fba02475726feb2cab2d8215eab14bc6bdd8bfb2c8151257032ecd8b
        );

        // Test 5: "The quick brown fox jumps over the lazy dog"
        // This is 43 bytes = 344 bits
        // Hex: 54686520717569636b2062726f776e20666f78206a756d7073206f76657220746865206c617a7920646f67
        $display("\nTest 5: 'The quick brown fox jumps over the lazy dog'");
        hash_single_block(
            {344'h54686520717569636b2062726f776e20666f78206a756d7073206f76657220746865206c617a7920646f67,
             8'h06, 728'h0, 8'h80},
            256'h69070dda01975c8c120c3aada1b282394e7f032fa9cf32f4cb2259a0897dfc04
        );

        // Test 6: Back-to-back operations (test ready/start handshake)
        $display("\nTest 6: Back-to-back 'abc' hashes");
        hash_single_block(
            {24'h616263, 8'h06, 1048'h0, 8'h80},
            256'h3a985da74fe225b2045c172d6bd390bd855f086e3e9d525b46bfe24511431532
        );
        hash_single_block(
            {24'h616263, 8'h06, 1048'h0, 8'h80},
            256'h3a985da74fe225b2045c172d6bd390bd855f086e3e9d525b46bfe24511431532
        );

        // Test 7: All zeros (edge case)
        $display("\nTest 7: Block of zeros");
        hash_single_block(
            {8'h06, 1072'h0, 8'h80},
            256'ha7ffc6f8bf1ed76651c14756a061d662f580ff4de43b49fa82d80a4b80f8434a
        );

        // Test Summary
        #1000;
        $display("\n========================================");
        $display("Test Summary");
        $display("========================================");
        $display("Total Tests: %0d", test_num);
        $display("Passed:      %0d", pass_count);
        $display("Failed:      %0d", fail_count);

        if (fail_count == 0) begin
            $display("\n*** ALL TESTS PASSED! ***\n");
        end else begin
            $display("\n*** SOME TESTS FAILED! ***\n");
        end

        $display("========================================\n");
        $finish;
    end

    // Timeout Watchdog (prevent infinite simulation)
    initial begin
        #2000000;  // 2ms timeout (SHA-3 takes more cycles)
        $display("\n[ERROR] Simulation timeout!");
        $finish;
    end

    // Monitor (optional - prints state changes)
    // Uncomment to see detailed state transitions
    /*
    always @(posedge clk) begin
        if (start)
            $display("Time %0t: START asserted", $time);
        if (ready)
            $display("Time %0t: READY asserted", $time);
    end
    */

endmodule
