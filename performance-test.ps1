# Performance Testing Script for Observability APIs
# PowerShell script for load testing and performance analysis

param(
    [int]$ConcurrentUsers = 10,
    [int]$TestDurationMinutes = 2,
    [string]$TargetUrl = "http://localhost:5000",
    [string]$TestType = "mixed"
)

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Performance Testing Script" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Target URL: $TargetUrl" -ForegroundColor Yellow
Write-Host "Concurrent Users: $ConcurrentUsers" -ForegroundColor Yellow
Write-Host "Test Duration: $TestDurationMinutes minutes" -ForegroundColor Yellow
Write-Host "Test Type: $TestType" -ForegroundColor Yellow
Write-Host ""

$results = @()
$startTime = Get-Date
$endTime = $startTime.AddMinutes($TestDurationMinutes)

function Invoke-ApiCall {
    param(
        [string]$Method,
        [string]$Endpoint,
        [string]$Description
    )
    
    $requestStart = Get-Date
    try {
        if ($Method -eq "GET") {
            $response = Invoke-WebRequest -Uri "$TargetUrl$Endpoint" -Method GET -UseBasicParsing -TimeoutSec 30
        } else {
            $response = Invoke-WebRequest -Uri "$TargetUrl$Endpoint" -Method POST -UseBasicParsing -TimeoutSec 30
        }
        
        $requestEnd = Get-Date
        $duration = ($requestEnd - $requestStart).TotalMilliseconds
        
        return @{
            Success = $true
            StatusCode = $response.StatusCode
            Duration = $duration
            Description = $Description
            Timestamp = $requestStart
        }
    } catch {
        $requestEnd = Get-Date
        $duration = ($requestEnd - $requestStart).TotalMilliseconds
        
        return @{
            Success = $false
            StatusCode = if ($_.Exception.Response) { $_.Exception.Response.StatusCode.value__ } else { 0 }
            Duration = $duration
            Description = $Description
            Error = $_.Exception.Message
            Timestamp = $requestStart
        }
    }
}

function Test-MixedWorkload {
    $endpoints = @(
        @{ Method = "GET"; Endpoint = "/gateway/products/1"; Description = "Gateway Product" },
        @{ Method = "GET"; Endpoint = "/gateway/products/2?delayMs=100"; Description = "Gateway Product with delay" },
        @{ Method = "POST"; Endpoint = "/gateway/orders"; Description = "Gateway Order" },
        @{ Method = "POST"; Endpoint = "/gateway/orders?failureMode=transient"; Description = "Gateway Order with transient failure" }
    )
    
    $endpoint = $endpoints[(Get-Random -Maximum $endpoints.Length)]
    return Invoke-ApiCall -Method $endpoint.Method -Endpoint $endpoint.Endpoint -Description $endpoint.Description
}

function Test-LatencyStress {
    $delays = @(500, 1000, 2000, 3000)
    $delay = $delays[(Get-Random -Maximum $delays.Length)]
    $productId = Get-Random -Minimum 100 -Maximum 999
    
    return Invoke-ApiCall -Method "GET" -Endpoint "/gateway/products/$productId`?delayMs=$delay" -Description "Latency stress test ($delay ms)"
}

function Test-ErrorStress {
    $failureModes = @("none", "transient", "persistent")
    $failureMode = $failureModes[(Get-Random -Maximum $failureModes.Length)]
    
    return Invoke-ApiCall -Method "POST" -Endpoint "/gateway/orders?failureMode=$failureMode" -Description "Error stress test ($failureMode)"
}

Write-Host "Starting performance test..." -ForegroundColor Green
Write-Host "Press Ctrl+C to stop early" -ForegroundColor Yellow
Write-Host ""

# Create jobs for concurrent users
$jobs = @()
for ($i = 1; $i -le $ConcurrentUsers; $i++) {
    $job = Start-Job -ScriptBlock {
        param($TargetUrl, $EndTime, $TestType)
        
        $results = @()
        
        while ((Get-Date) -lt $EndTime) {
            switch ($TestType) {
                "mixed" {
                    $endpoints = @(
                        @{ Method = "GET"; Endpoint = "/gateway/products/$((Get-Random -Minimum 1 -Maximum 100))"; Description = "Gateway Product" },
                        @{ Method = "GET"; Endpoint = "/gateway/products/$((Get-Random -Minimum 1 -Maximum 100))?delayMs=$((Get-Random -Minimum 100 -Maximum 500))"; Description = "Gateway Product with delay" },
                        @{ Method = "POST"; Endpoint = "/gateway/orders"; Description = "Gateway Order" },
                        @{ Method = "POST"; Endpoint = "/gateway/orders?failureMode=transient"; Description = "Gateway Order with transient failure" }
                    )
                    $endpoint = $endpoints[(Get-Random -Maximum $endpoints.Length)]
                    break
                }
                "latency" {
                    $delay = Get-Random -Minimum 500 -Maximum 3000
                    $productId = Get-Random -Minimum 100 -Maximum 999
                    $endpoint = @{ Method = "GET"; Endpoint = "/gateway/products/$productId`?delayMs=$delay"; Description = "Latency stress ($delay ms)" }
                    break
                }
                "error" {
                    $failureModes = @("none", "transient", "persistent")
                    $failureMode = $failureModes[(Get-Random -Maximum $failureModes.Length)]
                    $endpoint = @{ Method = "POST"; Endpoint = "/gateway/orders?failureMode=$failureMode"; Description = "Error stress ($failureMode)" }
                    break
                }
            }
            
            $requestStart = Get-Date
            try {
                if ($endpoint.Method -eq "GET") {
                    $response = Invoke-WebRequest -Uri "$TargetUrl$($endpoint.Endpoint)" -Method GET -UseBasicParsing -TimeoutSec 30
                } else {
                    $response = Invoke-WebRequest -Uri "$TargetUrl$($endpoint.Endpoint)" -Method POST -UseBasicParsing -TimeoutSec 30
                }
                
                $requestEnd = Get-Date
                $duration = ($requestEnd - $requestStart).TotalMilliseconds
                
                $results += @{
                    Success = $true
                    StatusCode = $response.StatusCode
                    Duration = $duration
                    Description = $endpoint.Description
                    Timestamp = $requestStart
                }
            } catch {
                $requestEnd = Get-Date
                $duration = ($requestEnd - $requestStart).TotalMilliseconds
                
                $results += @{
                    Success = $false
                    StatusCode = if ($_.Exception.Response) { $_.Exception.Response.StatusCode.value__ } else { 0 }
                    Duration = $duration
                    Description = $endpoint.Description
                    Error = $_.Exception.Message
                    Timestamp = $requestStart
                }
            }
            
            Start-Sleep -Milliseconds (Get-Random -Minimum 100 -Maximum 1000)
        }
        
        return $results
    } -ArgumentList $TargetUrl, $endTime, $TestType
    
    $jobs += $job
    Write-Host "Started user $i" -ForegroundColor Gray
}

