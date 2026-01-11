#!/usr/bin/env python3
"""
Simple script to fetch median gas fees from Dune
"""

import os
from dune_client import DuneClient
from dune_client.query import QueryBase

# Set your Dune API key here or in environment variable
API_KEY = os.environ.get("DUNE_API_KEY", "YOUR_API_KEY_HERE")

# Initialize client
dune = DuneClient(API_KEY)

# Simple query for median gas fees
query = QueryBase(
    name="Quick Gas Fees",
    query_sql="""
    SELECT
        approx_percentile(gas_used * gas_price / 1e18, 0.5) as median_gas_fee_eth,
        approx_percentile(gas_used * gas_price / 1e9, 0.5) as median_gas_fee_gwei,
        COUNT(*) as total_transactions
    FROM ethereum.transactions
    WHERE block_time >= NOW() - INTERVAL '24' hour
    """
)

# Execute and get results
print("Fetching median gas fees for last 24 hours...")
results = dune.run_query_dataframe(query)

print("\nResults:")
print(results)

if not results.empty:
    median_eth = results['median_gas_fee_eth'].iloc[0]
    median_gwei = results['median_gas_fee_gwei'].iloc[0]
    tx_count = results['total_transactions'].iloc[0]

    print(f"\nMedian Gas Fee: {median_eth:.6f} ETH ({median_gwei:.2f} Gwei)")
    print(f"Total Transactions: {tx_count:,}")
