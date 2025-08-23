# Advanced Bug Hunter Script - PowerShell Version
# This script generates various test patterns to help discover hidden bugs in the observability platform

param(
    [string]$BaseUrl = "http://localhost:5000",
    [string]$TestType = "all"
)

Write-Host "`n=== Advanced Bug Hunter - Observability Exercises ===" -ForegroundColor Cyan
Write-Host "Target: $BaseUrl" -ForegroundColor Yellow
Write-Host "Test Type: $TestType" -ForegroundColor Yellow

# Test 1: Random Product ID Test (finds hardcoded performance issues)
function Test-RandomProductIds {
    Write-Host "`n[TEST 1] Random Product ID Performance Test" -ForegroundColor Green
    Write-Host "Testing 100 random product IDs to find performance anomalies..." -ForegroundColor White
    
    $slowRequests = @()
    $normalRequests = @()
    
    for ($i = 1; $i -le 100; $i++) {
        $id = Get-Random -Minimum 1 -Maximum 10000
        $start = Get-Date
        
        try {
            $response = Invoke-RestMethod -Uri "$BaseUrl/gateway/products/$id" -Method Get -TimeoutSec 10
            $duration = ((Get-Date) - $start).TotalMilliseconds
            
            if ($duration -gt 2000) {
                $slowRequests += [PSCustomObject]@{ID = $id; Duration = $duration}
                Write-Host "!" -NoNewline -ForegroundColor Red
            } else {
                $normalRequests += [PSCustomObject]@{ID = $id; Duration = $duration}
                Write-Host "." -NoNewline -ForegroundColor Green
            }
        } catch {
            Write-Host "X" -NoNewline -ForegroundColor Yellow
        }
        
        if ($i % 50 -eq 0) { Write-Host " $i/100" }
    }
    
    Write-Host "`n`nResults:"
    if ($slowRequests.Count -gt 0) {
        Write-Host "Found $($slowRequests.Count) slow requests:" -ForegroundColor Red
        $slowRequests | ForEach-Object { Write-Host "  Product ID $($_.ID): $([math]::Round($_.Duration))ms" -ForegroundColor Red }
        
        # Analyze pattern
        $slowIds = $slowRequests | ForEach-Object { $_.ID }
        Write-Host "`nSlow Product IDs: $($slowIds -join ', ')" -ForegroundColor Yellow
        Write-Host "Hypothesis: Check if these IDs have something in common (unlucky numbers?)" -ForegroundColor Cyan
    } else {
        Write-Host "All requests performed normally" -ForegroundColor Green
    }
    
    if ($normalRequests.Count -gt 0) {
        $avgNormal = ($normalRequests | Measure-Object -Property Duration -Average).Average
        Write-Host "Average normal response time: $([math]::Round($avgNormal))ms" -ForegroundColor Green
    }
}

# Test 2: Sequential Order Range Test (finds range-based failures)
function Test-OrderRanges {
    Write-Host "`n[TEST 2] Sequential Order Range Test" -ForegroundColor Green
    Write-Host "Testing order IDs from 900 to 1200 to find failure patterns..." -ForegroundColor White
    
    $failures = @()
    $successes = @()
    
    for ($id = 900; $id -le 1200; $id++) {
        try {
            $response = Invoke-RestMethod -Uri "$BaseUrl/gateway/orders?orderId=$id" -Method Post -TimeoutSec 5
            $successes += $id
            Write-Host "." -NoNewline -ForegroundColor Green
        } catch {
            $failures += $id
            Write-Host "X" -NoNewline -ForegroundColor Red
        }
        
        if ($id % 50 -eq 0) { Write-Host " $id" }
    }
    
    Write-Host "`n`nResults:"
    if ($failures.Count -gt 0) {
        Write-Host "Failed order IDs: $($failures.Count) failures" -ForegroundColor Red
        
        # Analyze failure ranges
        $ranges = @()
        $start = $failures[0]
        $end = $failures[0]
        
        for ($i = 1; $i -lt $failures.Count; $i++) {
            if ($failures[$i] -eq $end + 1) {
                $end = $failures[$i]
            } else {
                if ($end - $start -ge 10) {
                    $ranges += "[$start-$end]"
                }
                $start = $failures[$i]
                $end = $failures[$i]
            }
        }
        if ($end - $start -ge 10) {
            $ranges += "[$start-$end]"
        }
        
        if ($ranges.Count -gt 0) {
            Write-Host "Failure ranges detected: $($ranges -join ', ')" -ForegroundColor Yellow
            Write-Host "Hypothesis: Check if specific ID ranges have processing issues" -ForegroundColor Cyan
        }
    }
    
    $failureRate = ($failures.Count / 301) * 100
    Write-Host "Overall failure rate: $([math]::Round($failureRate, 2))%" -ForegroundColor Yellow
}