# Monitor progress
$progressCount = 0
while ((Get-Date) -lt $endTime) {
    $progressCount++
    if ($progressCount % 10 -eq 0) {
        $elapsed = ((Get-Date) - $startTime).TotalMinutes
        $remaining = ($endTime - (Get-Date)).TotalMinutes
        Write-Host "Elapsed: $([math]::Round($elapsed, 1)) min, Remaining: $([math]::Round($remaining, 1)) min" -ForegroundColor Cyan
    }
    Start-Sleep -Seconds 1
}

Write-Host ""
Write-Host "Test completed. Collecting results..." -ForegroundColor Green

# Collect results from all jobs
$allResults = @()
foreach ($job in $jobs) {
    $jobResults = Receive-Job -Job $job -Wait
    $allResults += $jobResults
    Remove-Job -Job $job
}

Write-Host "Collected $($allResults.Count) total requests" -ForegroundColor Yellow
Write-Host ""

# Analysis
$successfulRequests = $allResults | Where-Object { $_.Success -eq $true }
$failedRequests = $allResults | Where-Object { $_.Success -eq $false }

$successRate = if ($allResults.Count -gt 0) { ($successfulRequests.Count / $allResults.Count) * 100 } else { 0 }
$avgResponseTime = if ($successfulRequests.Count -gt 0) { ($successfulRequests | Measure-Object -Property Duration -Average).Average } else { 0 }
$maxResponseTime = if ($successfulRequests.Count -gt 0) { ($successfulRequests | Measure-Object -Property Duration -Maximum).Maximum } else { 0 }
$minResponseTime = if ($successfulRequests.Count -gt 0) { ($successfulRequests | Measure-Object -Property Duration -Minimum).Minimum } else { 0 }

# Calculate percentiles
if ($successfulRequests.Count -gt 0) {
    $sortedDurations = $successfulRequests | Sort-Object Duration | Select-Object -ExpandProperty Duration
    $p50 = $sortedDurations[[math]::Floor($sortedDurations.Count * 0.5)]
    $p90 = $sortedDurations[[math]::Floor($sortedDurations.Count * 0.9)]
    $p95 = $sortedDurations[[math]::Floor($sortedDurations.Count * 0.95)]
    $p99 = $sortedDurations[[math]::Floor($sortedDurations.Count * 0.99)]
} else {
    $p50 = $p90 = $p95 = $p99 = 0
}

$throughput = $allResults.Count / $TestDurationMinutes

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "PERFORMANCE TEST RESULTS" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Total Requests: $($allResults.Count)" -ForegroundColor White
Write-Host "Successful Requests: $($successfulRequests.Count)" -ForegroundColor Green
Write-Host "Failed Requests: $($failedRequests.Count)" -ForegroundColor Red
Write-Host "Success Rate: $([math]::Round($successRate, 2))%" -ForegroundColor $(if ($successRate -gt 95) { "Green" } elseif ($successRate -gt 90) { "Yellow" } else { "Red" })
Write-Host ""
Write-Host "Response Times (ms):" -ForegroundColor Yellow
Write-Host "  Average: $([math]::Round($avgResponseTime, 2))" -ForegroundColor White
Write-Host "  Minimum: $([math]::Round($minResponseTime, 2))" -ForegroundColor White
Write-Host "  Maximum: $([math]::Round($maxResponseTime, 2))" -ForegroundColor White
Write-Host "  50th Percentile: $([math]::Round($p50, 2))" -ForegroundColor White
Write-Host "  90th Percentile: $([math]::Round($p90, 2))" -ForegroundColor White
Write-Host "  95th Percentile: $([math]::Round($p95, 2))" -ForegroundColor White
Write-Host "  99th Percentile: $([math]::Round($p99, 2))" -ForegroundColor White
Write-Host ""
Write-Host "Throughput: $([math]::Round($throughput, 2)) requests/minute" -ForegroundColor Magenta
Write-Host ""

# Status Code Distribution
$statusCodes = $allResults | Group-Object -Property StatusCode
Write-Host "Status Code Distribution:" -ForegroundColor Yellow
foreach ($group in $statusCodes) {
    $percentage = ($group.Count / $allResults.Count) * 100
    Write-Host "  $($group.Name): $($group.Count) ($([math]::Round($percentage, 1))%)" -ForegroundColor White
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Test completed successfully!" -ForegroundColor Green
Write-Host "Check Application Insights for detailed metrics" -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Cyan