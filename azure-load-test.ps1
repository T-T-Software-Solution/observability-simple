# Azure Load Test Script - 5 Minutes Continuous Testing
# Tests various endpoints with realistic load patterns

param(
    [int]$DurationMinutes = 5,
    [int]$ConcurrentRequests = 10,
    [string]$BaseUrl = "https://observability-upstream.azurewebsites.net"
)

$StartTime = Get-Date
$EndTime = $StartTime.AddMinutes($DurationMinutes)
$TotalRequests = 0
$SuccessfulRequests = 0
$FailedRequests = 0
$ResponseTimes = @()

Write-Host "🚀 Starting Azure Load Test" -ForegroundColor Green
Write-Host "Duration: $DurationMinutes minutes" -ForegroundColor Yellow
Write-Host "Concurrent Requests: $ConcurrentRequests" -ForegroundColor Yellow
Write-Host "Target: $BaseUrl" -ForegroundColor Yellow
Write-Host "Start Time: $($StartTime.ToString('yyyy-MM-dd HH:mm:ss'))" -ForegroundColor Yellow
Write-Host ""

# Test endpoints with different patterns
$Endpoints = @(
    @{ Method = "GET"; Url = "/gateway/products/123"; Weight = 40; Description = "Product lookup" }
    @{ Method = "GET"; Url = "/gateway/products/456?delayMs=500"; Weight = 20; Description = "Slow product lookup" }
    @{ Method = "POST"; Url = "/gateway/orders"; Weight = 15; Description = "Normal order" }
    @{ Method = "POST"; Url = "/gateway/orders?failureMode=transient"; Weight = 10; Description = "Transient failure" }
    @{ Method = "GET"; Url = "/health"; Weight = 10; Description = "Health check" }
    @{ Method = "GET"; Url = "/gateway/products/789?delayMs=1000"; Weight = 5; Description = "Very slow lookup" }
)

# Create weighted endpoint list
$WeightedEndpoints = @()
foreach ($endpoint in $Endpoints) {
    for ($i = 0; $i -lt $endpoint.Weight; $i++) {
        $WeightedEndpoints += $endpoint
    }
}

Write-Host "📊 Test Mix:" -ForegroundColor Cyan
foreach ($endpoint in $Endpoints) {
    Write-Host "  $($endpoint.Weight)% - $($endpoint.Method) $($endpoint.Url) ($($endpoint.Description))" -ForegroundColor White
}
Write-Host ""

# Statistics tracking
$Stats = @{}
foreach ($endpoint in $Endpoints) {
    $key = "$($endpoint.Method) $($endpoint.Url)"
    $Stats[$key] = @{ Count = 0; Success = 0; Failed = 0; TotalTime = 0 }
}

# Background job function
$JobScript = {
    param($BaseUrl, $Endpoint, $JobId)
    
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    
    try {
        $uri = $BaseUrl + $Endpoint.Url
        
        if ($Endpoint.Method -eq "POST") {
            $response = Invoke-RestMethod -Uri $uri -Method POST -TimeoutSec 30
        } else {
            $response = Invoke-RestMethod -Uri $uri -Method GET -TimeoutSec 30
        }
        
        $stopwatch.Stop()
        return @{
            Success = $true
            Duration = $stopwatch.ElapsedMilliseconds
            StatusCode = 200
            JobId = $JobId
            Endpoint = "$($Endpoint.Method) $($Endpoint.Url)"
        }
    }
    catch {
        $stopwatch.Stop()
        return @{
            Success = $false
            Duration = $stopwatch.ElapsedMilliseconds
            Error = $_.Exception.Message
            JobId = $JobId
            Endpoint = "$($Endpoint.Method) $($Endpoint.Url)"
        }
    }
}

$Jobs = @()
$JobCounter = 0

Write-Host "⚡ Load test in progress..." -ForegroundColor Green
Write-Host "Press Ctrl+C to stop early" -ForegroundColor Yellow
Write-Host ""

# Main load test loop
while ((Get-Date) -lt $EndTime) {
    try {
        # Clean up completed jobs
        $CompletedJobs = $Jobs | Where-Object { $_.Job.State -eq "Completed" }
        foreach ($completedJob in $CompletedJobs) {
            $result = Receive-Job -Job $completedJob.Job
            Remove-Job -Job $completedJob.Job
            
            $TotalRequests++
            $endpoint = $result.Endpoint
            
            if ($result.Success) {
                $SuccessfulRequests++
                $Stats[$endpoint].Success++
                $ResponseTimes += $result.Duration
                $Stats[$endpoint].TotalTime += $result.Duration
            } else {
                $FailedRequests++
                $Stats[$endpoint].Failed++
            }
            $Stats[$endpoint].Count++
        }
        
        # Remove completed jobs from tracking
        $Jobs = $Jobs | Where-Object { $_.Job.State -ne "Completed" }
        
        # Start new jobs if we have capacity
        while ($Jobs.Count -lt $ConcurrentRequests) {
            $endpoint = $WeightedEndpoints | Get-Random
            $JobCounter++
            
            $job = Start-Job -ScriptBlock $JobScript -ArgumentList $BaseUrl, $endpoint, $JobCounter
            $Jobs += @{ Job = $job; StartTime = Get-Date; Endpoint = $endpoint }
        }
        
        # Progress update every 10 seconds
        $elapsed = (Get-Date) - $StartTime
        if ($elapsed.TotalSeconds % 10 -lt 1 -and $TotalRequests -gt 0) {
            $remaining = $EndTime - (Get-Date)
            $rps = [math]::Round($TotalRequests / $elapsed.TotalSeconds, 1)
            $successRate = [math]::Round(($SuccessfulRequests / $TotalRequests) * 100, 1)
            $avgResponseTime = if ($ResponseTimes.Count -gt 0) { [math]::Round(($ResponseTimes | Measure-Object -Average).Average, 0) } else { 0 }
            
            Write-Host "⏱️  Elapsed: $([math]::Round($elapsed.TotalMinutes, 1))m | Remaining: $([math]::Round($remaining.TotalMinutes, 1))m | Requests: $TotalRequests | RPS: $rps | Success: $successRate% | Avg Response: ${avgResponseTime}ms" -ForegroundColor Cyan
        }
        
        Start-Sleep -Milliseconds 100
    }
    catch {
        Write-Host "Error in main loop: $($_.Exception.Message)" -ForegroundColor Red
        Start-Sleep -Seconds 1
    }
}