# Test 3: Prime Number Pattern Test (finds mathematical pattern bugs)
function Test-PrimeNumbers {
    Write-Host "`n[TEST 3] Prime Number Pattern Test" -ForegroundColor Green
    Write-Host "Testing prime number IDs for memory anomalies..." -ForegroundColor White
    
    $primes = @(2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31, 37, 41, 43, 47, 53, 59, 61, 67, 71, 73, 79, 83, 89, 97)
    $nonPrimes = @(4, 6, 8, 9, 10, 12, 14, 15, 16, 18, 20, 21, 22, 24, 25, 26, 27, 28, 30, 32, 33, 34, 35, 36, 38)
    
    Write-Host "Testing prime IDs..." -ForegroundColor White
    $primeResults = @()
    foreach ($id in $primes) {
        try {
            $start = Get-Date
            $response = Invoke-RestMethod -Uri "$BaseUrl/gateway/products/$id" -Method Get -TimeoutSec 5
            $duration = ((Get-Date) - $start).TotalMilliseconds
            $primeResults += [PSCustomObject]@{ID = $id; Duration = $duration; IsPrime = $true}
            Write-Host "." -NoNewline -ForegroundColor Green
        } catch {
            Write-Host "X" -NoNewline -ForegroundColor Red
        }
    }
    
    Write-Host "`nTesting non-prime IDs..." -ForegroundColor White
    $nonPrimeResults = @()
    foreach ($id in $nonPrimes) {
        try {
            $start = Get-Date
            $response = Invoke-RestMethod -Uri "$BaseUrl/gateway/products/$id" -Method Get -TimeoutSec 5
            $duration = ((Get-Date) - $start).TotalMilliseconds
            $nonPrimeResults += [PSCustomObject]@{ID = $id; Duration = $duration; IsPrime = $false}
            Write-Host "." -NoNewline -ForegroundColor Green
        } catch {
            Write-Host "X" -NoNewline -ForegroundColor Red
        }
    }
    
    Write-Host "`n`nResults:"
    
    if ($primeResults.Count -gt 0 -and $nonPrimeResults.Count -gt 0) {
        $avgPrime = ($primeResults | Measure-Object -Property Duration -Average).Average
        $avgNonPrime = ($nonPrimeResults | Measure-Object -Property Duration -Average).Average
        
        Write-Host "Average prime ID response time: $([math]::Round($avgPrime))ms" -ForegroundColor Yellow
        Write-Host "Average non-prime ID response time: $([math]::Round($avgNonPrime))ms" -ForegroundColor Yellow
        
        if ($avgPrime -gt $avgNonPrime * 1.5) {
            Write-Host "WARNING: Prime number IDs show performance degradation!" -ForegroundColor Red
            Write-Host "Hypothesis: Check memory usage patterns for prime IDs" -ForegroundColor Cyan
        }
    } else {
        Write-Host "Unable to calculate averages - insufficient data" -ForegroundColor Yellow
    }
}

