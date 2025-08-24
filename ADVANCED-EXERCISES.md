# Advanced Observability Exercises

These exercises simulate real production issues that require detective work using Azure Application Insights. Each bug is hidden and only manifests under specific conditions.

## Prerequisites

1. Both APIs running locally or in Azure
2. Azure Application Insights configured
3. Bug features enabled via environment variables

## Enabling Advanced Bugs

Set these environment variables in your Downstream API to enable specific bugs:

```bash
# Enable all bugs for maximum challenge
export ADVANCED_BUG_HARDCODED_ID=true
export ADVANCED_BUG_ORDER_RANGE=true
export ADVANCED_BUG_MEMORY_LEAK=true
export ADVANCED_BUG_THREAD_POOL=true
export ADVANCED_BUG_CACHE_POISON=true
export ADVANCED_BUG_CPU_SPIKE=true

# Or in appsettings.json
{
  "ADVANCED_BUG_HARDCODED_ID": true,
  "ADVANCED_BUG_ORDER_RANGE": true,
  "ADVANCED_BUG_MEMORY_LEAK": true,
  "ADVANCED_BUG_THREAD_POOL": true,
  "ADVANCED_BUG_CACHE_POISON": true,
  "ADVANCED_BUG_CPU_SPIKE": true
}
```

## Running the Bug Hunter

Use the cross-platform C# test data generator to trigger the bugs:

```powershell
# Build the test data generator
cd test-data-generator
dotnet build

# Run all tests
dotnet run -- http://localhost:5000 all

# Run specific test type
dotnet run -- http://localhost:5000 random   # Test random product IDs
dotnet run -- http://localhost:5000 range    # Test order ranges
dotnet run -- http://localhost:5000 prime    # Test prime numbers
dotnet run -- http://localhost:5000 load     # Test load patterns
dotnet run -- http://localhost:5000 palindrome # Test palindrome IDs
dotnet run -- http://localhost:5000 edge     # Test edge cases
```

---

## Exercise 1: The Mysterious Slow Products 🐌

### Scenario
**Customer Report:** "Some product pages load instantly, but others take forever (3+ seconds). It seems random but consistent - the same products are always slow."

### Your Mission
Find which product IDs are experiencing performance issues and identify the pattern.

### What You'll See in Logs
- "Applying enhanced validation for product {ProductId}"
- "Legacy system validation initiated"
- "Legacy validation completed"

These logs appear normal - legacy systems are often slow. But why only certain products?

### Test Generation
```powershell
# Run the random product ID test
cd test-data-generator
dotnet run -- http://localhost:5000 random
```

### Investigation Steps
1. Run the test script and observe which IDs are slow
2. Use Application Insights to query slow requests:
   ```kql
   requests
   | where name contains "products"
   | where duration > 2000
   | project productId = tostring(customDimensions.ProductId), duration
   | summarize count() by productId
   ```
3. Look for patterns in the slow IDs

### Hints (reveal progressively)
<details>
<summary>Hint 1</summary>
Look at the actual ID numbers that are slow. Do they have anything in common?
</details>

<details>
<summary>Hint 2</summary>
Consider cultural or superstitious significance of certain numbers...
</details>

<details>
<summary>Solution</summary>
The bug: Products with "unlucky" IDs (13, 42, 99, 666, 1337, 2024, 9999) have a hardcoded 3-second delay. This simulates legacy code with superstitious developers or special handling for demo/test IDs.
</details>

---

## Exercise 2: The Order Processing Anomaly 📊

### Scenario
**Customer Report:** "We're seeing a huge spike in order failures, but only for certain order numbers. Customer service is overwhelmed with complaints about orders in the 1000s range."

### Your Mission
Identify which order ID ranges are failing and determine the failure pattern.

### What You'll See in Logs
- "Order validation failed for {OrderId}: Database constraint violation"
- "Order {OrderId} failed validation check against table ORDER_CONSTRAINTS"
- Exception: "Foreign key constraint FK_ORDER_VALIDATION failed"

Looks like a database issue, but why only specific order ranges?

### Test Generation
```powershell
# Run the order range test
cd test-data-generator
dotnet run -- http://localhost:5000 range
```

