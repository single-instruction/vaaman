#!/usr/bin/env python3
"""
Verify SHA-256 and SHA-3-256 Testbench Values

This script verifies all hash values in the Verilog testbenches against
Python's hashlib implementation and NIST test vectors.

The test cases are extracted exactly from:
- testbench/sha256_tb.v
- testbench/sha3_tb.v

Usage:
    python3 verify_testbench.py

Sources:
- NIST CSRC: https://csrc.nist.gov/projects/cryptographic-standards-and-guidelines/example-values
- Test Vectors: https://di-mgt.com.au/sha_testvectors.html
"""

import hashlib
import sys

# ANSI color codes
GREEN = '\033[92m'
RED = '\033[91m'
YELLOW = '\033[93m'
BLUE = '\033[94m'
RESET = '\033[0m'

def format_hash(h):
    """Format hash for display with spaces every 8 chars"""
    return ' '.join([h[i:i+8] for i in range(0, len(h), 8)])

def verify_sha256(tests):
    """Verify SHA-256 test vectors"""
    print(f"\n{BLUE}{'='*80}{RESET}")
    print(f"{BLUE}SHA-256 Test Vector Verification{RESET}")
    print(f"{BLUE}From: testbench/sha256_tb.v{RESET}")
    print(f"{BLUE}{'='*80}{RESET}\n")

    passed = 0
    failed = 0

    for i, (description, msg, expected) in enumerate(tests, 1):
        computed = hashlib.sha256(msg.encode()).hexdigest()
        match = computed == expected

        if match:
            status = f"{GREEN}PASS{RESET}"
            passed += 1
        else:
            status = f"{RED}FAIL{RESET}"
            failed += 1

        print(f"Test {i}: {status} - {description}")

        # Display message (truncate if too long)
        display_msg = msg if len(msg) <= 40 else msg[:37] + "..."
        print(f"  Input:    '{display_msg}'")
        print(f"  Expected: {format_hash(expected)}")

        if not match:
            print(f"  {RED}Computed: {format_hash(computed)}{RESET}")
        else:
            print(f"  Computed: {format_hash(computed)}")
        print()

    return passed, failed

def verify_sha3(tests):
    """Verify SHA-3-256 test vectors"""
    print(f"\n{BLUE}{'='*80}{RESET}")
    print(f"{BLUE}SHA-3-256 Test Vector Verification{RESET}")
    print(f"{BLUE}From: testbench/sha3_tb.v{RESET}")
    print(f"{BLUE}{'='*80}{RESET}\n")

    passed = 0
    failed = 0

    for i, (description, msg, expected) in enumerate(tests, 1):
        computed = hashlib.sha3_256(msg.encode()).hexdigest()
        match = computed == expected

        if match:
            status = f"{GREEN}PASS{RESET}"
            passed += 1
        else:
            status = f"{RED}FAIL{RESET}"
            failed += 1

        print(f"Test {i}: {status} - {description}")

        # Display message (truncate if too long)
        display_msg = msg if len(msg) <= 40 else msg[:37] + "..."
        print(f"  Input:    '{display_msg}'")
        print(f"  Expected: {format_hash(expected)}")

        if not match:
            print(f"  {RED}Computed: {format_hash(computed)}{RESET}")
        else:
            print(f"  Computed: {format_hash(computed)}")
        print()

    return passed, failed

def main():
    print(f"\n{YELLOW}Testbench Hash Verification Tool{RESET}")
    print(f"{YELLOW}Verifying against Python hashlib and NIST test vectors{RESET}")

    # SHA-256 test vectors from testbench/sha256_tb.v
    # Extracted exactly as they appear in the testbench
    sha256_tests = [
        # Test 1: Empty string ""
        ("Empty string",
         "",
         "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"),

        # Test 2: "abc"
        ("'abc'",
         "abc",
         "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"),

        # Test 3: "hello"
        ("'hello'",
         "hello",
         "2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824"),

        # Test 4: Block of zeros with length 0 (same as empty string)
        ("Block of zeros with length 0",
         "",
         "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"),

        # Test 5: "test"
        ("'test'",
         "test",
         "9f86d081884c7d659a2feaa0c55ad015a3bf4f1b2b0b822cd15d6c15b0f00a08"),

        # Test 6: Back-to-back 'abc' hashes (first)
        ("Back-to-back 'abc' hashes #1",
         "abc",
         "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"),

        # Test 7: Back-to-back 'abc' hashes (second)
        ("Back-to-back 'abc' hashes #2",
         "abc",
         "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"),
    ]

    # SHA-3-256 test vectors from testbench/sha3_tb.v
    # Extracted exactly as they appear in the testbench
    sha3_tests = [
        # Test 1: Empty string
        ("Empty string",
         "",
         "a7ffc6f8bf1ed76651c14756a061d662f580ff4de43b49fa82d80a4b80f8434a"),

        # Test 2: "abc"
        ("'abc'",
         "abc",
         "3a985da74fe225b2045c172d6bd390bd855f086e3e9d525b46bfe24511431532"),

        # Test 3: Long string (56 bytes)
        ("'abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq'",
         "abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq",
         "41c0dba2a9d6240849100376a8235e2c82e1b9998a999e21db32dd97496d3376"),

        # Test 4: "a"
        ("'a'",
         "a",
         "80084bf2fba02475726feb2cab2d8215eab14bc6bdd8bfb2c8151257032ecd8b"),

        # Test 5: The quick brown fox
        ("'The quick brown fox jumps over the lazy dog'",
         "The quick brown fox jumps over the lazy dog",
         "69070dda01975c8c120c3aada1b282394e7f032fa9cf32f4cb2259a0897dfc04"),

        # Test 6: Back-to-back 'abc' hashes (first)
        ("Back-to-back 'abc' hashes #1",
         "abc",
         "3a985da74fe225b2045c172d6bd390bd855f086e3e9d525b46bfe24511431532"),

        # Test 7: Back-to-back 'abc' hashes (second)
        ("Back-to-back 'abc' hashes #2",
         "abc",
         "3a985da74fe225b2045c172d6bd390bd855f086e3e9d525b46bfe24511431532"),

        # Test 8: Block of zeros (same as empty string)
        ("Block of zeros",
         "",
         "a7ffc6f8bf1ed76651c14756a061d662f580ff4de43b49fa82d80a4b80f8434a"),
    ]

    # Run SHA-256 verification
    sha256_passed, sha256_failed = verify_sha256(sha256_tests)

    # Run SHA-3-256 verification
    sha3_passed, sha3_failed = verify_sha3(sha3_tests)

    # Summary
    print(f"\n{BLUE}{'='*80}{RESET}")
    print(f"{BLUE}Summary{RESET}")
    print(f"{BLUE}{'='*80}{RESET}")

    total_passed = sha256_passed + sha3_passed
    total_failed = sha256_failed + sha3_failed
    total_tests = total_passed + total_failed

    print(f"\nSHA-256:   {sha256_passed}/{len(sha256_tests)} passed")
    print(f"SHA-3-256: {sha3_passed}/{len(sha3_tests)} passed")
    print(f"\nTotal:     {total_passed}/{total_tests} tests passed")

    if total_failed == 0:
        print(f"\n{GREEN}*** ALL TESTS PASSED ***{RESET}")
        print(f"{GREEN}All testbench values are correct and match NIST test vectors.{RESET}\n")
        return 0
    else:
        print(f"\n{RED}*** {total_failed} TEST(S) FAILED ***{RESET}")
        print(f"{RED}Some testbench values do not match expected outputs.{RESET}\n")
        return 1

if __name__ == "__main__":
    sys.exit(main())