# Wait for remaining jobs to complete
Write-Host ""
Write-Host "⏳ Waiting for remaining requests to complete..." -ForegroundColor Yellow

$timeout = (Get-Date).AddSeconds(30)
while ($Jobs.Count -gt 0 -and (Get-Date) -lt $timeout) {
    $CompletedJobs = $Jobs | Where-Object { $_.Job.State -eq "Completed" }
    foreach ($completedJob in $CompletedJobs) {
        $result = Receive-Job -Job $completedJob.Job
        Remove-Job -Job $completedJob.Job
        
        $TotalRequests++
        $endpoint = $result.Endpoint
        
        if ($result.Success) {
            $SuccessfulRequests++
            $Stats[$endpoint].Success++
            $ResponseTimes += $result.Duration
            $Stats[$endpoint].TotalTime += $result.Duration
        } else {
            $FailedRequests++
            $Stats[$endpoint].Failed++
        }
        $Stats[$endpoint].Count++
    }
    
    $Jobs = $Jobs | Where-Object { $_.Job.State -ne "Completed" }
    Start-Sleep -Milliseconds 100
}

# Clean up any remaining jobs
foreach ($job in $Jobs) {
    Stop-Job -Job $job.Job -PassThru | Remove-Job
}

# Calculate final statistics
$ActualDuration = (Get-Date) - $StartTime
$AverageRPS = [math]::Round($TotalRequests / $ActualDuration.TotalSeconds, 2)
$SuccessRate = if ($TotalRequests -gt 0) { [math]::Round(($SuccessfulRequests / $TotalRequests) * 100, 2) } else { 0 }
$AverageResponseTime = if ($ResponseTimes.Count -gt 0) { [math]::Round(($ResponseTimes | Measure-Object -Average).Average, 0) } else { 0 }
$MedianResponseTime = if ($ResponseTimes.Count -gt 0) { 
    $sorted = $ResponseTimes | Sort-Object
    $median = $sorted[[math]::Floor($sorted.Count / 2)]
    [math]::Round($median, 0)
} else { 0 }
$MaxResponseTime = if ($ResponseTimes.Count -gt 0) { ($ResponseTimes | Measure-Object -Maximum).Maximum } else { 0 }
$MinResponseTime = if ($ResponseTimes.Count -gt 0) { ($ResponseTimes | Measure-Object -Minimum).Minimum } else { 0 }

# Display results
Write-Host ""
Write-Host "🎯 Azure Load Test Results" -ForegroundColor Green
Write-Host "================================" -ForegroundColor Green
Write-Host "Duration: $([math]::Round($ActualDuration.TotalMinutes, 2)) minutes" -ForegroundColor White
Write-Host "Total Requests: $TotalRequests" -ForegroundColor White
Write-Host "Successful: $SuccessfulRequests" -ForegroundColor Green
Write-Host "Failed: $FailedRequests" -ForegroundColor Red
Write-Host "Success Rate: $SuccessRate%" -ForegroundColor $(if ($SuccessRate -gt 95) { "Green" } elseif ($SuccessRate -gt 85) { "Yellow" } else { "Red" })
Write-Host "Average RPS: $AverageRPS" -ForegroundColor White
Write-Host ""
Write-Host "Response Times (ms):" -ForegroundColor Cyan
Write-Host "  Average: $AverageResponseTime ms" -ForegroundColor White
Write-Host "  Median:  $MedianResponseTime ms" -ForegroundColor White
Write-Host "  Min:     $MinResponseTime ms" -ForegroundColor White  
Write-Host "  Max:     $MaxResponseTime ms" -ForegroundColor White
Write-Host ""

# Endpoint statistics
Write-Host "📈 Endpoint Statistics:" -ForegroundColor Cyan
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Gray

$format = "{0,-50} {1,8} {2,8} {3,8} {4,10} {5,8}"
Write-Host ($format -f "Endpoint", "Total", "Success", "Failed", "Avg (ms)", "Success%") -ForegroundColor Yellow

foreach ($endpoint in $Stats.Keys | Sort-Object) {
    $stat = $Stats[$endpoint]
    $avgTime = if ($stat.Success -gt 0) { [math]::Round($stat.TotalTime / $stat.Success, 0) } else { 0 }
    $successPct = if ($stat.Count -gt 0) { [math]::Round(($stat.Success / $stat.Count) * 100, 1) } else { 0 }
    
    $color = if ($successPct -gt 95) { "Green" } elseif ($successPct -gt 85) { "Yellow" } else { "Red" }
    Write-Host ($format -f $endpoint, $stat.Count, $stat.Success, $stat.Failed, $avgTime, "$successPct%") -ForegroundColor $color
}

Write-Host ""
Write-Host "✅ Load test completed! Check Application Insights for detailed telemetry." -ForegroundColor Green
Write-Host "🔗 Application Insights URL: https://portal.azure.com/#@/resource/subscriptions/[SUBSCRIPTION]/resourceGroups/observability-rg-west/providers/microsoft.insights/components/observability-insights" -ForegroundColor Blue