### Investigation Steps
1. Run the test script to generate orders from 900-1200
2. Query Application Insights for failures:
   ```kql
   exceptions
   | where message contains "BR-1099"
   | extend orderId = toint(customDimensions.OrderId)
   | summarize failureCount = count() by bin(orderId, 10)
   | order by orderId
   ```
3. Calculate failure rates by range

### Hints (reveal progressively)
<details>
<summary>Hint 1</summary>
Focus on orders between 1000-1099. What's the failure rate in this range?
</details>

<details>
<summary>Hint 2</summary>
The error message mentions "BR-1099" - this might be a business rule related to the ID range.
</details>

<details>
<summary>Solution</summary>
The bug: Orders with IDs 1000-1099 fail 90% of the time due to a "business rule BR-1099". This simulates a database constraint or business logic that treats this range as reserved/special.
</details>

---

## Exercise 3: The Memory Leak Mystery 💾

### Scenario
**Customer Report:** "The API server memory usage keeps growing throughout the day. We have to restart it every night. The leak seems to correlate with certain product views."

### Your Mission
Find which product IDs are causing memory leaks.

### What You'll See in Logs
- "Initializing product cache for {ProductId}"
- "Product {ProductId} cached for performance optimization"

Normal caching behavior, right? But why isn't memory being released?

### Test Generation
```powershell
# Run the prime number test
cd test-data-generator
dotnet run -- http://localhost:5000 prime
```

### Investigation Steps
1. Monitor memory metrics while running the test
2. Query for patterns:
   ```kql
   customMetrics
   | where name contains "Memory"
   | summarize avg(value) by bin(timestamp, 1m)
   | render timechart
   ```
3. Correlate memory spikes with specific product IDs

### Hints (reveal progressively)
<details>
<summary>Hint 1</summary>
Test both prime and non-prime product IDs. Compare the performance.
</details>

<details>
<summary>Hint 2</summary>
Prime numbers are special in mathematics. Maybe they're special in the code too?
</details>

<details>
<summary>Solution</summary>
The bug: Products with prime number IDs leak 5MB of memory per unique prime ID accessed. The memory is never released, simulating a cache that doesn't evict prime number entries.
</details>

---

## Exercise 4: The Periodic Performance Problem ⏰

### Scenario
**Customer Report:** "Every few requests, the system freezes for 5 seconds. It's killing our user experience during peak hours."

### Your Mission
Identify the pattern causing periodic slowdowns.

### What You'll See in Logs
- "Starting scheduled maintenance task"
- "Synchronous database cleanup initiated for request {RequestNumber}"
- "Maintenance task completed"

Maintenance is normal, but why is it running during peak hours and blocking requests?

### Test Generation
```powershell
# Run the load pattern test
cd test-data-generator
dotnet run -- http://localhost:5000 load
```

### Investigation Steps
1. Send 50 rapid requests and observe the pattern
2. Query for slow requests:
   ```kql
   requests
   | where duration > 3000
   | extend requestNumber = toint(customDimensions.RequestNumber)
   | project requestNumber, duration
   | order by requestNumber
   ```
3. Look for mathematical patterns in request numbers

### Hints (reveal progressively)
<details>
<summary>Hint 1</summary>
Count the request numbers that are slow. Is there a pattern like every Nth request?
</details>

<details>
<summary>Hint 2</summary>
Check if slow request positions are divisible by a specific number.
</details>

<details>
<summary>Solution</summary>
The bug: Every 10th request blocks a thread for 5 seconds, simulating thread pool exhaustion. This represents a common production issue where periodic batch processing interferes with request handling.
</details>

---

## Exercise 5: The Cache Corruption Catastrophe 🔥

### Scenario
**Customer Report:** "Sometimes all products show as 'CORRUPTED_DATA' with price -1. It fixes itself after about 30 seconds, but customers are panicking."

### Your Mission
Find what triggers cache corruption.

### What You'll See in Logs
- "Cache miss for product {ProductId}, loading from database"
- "Unexpected data format for product {ProductId}, using fallback values"

Seems like a data format issue, but why does it affect ALL subsequent requests?

### Test Generation
```powershell
# Run the edge case test
cd test-data-generator
dotnet run -- http://localhost:5000 edge
```

