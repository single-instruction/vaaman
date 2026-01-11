#!/usr/bin/env python3
"""
Fetch median gas fees from Ethereum using Dune API
"""

import os
import time
from dune_client import DuneClient
from dune_client.query import QueryBase
from dune_client.types import QueryParameter

# Initialize Dune client
# Get API key from environment variable or set it directly
DUNE_API_KEY = os.environ.get("DUNE_API_KEY", "your_api_key_here")
dune = DuneClient(DUNE_API_KEY)


def fetch_median_gas_fees_from_existing_query(query_id: int):
    """
    Execute an existing Dune query and fetch results

    Args:
        query_id: The ID of your Dune query
    """
    print(f"Executing query {query_id}...")

    # Execute the query
    results = dune.run_query(query_id)

    # Get the execution result
    return results


def create_and_execute_query():
    """
    Create a new query programmatically and execute it
    """

    # Define the SQL query
    sql_query = """
    SELECT
        DATE_TRUNC('day', block_time) as date,
        approx_percentile(gas_used * gas_price / 1e18, 0.5) as median_gas_fee_eth,
        approx_percentile(gas_used * gas_price / 1e9, 0.5) as median_gas_fee_gwei,
        COUNT(*) as tx_count,
        AVG(gas_used * gas_price / 1e18) as avg_gas_fee_eth
    FROM ethereum.transactions
    WHERE block_time >= NOW() - INTERVAL '7' day
    GROUP BY 1
    ORDER BY 1 DESC
    """

    print("Creating and executing query...")

    # Create query
    query = QueryBase(
        name="Ethereum Median Gas Fees",
        query_sql=sql_query,
    )

    # Execute query
    results = dune.run_query_dataframe(query)

    return results


def fetch_with_parameters(query_id: int, days: int = 7):
    """
    Execute query with parameters

    Args:
        query_id: The ID of your Dune query
        days: Number of days to look back
    """
    print(f"Executing query {query_id} with {days} days parameter...")

    # Define query parameters
    query = QueryBase(
        query_id=query_id,
        params=[
            QueryParameter.number_type(name="days", value=days),
        ]
    )

    # Execute query and get results as dataframe
    results = dune.run_query_dataframe(query)

    return results


def get_latest_gas_fees():
    """
    Get current gas fee statistics
    """
    sql_query = """
    SELECT
        approx_percentile(gas_used * gas_price / 1e18, 0.5) as median_gas_fee_eth,
        approx_percentile(gas_used * gas_price / 1e9, 0.5) as median_gas_fee_gwei,
        approx_percentile(gas_used * gas_price / 1e9, 0.25) as p25_gwei,
        approx_percentile(gas_used * gas_price / 1e9, 0.75) as p75_gwei,
        approx_percentile(gas_used * gas_price / 1e9, 0.95) as p95_gwei,
        COUNT(*) as tx_count,
        AVG(gas_used * gas_price / 1e18) as avg_gas_fee_eth,
        MIN(block_time) as period_start,
        MAX(block_time) as period_end
    FROM ethereum.transactions
    WHERE block_time >= NOW() - INTERVAL '1' hour
    """

    print("Fetching latest gas fees (last 1 hour)...")

    query = QueryBase(
        name="Latest Gas Fees",
        query_sql=sql_query,
    )

    results = dune.run_query_dataframe(query)

    return results


def get_eip1559_gas_fees():
    """
    Get gas fees for EIP-1559 transactions (post-London fork)
    """
    sql_query = """
    SELECT
        DATE_TRUNC('hour', block_time) as hour,
        approx_percentile(
            gas_used * (base_fee_per_gas + priority_fee_per_gas) / 1e18,
            0.5
        ) as median_total_fee_eth,
        approx_percentile(base_fee_per_gas / 1e9, 0.5) as median_base_fee_gwei,
        approx_percentile(priority_fee_per_gas / 1e9, 0.5) as median_priority_fee_gwei,
        COUNT(*) as tx_count
    FROM ethereum.transactions
    WHERE block_time >= NOW() - INTERVAL '24' hour
        AND type = 'DynamicFee'  -- EIP-1559 transactions
    GROUP BY 1
    ORDER BY 1 DESC
    """

    print("Fetching EIP-1559 gas fees (last 24 hours)...")

    query = QueryBase(
        name="EIP-1559 Gas Fees",
        query_sql=sql_query,
    )

    results = dune.run_query_dataframe(query)

    return results


if __name__ == "__main__":
    print("=" * 60)
    print("Dune API - Ethereum Gas Fees Fetcher")
    print("=" * 60)

    # Option 1: Create and execute a new query
    print("\n1. Fetching 7-day median gas fees...")
    df = create_and_execute_query()
    print(df)

    # Option 2: Get latest gas fees
    print("\n2. Fetching latest gas fees (last hour)...")
    latest = get_latest_gas_fees()
    print(latest)

    # Option 3: Get EIP-1559 specific fees
    print("\n3. Fetching EIP-1559 gas fees (last 24 hours)...")
    eip1559 = get_eip1559_gas_fees()
    print(eip1559)

    # Example: Using an existing query ID
    # Uncomment and replace with your actual query ID
    # print("\n4. Fetching from existing query...")
    # results = fetch_median_gas_fees_from_existing_query(query_id=1234567)
    # print(results)

    print("\n" + "=" * 60)
    print("Done!")