# Test 4: Load Pattern Test (finds concurrency issues)
function Test-LoadPattern {
    Write-Host "`n[TEST 4] Load Pattern Test" -ForegroundColor Green
    Write-Host "Sending 50 rapid requests to find thread pool issues..." -ForegroundColor White
    
    $results = @()
    for ($i = 1; $i -le 50; $i++) {
        $start = Get-Date
        try {
            $response = Invoke-RestMethod -Uri "$BaseUrl/gateway/orders" -Method Post -TimeoutSec 10
            $duration = ((Get-Date) - $start).TotalMilliseconds
            $results += [PSCustomObject]@{Request = $i; Duration = $duration}
            
            if ($duration -gt 3000) {
                Write-Host "S" -NoNewline -ForegroundColor Red
            } else {
                Write-Host "." -NoNewline -ForegroundColor Green
            }
        } catch {
            Write-Host "X" -NoNewline -ForegroundColor Yellow
        }
    }
    
    Write-Host "`n`nResults:"
    $slowRequests = $results | Where-Object { $_.Duration -gt 3000 }
    if ($slowRequests.Count -gt 0) {
        Write-Host "Slow requests detected at positions:" -ForegroundColor Red
        $slowRequests | ForEach-Object { Write-Host "  Request #$($_.Request): $([math]::Round($_.Duration))ms" }
        
        # Check for pattern (every 10th request)
        $positions = $slowRequests | ForEach-Object { $_.Request }
        $modulo10 = $positions | Where-Object { $_ % 10 -eq 0 }
        if ($modulo10.Count -eq $slowRequests.Count) {
            Write-Host "PATTERN DETECTED: Every 10th request is slow!" -ForegroundColor Red
            Write-Host "Hypothesis: Thread pool exhaustion pattern" -ForegroundColor Cyan
        }
    }
}

# Test 5: Palindrome Pattern Test (finds CPU spike issues)
function Test-PalindromePattern {
    Write-Host "`n[TEST 5] Palindrome Pattern Test" -ForegroundColor Green
    Write-Host "Testing palindrome IDs for CPU spike issues..." -ForegroundColor White
    
    # Test various palindrome IDs
    $palindromes = @(11, 22, 33, 44, 55, 66, 77, 88, 99, 101, 111, 121, 131, 141, 151, 161, 171, 181, 191, 202, 212, 222, 232, 242, 252, 1001, 1111, 1221, 1331, 1441, 1551, 1661, 1771, 1881, 1991, 2002, 2112, 2222, 2332, 2442)
    $nonPalindromes = @(10, 12, 13, 14, 15, 16, 17, 18, 19, 20, 23, 24, 25, 26, 27, 28, 29, 30, 100, 102, 103, 104, 105, 106, 107, 108, 109, 110, 112, 113, 114, 115)
    
    Write-Host "Testing palindrome IDs..." -ForegroundColor White
    $palindromeResults = @()
    foreach ($id in $palindromes[0..9]) {  # Test first 10 palindromes
        try {
            $start = Get-Date
            $response = Invoke-RestMethod -Uri "$BaseUrl/gateway/products/$id" -Method Get -TimeoutSec 15
            $duration = ((Get-Date) - $start).TotalMilliseconds
            $palindromeResults += [PSCustomObject]@{ID = $id; Duration = $duration; IsPalindrome = $true}
            
            if ($duration -gt 5000) {
                Write-Host "!" -NoNewline -ForegroundColor Red
            } else {
                Write-Host "." -NoNewline -ForegroundColor Green
            }
        } catch {
            Write-Host "X" -NoNewline -ForegroundColor Yellow
        }
    }
    
    Write-Host "`nTesting non-palindrome IDs..." -ForegroundColor White
    $nonPalindromeResults = @()
    foreach ($id in $nonPalindromes[0..9]) {  # Test first 10 non-palindromes
        try {
            $start = Get-Date
            $response = Invoke-RestMethod -Uri "$BaseUrl/gateway/products/$id" -Method Get -TimeoutSec 5
            $duration = ((Get-Date) - $start).TotalMilliseconds
            $nonPalindromeResults += [PSCustomObject]@{ID = $id; Duration = $duration; IsPalindrome = $false}
            Write-Host "." -NoNewline -ForegroundColor Green
        } catch {
            Write-Host "X" -NoNewline -ForegroundColor Yellow
        }
    }
    
    Write-Host "`n`nResults:"
    
    if ($palindromeResults.Count -gt 0 -and $nonPalindromeResults.Count -gt 0) {
        $avgPalindrome = ($palindromeResults | Measure-Object -Property Duration -Average).Average
        $avgNonPalindrome = ($nonPalindromeResults | Measure-Object -Property Duration -Average).Average
        
        Write-Host "Average palindrome ID response time: $([math]::Round($avgPalindrome))ms" -ForegroundColor Yellow
        Write-Host "Average non-palindrome ID response time: $([math]::Round($avgNonPalindrome))ms" -ForegroundColor Yellow
        
        if ($avgPalindrome -gt $avgNonPalindrome * 10) {
            Write-Host "CRITICAL: Palindrome IDs cause extreme CPU spikes!" -ForegroundColor Red
            $ratio = [math]::Round($avgPalindrome / $avgNonPalindrome)
            Write-Host "Palindrome requests take ${ratio}x longer!" -ForegroundColor Red
            Write-Host "Hypothesis: CPU-intensive processing for palindrome patterns" -ForegroundColor Cyan
            
            $slowPalindromes = $palindromeResults | Where-Object { $_.Duration -gt 5000 }
            if ($slowPalindromes.Count -gt 0) {
                Write-Host "`nExtremely slow palindrome IDs:" -ForegroundColor Red
                $slowPalindromes | ForEach-Object { Write-Host "  ID $($_.ID): $([math]::Round($_.Duration))ms" -ForegroundColor Red }
            }
        }
    } else {
        Write-Host "Unable to calculate averages - insufficient data" -ForegroundColor Yellow
    }
}

