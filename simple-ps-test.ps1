# Simple PowerShell Load Test
param(
    [int]$DurationMinutes = 5,
    [string]$BaseUrl = "https://observability-upstream.azurewebsites.net"
)

$StartTime = Get-Date
$EndTime = $StartTime.AddMinutes($DurationMinutes)
$TotalRequests = 0
$SuccessfulRequests = 0

$Endpoints = @(
    "/gateway/products/123",
    "/gateway/products/456?delayMs=500", 
    "/gateway/orders",
    "/health"
)

Write-Host "🚀 PowerShell Load Test Running for $DurationMinutes minutes..."
Write-Host "Target: $BaseUrl"
Write-Host ""

while ((Get-Date) -lt $EndTime) {
    $endpoint = $Endpoints | Get-Random
    $uri = $BaseUrl + $endpoint
    
    try {
        if ($endpoint -eq "/gateway/orders") {
            $response = Invoke-RestMethod -Uri $uri -Method POST -TimeoutSec 10 -ErrorAction Stop
        } else {
            $response = Invoke-RestMethod -Uri $uri -Method GET -TimeoutSec 10 -ErrorAction Stop
        }
        $SuccessfulRequests++
    }
    catch {
        # Expected for failure modes
    }
    
    $TotalRequests++
    
    if ($TotalRequests % 20 -eq 0) {
        $elapsed = (Get-Date) - $StartTime
        $rps = [math]::Round($TotalRequests / $elapsed.TotalSeconds, 1)
        $successRate = [math]::Round(($SuccessfulRequests / $TotalRequests) * 100, 1)
        $remaining = [math]::Ceiling((($EndTime - (Get-Date)).TotalMinutes))
        Write-Host "Progress: ${TotalRequests} req | ${rps} RPS | ${successRate}% OK | ${remaining}m left"
    }
    
    Start-Sleep -Milliseconds 500
}

$Duration = (Get-Date) - $StartTime
$RPS = [math]::Round($TotalRequests / $Duration.TotalSeconds, 2)
$SuccessRate = [math]::Round(($SuccessfulRequests / $TotalRequests) * 100, 2)

Write-Host ""
Write-Host "✅ PowerShell Load Test Complete"
Write-Host "Duration: $([math]::Round($Duration.TotalMinutes, 2)) minutes"
Write-Host "Requests: $TotalRequests | Success: $SuccessfulRequests | Rate: $SuccessRate%"
Write-Host "Average RPS: $RPS"