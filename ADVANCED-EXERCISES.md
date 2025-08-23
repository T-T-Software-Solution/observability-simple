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

Use the provided test generation scripts to trigger the bugs:

```bash
# PowerShell
./advanced-bug-hunter.ps1 -BaseUrl http://localhost:5000 -TestType all

# Bash
./advanced-bug-hunter.sh http://localhost:5000 all
```

---

## Exercise 1: The Mysterious Slow Products 🐌

### Scenario
**Customer Report:** "Some product pages load instantly, but others take forever (3+ seconds). It seems random but consistent - the same products are always slow."

### Your Mission
Find which product IDs are experiencing performance issues and identify the pattern.

### Test Generation
```bash
# Run the random product ID test
./advanced-bug-hunter.ps1 -TestType random
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

### Test Generation
```bash
# Run the order range test
./advanced-bug-hunter.ps1 -TestType range
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

### Test Generation
```bash
# Run the prime number test
./advanced-bug-hunter.ps1 -TestType prime
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

### Test Generation
```bash
# Run the load pattern test
./advanced-bug-hunter.ps1 -TestType load
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

### Test Generation
```bash
# Run the edge case test
./advanced-bug-hunter.ps1 -TestType edge
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

### Test Generation
```bash
# Run the palindrome test
./advanced-bug-hunter.ps1 -TestType palindrome

# Or test specific palindrome IDs
curl http://localhost:5001/products/121
curl http://localhost:5001/products/1221
curl http://localhost:5001/products/12321
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

## 🔍 Code-Level Bug Hunting

The system now includes **precise code location tracking** that tells you exactly which line of code causes each bug - just like real production systems using only observability data!

### Production-Ready Approach

**No debug endpoints** - just like real production systems! All code location data flows through Application Insights telemetry.

### Enhanced Logging Format

All bug events now log with structured data in Application Insights:
```
🐛 BUG DETECTED: CPU_SPIKE at Program.cs:94 in method <Main>$ - Palindrome ProductId=121
```

### Bug Code Locations

Find these exact locations in telemetry data:

| Bug Type | Code Location | Description |
|----------|---------------|-------------|
| `HARDCODED_DELAY` | Program.cs:78-81 | Unlucky ID delay logic |
| `ORDER_RANGE_FAILURE` | Program.cs:144-147 | Range validation failure |
| `MEMORY_LEAK` | Program.cs:86-89 | Prime number memory leak |
| `THREAD_POOL_EXHAUSTION` | Program.cs:156-159 | Thread blocking logic |
| `CACHE_POISON` | Program.cs:109-112 | Cache corruption trigger |
| `CPU_SPIKE` | Program.cs:94-98 | Palindrome CPU intensive code |

### How to Hunt Bugs

1. **Generate Issues**: Use the bug hunter scripts to trigger problems
2. **Check Application Insights**: Look for `BugTriggered` custom events
3. **Analyze Telemetry**: Use KQL queries to find code locations
4. **Correlate Data**: Match symptoms to exact line numbers

---

## KQL Queries for Code-Level Investigation

### Find Bugs by Code Location
```kql
customEvents
| where name == "BugTriggered"
| extend BugType = tostring(customDimensions.BugType)
| extend CodeLocation = tostring(customDimensions.CodeLocation)
| extend Context = tostring(customDimensions.Context)
| extend LineNumber = toint(customDimensions.LineNumber)
| project timestamp, BugType, CodeLocation, Context, LineNumber
| order by timestamp desc
```

### Identify Code Hotspots
```kql
customEvents
| where name == "BugTriggered"
| extend CodeLocation = tostring(customDimensions.CodeLocation)
| extend MethodName = tostring(customDimensions.MethodName)
| summarize 
    BugCount = count(),
    AvgDuration = avg(toreal(customMeasurements.DurationMs)),
    UniqueBugTypes = dcount(tostring(customDimensions.BugType))
    by CodeLocation, MethodName
| order by BugCount desc
```

### Performance Impact by Line Number
```kql
customEvents
| where name == "BugTriggered"
| extend BugType = tostring(customDimensions.BugType)
| extend CodeLocation = tostring(customDimensions.CodeLocation)
| extend DurationMs = toreal(customMeasurements.DurationMs)
| summarize 
    TotalImpact = sum(DurationMs),
    AvgImpact = avg(DurationMs),
    Count = count()
    by BugType, CodeLocation
| order by TotalImpact desc
```

### Stack Trace Analysis
```kql
customEvents
| where name == "BugTriggered"
| extend StackTrace = tostring(customDimensions.StackTrace)
| extend BugType = tostring(customDimensions.BugType)
| project timestamp, BugType, StackTrace
| where isnotempty(StackTrace)
| take 10
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