# Test 6: Edge Case Test (finds boundary issues)
function Test-EdgeCases {
    Write-Host "`n[TEST 6] Edge Case Test" -ForegroundColor Green
    Write-Host "Testing edge cases (0, negative, very large IDs)..." -ForegroundColor White
    
    $edgeCases = @(0, -1, -100, 999999, 2147483647)
    $results = @()
    
    foreach ($id in $edgeCases) {
        Write-Host "`nTesting Product ID $id..." -ForegroundColor White
        try {
            $response = Invoke-RestMethod -Uri "$BaseUrl/gateway/products/$id" -Method Get -TimeoutSec 5
            $results += [PSCustomObject]@{ID = $id; Status = "Success"; Data = $response}
            Write-Host "  Success" -ForegroundColor Green
            
            # Check for data corruption
            if ($response.name -eq "CORRUPTED_DATA" -or $response.price -eq -1) {
                Write-Host "  WARNING: Data corruption detected!" -ForegroundColor Red
                Write-Host "  Product name: $($response.name)" -ForegroundColor Yellow
                Write-Host "  Product price: $($response.price)" -ForegroundColor Yellow
            }
        } catch {
            $results += [PSCustomObject]@{ID = $id; Status = "Failed"; Error = $_.Exception.Message}
            Write-Host "  Failed: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
    
    # Test subsequent normal request after edge cases
    Write-Host "`nTesting normal request after edge cases..." -ForegroundColor White
    try {
        $response = Invoke-RestMethod -Uri "$BaseUrl/gateway/products/100" -Method Get -TimeoutSec 5
        if ($response.name -eq "CORRUPTED_DATA") {
            Write-Host "CACHE POISONING DETECTED: Normal requests returning corrupted data!" -ForegroundColor Red
            Write-Host "Hypothesis: Edge case IDs corrupt the cache" -ForegroundColor Cyan
        } else {
            Write-Host "Normal request OK" -ForegroundColor Green
        }
    } catch {
        Write-Host "Normal request failed" -ForegroundColor Red
    }
}

# Main execution
Write-Host "`nStarting bug hunting..." -ForegroundColor Cyan

switch ($TestType.ToLower()) {
    "random" { Test-RandomProductIds }
    "range" { Test-OrderRanges }
    "prime" { Test-PrimeNumbers }
    "load" { Test-LoadPattern }
    "palindrome" { Test-PalindromePattern }
    "edge" { Test-EdgeCases }
    "all" {
        Test-RandomProductIds
        Start-Sleep -Seconds 2
        Test-OrderRanges
        Start-Sleep -Seconds 2
        Test-PrimeNumbers
        Start-Sleep -Seconds 2
        Test-LoadPattern
        Start-Sleep -Seconds 2
        Test-PalindromePattern
        Start-Sleep -Seconds 2
        Test-EdgeCases
    }
    default {
        Write-Host "Invalid test type. Use: random, range, prime, load, palindrome, edge, or all" -ForegroundColor Red
    }
}

Write-Host "`n=== Bug Hunter Complete ===" -ForegroundColor Cyan
Write-Host "Check Application Insights for detailed telemetry and code locations!" -ForegroundColor Yellow
Write-Host "`n🔍 Code-Level Analysis:" -ForegroundColor Cyan
Write-Host "All bugs now include exact file names and line numbers in Application Insights" -ForegroundColor White
Write-Host "Look for 'BugTriggered' events with CodeLocation dimensions" -ForegroundColor Green

