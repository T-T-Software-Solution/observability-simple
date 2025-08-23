# Simple Azure Load Test - 5 Minutes
param(
    [int]$DurationMinutes = 5,
    [int]$ConcurrentRequests = 8,
    [string]$BaseUrl = "https://observability-upstream.azurewebsites.net"
)

$StartTime = Get-Date
$EndTime = $StartTime.AddMinutes($DurationMinutes)
$TotalRequests = 0
$SuccessfulRequests = 0
$FailedRequests = 0

Write-Host "🚀 Starting Azure Load Test" -ForegroundColor Green
Write-Host "Duration: $DurationMinutes minutes"
Write-Host "Concurrent Requests: $ConcurrentRequests" 
Write-Host "Target: $BaseUrl"
Write-Host "Start Time: $($StartTime.ToString('yyyy-MM-dd HH:mm:ss'))"
Write-Host ""

# Test endpoints
$Endpoints = @(
    "/gateway/products/123",
    "/gateway/products/456?delayMs=500", 
    "/gateway/orders",
    "/health"
)

$Jobs = @()

Write-Host "⚡ Load test running..." -ForegroundColor Green

while ((Get-Date) -lt $EndTime) {
    # Clean up completed jobs
    $CompletedJobs = $Jobs | Where-Object { $_.State -eq "Completed" }
    foreach ($job in $CompletedJobs) {
        $result = Receive-Job -Job $job
        Remove-Job -Job $job
        $TotalRequests++
        if ($result -and $result.Success) {
            $SuccessfulRequests++
        } else {
            $FailedRequests++
        }
    }
    
    # Remove completed jobs
    $Jobs = $Jobs | Where-Object { $_.State -ne "Completed" }
    
    # Start new jobs
    while ($Jobs.Count -lt $ConcurrentRequests) {
        $endpoint = $Endpoints | Get-Random
        $uri = $BaseUrl + $endpoint
        
        $job = Start-Job -ScriptBlock {
            param($uri, $endpoint)
            try {
                if ($endpoint -eq "/gateway/orders") {
                    $response = Invoke-RestMethod -Uri $uri -Method POST -TimeoutSec 10
                } else {
                    $response = Invoke-RestMethod -Uri $uri -Method GET -TimeoutSec 10
                }
                return @{ Success = $true; Endpoint = $endpoint }
            } catch {
                return @{ Success = $false; Error = $_.Exception.Message; Endpoint = $endpoint }
            }
        } -ArgumentList $uri, $endpoint
        
        $Jobs += $job
    }
    
    # Progress update
    $elapsed = (Get-Date) - $StartTime
    if ($TotalRequests % 50 -eq 0 -and $TotalRequests -gt 0) {
        $rps = [math]::Round($TotalRequests / $elapsed.TotalSeconds, 1)
        $successRate = [math]::Round(($SuccessfulRequests / $TotalRequests) * 100, 1)
        Write-Host "Progress: $TotalRequests requests, $rps RPS, $successRate% success" -ForegroundColor Cyan
    }
    
    Start-Sleep -Milliseconds 200
}

# Wait for remaining jobs
Write-Host "Finishing remaining requests..."
$Jobs | Wait-Job | Receive-Job | ForEach-Object { 
    $TotalRequests++
    if ($_.Success) { $SuccessfulRequests++ } else { $FailedRequests++ }
}
$Jobs | Remove-Job

$Duration = (Get-Date) - $StartTime
$RPS = [math]::Round($TotalRequests / $Duration.TotalSeconds, 2)
$SuccessRate = [math]::Round(($SuccessfulRequests / $TotalRequests) * 100, 2)

Write-Host ""
Write-Host "🎯 Load Test Results" -ForegroundColor Green
Write-Host "==================="
Write-Host "Duration: $([math]::Round($Duration.TotalMinutes, 2)) minutes"
Write-Host "Total Requests: $TotalRequests"
Write-Host "Successful: $SuccessfulRequests" -ForegroundColor Green
Write-Host "Failed: $FailedRequests" -ForegroundColor Red
Write-Host "Success Rate: $SuccessRate%"
Write-Host "Average RPS: $RPS"
Write-Host ""
Write-Host "✅ Load test completed! Check Application Insights for telemetry."