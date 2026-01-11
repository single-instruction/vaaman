# Dune API - Ethereum Gas Fees Guide

## Quick Start

### 1. Install Dependencies

```bash
pip install -r requirements.txt
```

### 2. Get Your Dune API Key

1. Go to [https://dune.com/settings/api](https://dune.com/settings/api)
2. Create an API key
3. Copy the key

### 3. Set Up Environment

```bash
# Copy the example env file
cp .env.example .env

# Edit .env and add your API key
nano .env
```

Or export directly:
```bash
export DUNE_API_KEY="your_api_key_here"
```

### 4. Run the Script

**Simple version:**
```bash
python simple_gas_fees.py
```

**Full version with multiple queries:**
```bash
python dune_gas_fees.py
```

---

## Usage Examples

### Example 1: Quick Median Gas Fee

```python
from dune_client import DuneClient
from dune_client.query import QueryBase

dune = DuneClient("YOUR_API_KEY")

query = QueryBase(
    query_sql="""
    SELECT approx_percentile(gas_used * gas_price / 1e9, 0.5) as median_gwei
    FROM ethereum.transactions
    WHERE block_time >= NOW() - INTERVAL '1' hour
    """
)

results = dune.run_query_dataframe(query)
print(f"Median gas fee: {results['median_gwei'].iloc[0]:.2f} Gwei")
```

### Example 2: Use Existing Query

If you've already created a query on Dune's website:

```python
from dune_client import DuneClient

dune = DuneClient("YOUR_API_KEY")

# Replace 1234567 with your actual query ID from Dune
query_id = 1234567
results = dune.run_query_dataframe(query_id)
print(results)
```

### Example 3: Parameterized Query

```python
from dune_client import DuneClient
from dune_client.query import QueryBase
from dune_client.types import QueryParameter

dune = DuneClient("YOUR_API_KEY")

# Query with {{days}} parameter
query = QueryBase(
    query_id=1234567,  # Your query ID
    params=[
        QueryParameter.number_type(name="days", value=7),
    ]
)

results = dune.run_query_dataframe(query)
print(results)
```

### Example 4: Time Series Data

```python
query = QueryBase(
    query_sql="""
    SELECT
        DATE_TRUNC('hour', block_time) as hour,
        approx_percentile(gas_used * gas_price / 1e9, 0.5) as median_gwei,
        COUNT(*) as tx_count
    FROM ethereum.transactions
    WHERE block_time >= NOW() - INTERVAL '7' day
    GROUP BY 1
    ORDER BY 1
    """
)

df = dune.run_query_dataframe(query)

# Now you can plot this with matplotlib/pandas
import matplotlib.pyplot as plt
df.plot(x='hour', y='median_gwei')
plt.show()
```

---

## Gas Fee Formulas

### Pre-EIP-1559 (Legacy)
```sql
gas_fee_wei = gas_used * gas_price
gas_fee_gwei = gas_used * gas_price / 1e9
gas_fee_eth = gas_used * gas_price / 1e18
```

### Post-EIP-1559 (Type 2)
```sql
gas_fee_wei = gas_used * (base_fee_per_gas + priority_fee_per_gas)
gas_fee_gwei = gas_used * (base_fee_per_gas + priority_fee_per_gas) / 1e9
gas_fee_eth = gas_used * (base_fee_per_gas + priority_fee_per_gas) / 1e18
```

### Combined Query (Both Types)
```sql
SELECT
    CASE
        WHEN type = 'Legacy' OR type IS NULL THEN
            gas_used * gas_price / 1e9
        ELSE
            gas_used * (base_fee_per_gas + priority_fee_per_gas) / 1e9
    END as gas_fee_gwei
FROM ethereum.transactions
```

---

## Useful Queries

### 1. Current Gas Prices (Last Hour)

```sql
SELECT
    approx_percentile(gas_price / 1e9, 0.1) as p10_gwei,
    approx_percentile(gas_price / 1e9, 0.5) as median_gwei,
    approx_percentile(gas_price / 1e9, 0.9) as p90_gwei
FROM ethereum.transactions
WHERE block_time >= NOW() - INTERVAL '1' hour
```

### 2. Gas Fees by Day

```sql
SELECT
    DATE_TRUNC('day', block_time) as day,
    approx_percentile(gas_used * gas_price / 1e9, 0.5) as median_gas_fee_gwei,
    SUM(gas_used * gas_price / 1e18) as total_fees_eth,
    COUNT(*) as tx_count
FROM ethereum.transactions
WHERE block_time >= NOW() - INTERVAL '30' day
GROUP BY 1
ORDER BY 1 DESC
```

### 3. EIP-1559 Base Fee vs Priority Fee

```sql
SELECT
    DATE_TRUNC('hour', block_time) as hour,
    approx_percentile(base_fee_per_gas / 1e9, 0.5) as median_base_fee,
    approx_percentile(priority_fee_per_gas / 1e9, 0.5) as median_priority_fee,
    approx_percentile((base_fee_per_gas + priority_fee_per_gas) / 1e9, 0.5) as median_total
FROM ethereum.transactions
WHERE block_time >= NOW() - INTERVAL '24' hour
    AND type = 'DynamicFee'
GROUP BY 1
ORDER BY 1 DESC
```

### 4. Gas Fees by Contract

```sql
SELECT
    "to" as contract_address,
    COUNT(*) as tx_count,
    approx_percentile(gas_used * gas_price / 1e18, 0.5) as median_fee_eth,
    SUM(gas_used * gas_price / 1e18) as total_fees_eth
FROM ethereum.transactions
WHERE block_time >= NOW() - INTERVAL '7' day
    AND "to" IS NOT NULL
GROUP BY 1
HAVING COUNT(*) > 100
ORDER BY total_fees_eth DESC
LIMIT 20
```

---

## API Methods

### `run_query(query_id)`
Execute a query by ID and return raw results.

```python
results = dune.run_query(query_id=1234567)
```

### `run_query_dataframe(query)`
Execute a query and return pandas DataFrame.

```python
df = dune.run_query_dataframe(query)
```

### `get_latest_result(query_id)`
Get cached results without re-executing.

```python
results = dune.get_latest_result(query_id=1234567)
```

### `refresh(query_id)`
Refresh an existing query.

```python
results = dune.refresh(query_id=1234567)
```

---

## Tips & Best Practices

1. **Use Time Filters**: Always filter by `block_time` to improve query performance
   ```sql
   WHERE block_time >= NOW() - INTERVAL '7' day
   ```

2. **Use Approximate Functions**: For large datasets, use `approx_percentile()` instead of `percentile_cont()`

3. **Cache Results**: Use `get_latest_result()` if you don't need real-time data

4. **Batch Queries**: Group multiple metrics in one query instead of multiple API calls

5. **Handle Rate Limits**: The free tier has rate limits; add delays between requests if needed
   ```python
   import time
   time.sleep(1)  # Wait 1 second between requests
   ```

6. **Use Parameters**: Make queries reusable with parameters
   ```sql
   WHERE block_time >= NOW() - INTERVAL '{{days}}' day
   ```

---

## Error Handling

```python
from dune_client import DuneClient
from dune_client.query import QueryBase

dune = DuneClient("YOUR_API_KEY")

try:
    query = QueryBase(query_sql="SELECT * FROM ethereum.transactions LIMIT 10")
    results = dune.run_query_dataframe(query)
    print(results)
except Exception as e:
    print(f"Error executing query: {e}")
```

---

## Resources

- **Dune API Docs**: https://docs.dune.com/api-reference/
- **Dune Python Client**: https://github.com/duneanalytics/dune-client
- **Dune Community**: https://discord.gg/dunecom
- **Ethereum Docs**: https://docs.dune.com/data-tables/raw/evm/ethereum

---

## Common Issues

### Issue: "Invalid API Key"
- Check your API key is correct
- Ensure it's properly set in environment variable
- Verify the key has not expired

### Issue: "Query timeout"
- Reduce the time range in your query
- Use `approx_percentile()` instead of exact calculations
- Add more specific WHERE filters

### Issue: "Rate limit exceeded"
- Add delays between requests
- Upgrade to a paid plan for higher limits
- Cache results when possible

---

## Next Steps

1. Create your first query on [Dune.com](https://dune.com)
2. Get the query ID from the URL
3. Use the API to fetch results programmatically
4. Build dashboards or automated alerts