### Investigation Steps
1. Test edge cases (0, negative, very large IDs)
2. Monitor subsequent normal requests
3. Query for corrupted responses:
   ```kql
   requests
   | where responseCode == 200
   | extend responseBody = tostring(customDimensions.ResponseBody)
   | where responseBody contains "CORRUPTED_DATA"
   | project timestamp, productId = customDimensions.ProductId
   ```

### Hints (reveal progressively)
<details>
<summary>Hint 1</summary>
What happens when you request product ID 0 or negative IDs?
</details>

<details>
<summary>Hint 2</summary>
After requesting an invalid ID, immediately request a valid product. What do you see?
</details>

<details>
<summary>Solution</summary>
The bug: Product IDs ≤ 0 poison the cache for 30 seconds, causing all subsequent requests to return corrupted data. This simulates a cache poisoning vulnerability where invalid input corrupts shared state.
</details>

---

## Exercise 6: The CPU Spike Syndrome 🔥

### Scenario
**Customer Report:** "Our monitoring shows massive CPU spikes that max out the server for several seconds. It happens with certain products but we can't identify the pattern. The server becomes unresponsive during these spikes."

### Your Mission
Identify which product IDs trigger extreme CPU usage and find the pattern.

### What You'll See in Logs
- "Calculating recommendations for product {ProductId}"
- "Running similarity analysis for product {ProductId}"
- "Recommendation calculation completed in {ElapsedMs}ms"

Recommendation engines can be CPU-intensive, but why are some products taking 10-100x longer?

### Test Generation
```powershell
# Run the palindrome test
cd test-data-generator
dotnet run -- http://localhost:5000 palindrome

# Or test specific palindrome IDs
Invoke-RestMethod http://localhost:5001/products/121
Invoke-RestMethod http://localhost:5001/products/1221
Invoke-RestMethod http://localhost:5001/products/12321
```

### Investigation Steps
1. Monitor CPU metrics while testing various product IDs
2. Query Application Insights for high-duration requests:
   ```kql
   requests
   | where name contains "products"
   | where duration > 5000
   | extend productId = tostring(customDimensions.ProductId)
   | project productId, duration
   | order by duration desc
   ```
3. Look for patterns in the product IDs that cause spikes
4. Check performance counters during the spike:
   ```kql
   performanceCounters
   | where name == "% Processor Time"
   | where value > 80
   | summarize max(value) by bin(timestamp, 10s)
   | render timechart
   ```

### Hints (reveal progressively)
<details>
<summary>Hint 1</summary>
Test product IDs that read the same forwards and backwards (like 121, 1001, 12321).
</details>

<details>
<summary>Hint 2</summary>
Consider mathematical or linguistic properties of the numbers. What do we call numbers that are the same when reversed?
</details>

<details>
<summary>Solution</summary>
The bug: Products with palindrome IDs (numbers that read the same forwards and backwards like 121, 131, 1221, 12321) trigger a CPU-intensive calculation that performs 50 million complex mathematical operations. This simulates inefficient algorithm implementation or unnecessary computation for special cases.

Common palindrome IDs to test:
- Single digit: 1-9
- Two digits: 11, 22, 33, 44, 55, 66, 77, 88, 99
- Three digits: 101, 111, 121, 131, 141, 151, 161, 171, 181, 191, 202, 212, etc.
- Four digits: 1001, 1111, 1221, 1331, 1441, 1551, 1661, 1771, 1881, 1991, 2002, etc.
</details>

---

## 🔍 Production-Like Bug Hunting

### The Realistic Challenge

**No obvious bug indicators** - just like real production! You won't find:
- No "BUG DETECTED" messages
- No "BugTriggered" events  
- No explicit code locations
- No bug type labels

### What You WILL Find

Just like in production, you'll see:
- Normal business logic logs ("Applying enhanced validation", "Starting maintenance task")
- Performance metrics (latency, CPU, memory)
- Error patterns and exceptions
- Request correlations

### How to Hunt Bugs Like a Pro

1. **Generate Traffic**: Use the test data generator to create load
2. **Observe Patterns**: Look for anomalies in Application Insights
3. **Correlate Symptoms**: Match performance issues with request patterns
4. **Form Hypotheses**: Use the data to guess what's happening
5. **Validate Theory**: Test specific scenarios to confirm

