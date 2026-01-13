/*
 * SHA-256 Testbench
 *
 * This testbench verifies the SHA-256 core against NIST test vectors.
 *
 * Test vectors from NIST:
 * https://csrc.nist.gov/projects/cryptographic-standards-and-guidelines/example-values
 *
 * How to run:
 *   iverilog -o ../outflow/sha256_sim ../rtl/sha256_core.v sha256_tb.v
 *   vvp ../outflow/sha256_sim
 *   gtkwave ../outflow/sha256_tb.vcd
 *
 * Expected behavior:
 *   - All test vectors should pass
 *   - No timing violations
 *   - Ready signal properly asserted/deasserted
 */

`timescale 1ns / 1ps

module sha256_tb;

    // Clock and Reset
    reg clk;
    reg rst_n;

    // DUT Interface
    reg [511:0] message_block;
    reg start;
    wire [255:0] hash_out;
    wire ready;

    // Test Control
    integer test_num;
    integer pass_count;
    integer fail_count;
    reg [255:0] expected_hash;

    // Instantiate DUT (Device Under Test)
    sha256_core dut (
        .clk(clk),
        .rst_n(rst_n),
        .message_block(message_block),
        .start(start),
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
        $dumpfile("outflow/sha256_tb.vcd");
        $dumpvars(0, sha256_tb);
    end

    // Helper Task: Perform one hash operation
    task hash_block;
        input [511:0] msg;
        input [255:0] expected;
        begin
            test_num = test_num + 1;

            // Wait for ready
            while (!ready) @(posedge clk);

            // Apply input
            @(posedge clk);
            message_block = msg;
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
        message_block = 512'd0;
        test_num = 0;
        pass_count = 0;
        fail_count = 0;

        $display("========================================");
        $display("SHA-256 Core Testbench");
        $display("========================================");

        // Reset sequence
        #100;
        rst_n = 1;
        #50;

        // Test 1: Empty string ""
        // Padded message: 0x80 followed by zeros, then length (0x00)
        $display("\nTest 1: Empty string");
        hash_block(
            512'h80000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000,
            256'he3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855
        );

        // Test 2: "abc"
        // "abc" = 0x616263
        // Padded: 0x61626380 00...00 00...18 (24 bits = 0x18)
        $display("\nTest 2: 'abc'");
        hash_block(
            512'h61626380000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000018,
            256'hba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad
        );

        // Test 3: "hello" (40 bits = 5 bytes)
        // "hello" = 0x68656c6c6f
        // Padded: 0x68656c6c6f80 00...00 00...28 (40 bits = 0x28)
        $display("\nTest 3: 'hello'");
        hash_block(
            512'h68656c6c6f8000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000028,
            256'h2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824
        );

        // Test 4: Single block of zeros (testing corner case)
        $display("\nTest 4: Block of zeros with length 0");
        hash_block(
            512'h80000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000,
            256'he3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855
        );

        // Test 5: "test" (32 bits = 4 bytes)
        // "test" = 0x74657374
        // Padded: 0x7465737480 00...00 00...20 (32 bits = 0x20)
        $display("\nTest 5: 'test'");
        hash_block(
            512'h74657374800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000020,
            256'h9f86d081884c7d659a2feaa0c55ad015a3bf4f1b2b0b822cd15d6c15b0f00a08
        );

        // Test 6: Back-to-back operations (test ready/start handshake)
        $display("\nTest 6: Back-to-back 'abc' hashes");
        hash_block(
            512'h61626380000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000018,
            256'hba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad
        );
        hash_block(
            512'h61626380000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000018,
            256'hba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad
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
        #1000000;  // 1ms timeout
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
