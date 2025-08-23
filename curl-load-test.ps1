# Simple cURL-based Load Test - 5 Minutes
param(
    [int]$DurationMinutes = 5,
    [int]$RequestsPerMinute = 60,
    [string]$BaseUrl = "https://observability-upstream.azurewebsites.net"
)

$StartTime = Get-Date
$EndTime = $StartTime.AddMinutes($DurationMinutes)
$TotalRequests = 0
$SuccessfulRequests = 0
$FailedRequests = 0
$DelayBetweenRequests = 60000 / $RequestsPerMinute  # milliseconds

# Test endpoints
$Endpoints = @(
    @{ Method = "GET"; Url = "/gateway/products/123"; Description = "Fast product lookup" },
    @{ Method = "GET"; Url = "/gateway/products/456?delayMs=500"; Description = "Slow product lookup" },
    @{ Method = "POST"; Url = "/gateway/orders"; Description = "Normal order" },
    @{ Method = "POST"; Url = "/gateway/orders?failureMode=transient"; Description = "Transient failure test" },
    @{ Method = "GET"; Url = "/health"; Description = "Health check" }
)

Write-Host "🚀 Starting cURL Load Test" -ForegroundColor Green
Write-Host "Duration: $DurationMinutes minutes"
Write-Host "Target RPS: $([math]::Round($RequestsPerMinute/60, 1))"
Write-Host "Target: $BaseUrl"
Write-Host "Start Time: $($StartTime.ToString('yyyy-MM-dd HH:mm:ss'))"
Write-Host ""

# Track endpoint statistics
$EndpointStats = @{}
foreach ($ep in $Endpoints) {
    $key = "$($ep.Method) $($ep.Url)"
    $EndpointStats[$key] = @{ Total = 0; Success = 0; Failed = 0; TotalTime = 0 }
}

Write-Host "⚡ Load test in progress..." -ForegroundColor Green
Write-Host ""

while ((Get-Date) -lt $EndTime) {
    $endpoint = $Endpoints | Get-Random
    $uri = $BaseUrl + $endpoint.Url
    $key = "$($endpoint.Method) $($endpoint.Url)"
    
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    
    try {
        if ($endpoint.Method -eq "POST") {
            $result = curl -s -X POST "$uri" -w "%{http_code}|%{time_total}" -o $null --max-time 30
        } else {
            $result = curl -s "$uri" -w "%{http_code}|%{time_total}" -o $null --max-time 30
        }
        
        $stopwatch.Stop()
        
        if ($result -match "^([0-9]{3})\|(.+)$") {
            $httpCode = [int]$matches[1]
            $responseTime = [double]$matches[2] * 1000  # Convert to milliseconds
            
            $TotalRequests++
            $EndpointStats[$key].Total++
            $EndpointStats[$key].TotalTime += $responseTime
            
            if ($httpCode -ge 200 -and $httpCode -lt 400) {
                $SuccessfulRequests++
                $EndpointStats[$key].Success++
                $status = "✅"
            } else {
                $FailedRequests++
                $EndpointStats[$key].Failed++
                $status = "❌"
            }
            
            # Show progress every 10 requests
            if ($TotalRequests % 10 -eq 0) {
                $elapsed = (Get-Date) - $StartTime
                $remaining = $EndTime - (Get-Date)
                $currentRps = [math]::Round($TotalRequests / $elapsed.TotalSeconds, 1)
                $successRate = [math]::Round(($SuccessfulRequests / $TotalRequests) * 100, 1)
                
                Write-Host "⏱️  $([math]::Floor($elapsed.TotalMinutes))m$([math]::Floor($elapsed.Seconds))s | Remaining: $([math]::Ceiling($remaining.TotalMinutes))m | Requests: $TotalRequests | RPS: $currentRps | Success: $successRate%" -ForegroundColor Cyan
            }
        }
    }
    catch {
        $FailedRequests++
        $TotalRequests++
        $EndpointStats[$key].Total++
        $EndpointStats[$key].Failed++
        Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    # Rate limiting
    if ($DelayBetweenRequests -gt 0) {
        Start-Sleep -Milliseconds $DelayBetweenRequests
    }
}

$ActualDuration = (Get-Date) - $StartTime
$AverageRPS = [math]::Round($TotalRequests / $ActualDuration.TotalSeconds, 2)
$SuccessRate = if ($TotalRequests -gt 0) { [math]::Round(($SuccessfulRequests / $TotalRequests) * 100, 2) } else { 0 }

Write-Host ""
Write-Host "🎯 Load Test Results" -ForegroundColor Green
Write-Host "===================="
Write-Host "Duration: $([math]::Round($ActualDuration.TotalMinutes, 2)) minutes"
Write-Host "Total Requests: $TotalRequests"
Write-Host "Successful: $SuccessfulRequests" -ForegroundColor Green
Write-Host "Failed: $FailedRequests" -ForegroundColor Red
Write-Host "Success Rate: $SuccessRate%"
Write-Host "Average RPS: $AverageRPS"
Write-Host ""

Write-Host "📊 Endpoint Statistics:" -ForegroundColor Cyan
Write-Host "────────────────────────────────────────────────────────────────────────────"
$format = "{0,-50} {1,6} {2,6} {3,6} {4,8} {5,8}"
Write-Host ($format -f "Endpoint", "Total", "OK", "Fail", "Avg(ms)", "Success%") -ForegroundColor Yellow

foreach ($key in $EndpointStats.Keys | Sort-Object) {
    $stat = $EndpointStats[$key]
    if ($stat.Total -gt 0) {
        $avgTime = if ($stat.Success -gt 0) { [math]::Round($stat.TotalTime / $stat.Success, 0) } else { 0 }
        $successPct = [math]::Round(($stat.Success / $stat.Total) * 100, 1)
        
        $color = if ($successPct -gt 95) { "Green" } elseif ($successPct -gt 85) { "Yellow" } else { "Red" }
        Write-Host ($format -f $key, $stat.Total, $stat.Success, $stat.Failed, $avgTime, "$successPct%") -ForegroundColor $color
    }
}

Write-Host ""
Write-Host "✅ Load test completed! Data should be flowing to Application Insights." -ForegroundColor Green
Write-Host "🔗 View in Azure Portal: Application Insights > Live Metrics" -ForegroundColor Blue