### Detective Work Required

| Symptom | What to Look For | Investigation Approach |
|---------|------------------|------------------------|
| Slow requests | Duration > 2000ms | Group by ProductId, look for patterns |
| High failure rate | Status 500/503 | Analyze by OrderId ranges |
| Memory growth | Increasing memory metrics | Correlate with specific ProductIds |
| CPU spikes | CPU > 80% | Match with request timings |
| Data corruption | Unexpected response values | Track when corruption starts |

---

## KQL Queries for Realistic Investigation

### Find Slow Products (No Bug Labels!)
```kql
requests
| where name contains "products"
| where duration > 2000
| extend ProductId = tostring(customDimensions.ProductId)
| summarize 
    AvgDuration = avg(duration),
    Count = count(),
    P95Duration = percentile(duration, 95)
    by ProductId
| where Count > 2
| order by AvgDuration desc
// Look for patterns in the slow ProductIds - what do they have in common?
```

### Analyze Order Failures by Range
```kql
exceptions
| where message contains "constraint" or message contains "validation"
| extend OrderId = toint(customDimensions.OrderId)
| summarize 
    FailureCount = count(),
    FailureRate = count() * 100.0 / 301.0
    by OrderRange = bin(OrderId, 100)
| order by OrderRange
// Which order ranges have unusually high failure rates?
```

### Memory Growth Pattern Detection
```kql
performanceCounters
| where name == "Private Bytes"
| summarize MemoryMB = avg(value/1048576) by bin(timestamp, 1m)
| join kind=inner (
    requests
    | where name contains "products"
    | extend ProductId = toint(customDimensions.ProductId)
    | summarize RequestCount = count() by bin(timestamp, 1m), ProductId
) on timestamp
| order by timestamp
// Does memory growth correlate with specific ProductIds?
```

### Find Request Patterns in Slowdowns
```kql
requests
| where duration > 3000
| serialize
| extend RequestNumber = row_number()
| extend PatternCheck = RequestNumber % 10
| summarize 
    SlowCount = count(),
    AvgDuration = avg(duration)
    by PatternCheck
| order by PatternCheck
// Is there a pattern in which requests are slow?
```

---

## KQL Queries for Investigation

### Find Patterns in Slow Requests
```kql
requests
| where timestamp > ago(1h)
| where duration > 2000
| extend productId = toint(customDimensions.ProductId)
| summarize 
    avgDuration = avg(duration),
    maxDuration = max(duration),
    count = count()
    by productId
| where count > 2
| order by avgDuration desc
```

### Identify Failure Clusters
```kql
exceptions
| where timestamp > ago(1h)
| extend orderId = toint(customDimensions.OrderId)
| summarize failures = count() by bin(orderId, 100)
| render columnchart
```

### Track Memory Growth
```kql
performanceCounters
| where name == "Private Bytes"
| where timestamp > ago(1h)
| summarize memoryMB = avg(value/1048576) by bin(timestamp, 1m)
| render timechart
```

### Detect Thread Pool Issues
```kql
requests
| where timestamp > ago(30m)
| serialize 
| extend requestNumber = row_number()
| where duration > 3000
| project requestNumber, duration
| extend isDivisibleBy10 = (requestNumber % 10 == 0)
| summarize slowCount = count() by isDivisibleBy10
```

---

## Success Criteria

For each exercise, you've succeeded when you can:
1. ✅ Identify the exact condition triggering the bug
2. ✅ Provide evidence from Application Insights
3. ✅ Explain why this pattern would cause issues in production
4. ✅ Suggest a fix or mitigation strategy

## Learning Outcomes

After completing these exercises, you'll understand:
- How to identify patterns in telemetry data
- Common production bug patterns
- The importance of comprehensive monitoring
- How edge cases can affect system stability
- Why load testing with varied inputs is crucial

## Next Steps

1. Try enabling different combinations of bugs
2. Create custom KQL queries to detect these issues automatically
3. Set up Azure Monitor alerts for these patterns
4. Practice explaining findings to non-technical stakeholders
5. Design your own hidden bugs for team training

Remember: In production, these bugs would be much harder to find without proper observability tools!