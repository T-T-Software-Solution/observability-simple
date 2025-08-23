# Observability Testing Scenarios Script
# PowerShell script to test various scenarios

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Observability Testing Scenarios" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$downstreamUrl = "http://localhost:5001"
$upstreamUrl = "http://localhost:5000"

function Test-Endpoint {
    param(
        [string]$Name,
        [string]$Method,
        [string]$Url,
        [string]$ExpectedStatus
    )
    
    Write-Host "Testing: $Name" -ForegroundColor Yellow
    try {
        if ($Method -eq "GET") {
            $response = Invoke-WebRequest -Uri $Url -Method GET -UseBasicParsing
        } else {
            $response = Invoke-WebRequest -Uri $Url -Method POST -UseBasicParsing
        }
        
        if ($response.StatusCode -eq $ExpectedStatus -or $ExpectedStatus -eq "Any") {
            Write-Host "  ✓ Success: Status $($response.StatusCode)" -ForegroundColor Green
            if ($response.Content) {
                $json = $response.Content | ConvertFrom-Json
                Write-Host "  Response: $($json | ConvertTo-Json -Compress)" -ForegroundColor Gray
            }
        } else {
            Write-Host "  ✗ Failed: Expected $ExpectedStatus, got $($response.StatusCode)" -ForegroundColor Red
        }
    } catch {
        if ($_.Exception.Response) {
            $statusCode = $_.Exception.Response.StatusCode.value__
            if ($statusCode -eq $ExpectedStatus) {
                Write-Host "  ✓ Success: Got expected error status $statusCode" -ForegroundColor Green
            } else {
                Write-Host "  ✗ Failed: Status $statusCode - $_" -ForegroundColor Red
            }
        } else {
            Write-Host "  ✗ Failed: $_" -ForegroundColor Red
        }
    }
    Write-Host ""
}

# 1. Health Check Tests
Write-Host "1. HEALTH CHECK TESTS" -ForegroundColor Magenta
Write-Host "=====================" -ForegroundColor Magenta
Test-Endpoint -Name "Downstream Health" -Method "GET" -Url "$downstreamUrl/health" -ExpectedStatus 200
Test-Endpoint -Name "Upstream Health" -Method "GET" -Url "$upstreamUrl/health" -ExpectedStatus 200

# 2. Latency Tests
Write-Host "2. LATENCY SIMULATION TESTS" -ForegroundColor Magenta
Write-Host "============================" -ForegroundColor Magenta
Test-Endpoint -Name "Product without delay" -Method "GET" -Url "$downstreamUrl/products/100" -ExpectedStatus 200
Test-Endpoint -Name "Product with 500ms delay" -Method "GET" -Url "$downstreamUrl/products/101?delayMs=500" -ExpectedStatus 200
Test-Endpoint -Name "Gateway product with 1000ms delay" -Method "GET" -Url "$upstreamUrl/gateway/products/102?delayMs=1000" -ExpectedStatus 200

# 3. Error Simulation Tests
Write-Host "3. ERROR SIMULATION TESTS" -ForegroundColor Magenta
Write-Host "==========================" -ForegroundColor Magenta
Test-Endpoint -Name "Order with no failure" -Method "POST" -Url "$downstreamUrl/orders" -ExpectedStatus 201

Write-Host "Testing transient failures (50% chance)..." -ForegroundColor Yellow
$successCount = 0
$failureCount = 0
for ($i = 1; $i -le 10; $i++) {
    try {
        $response = Invoke-WebRequest -Uri "$downstreamUrl/orders?failureMode=transient" -Method POST -UseBasicParsing
        $successCount++
        Write-Host "  Attempt $i`: Success" -ForegroundColor Green -NoNewline
    } catch {
        $failureCount++
        Write-Host "  Attempt $i`: Failed" -ForegroundColor Red -NoNewline
    }
    if ($i % 5 -eq 0) { Write-Host "" }
}
Write-Host ""
Write-Host "  Transient Results: $successCount successes, $failureCount failures out of 10 attempts" -ForegroundColor Cyan
Write-Host ""

Test-Endpoint -Name "Order with persistent failure" -Method "POST" -Url "$downstreamUrl/orders?failureMode=persistent" -ExpectedStatus 500

# 4. Gateway Error Handling Tests
Write-Host "4. GATEWAY ERROR HANDLING TESTS" -ForegroundColor Magenta
Write-Host "================================" -ForegroundColor Magenta
Test-Endpoint -Name "Gateway order with no failure" -Method "POST" -Url "$upstreamUrl/gateway/orders" -ExpectedStatus 201
Test-Endpoint -Name "Gateway order with persistent failure" -Method "POST" -Url "$upstreamUrl/gateway/orders?failureMode=persistent" -ExpectedStatus 502

# 5. Resource Pressure Tests
Write-Host "5. RESOURCE PRESSURE TESTS" -ForegroundColor Magenta
Write-Host "===========================" -ForegroundColor Magenta
Test-Endpoint -Name "CPU pressure (light)" -Method "GET" -Url "$downstreamUrl/pressure/cpu?iterations=100000" -ExpectedStatus 200
Test-Endpoint -Name "Memory pressure (10MB)" -Method "GET" -Url "$downstreamUrl/pressure/memory?mbToAllocate=10" -ExpectedStatus 200

# 6. End-to-End Tracing Test
Write-Host "6. END-TO-END TRACING TEST" -ForegroundColor Magenta
Write-Host "===========================" -ForegroundColor Magenta
Write-Host "Simulating a complex scenario with multiple calls..." -ForegroundColor Yellow

# Make several correlated calls
$productIds = 201, 202, 203
foreach ($id in $productIds) {
    Test-Endpoint -Name "Gateway Product $id with delay" -Method "GET" -Url "$upstreamUrl/gateway/products/$id`?delayMs=100" -ExpectedStatus 200
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Testing Complete!" -ForegroundColor Cyan
Write-Host "Check Application Insights for:" -ForegroundColor Yellow
Write-Host "  - End-to-end transaction details" -ForegroundColor White
Write-Host "  - Performance metrics" -ForegroundColor White
Write-Host "  - Error traces and exceptions" -ForegroundColor White
Write-Host "  - Dependency calls between services" -ForegroundColor White
Write-Host "========================================" -ForegroundColor Cyan