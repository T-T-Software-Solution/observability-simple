#!/bin/bash

# Advanced Bug Hunter Script - Bash Version
# This script generates various test patterns to help discover hidden bugs in the observability platform

BASE_URL="${1:-http://localhost:5000}"
TEST_TYPE="${2:-all}"

echo -e "\n\033[36m=== Advanced Bug Hunter - Observability Exercises ===\033[0m"
echo -e "\033[33mTarget: $BASE_URL\033[0m"
echo -e "\033[33mTest Type: $TEST_TYPE\033[0m"

# Test 1: Random Product ID Test (finds hardcoded performance issues)
test_random_product_ids() {
    echo -e "\n\033[32m[TEST 1] Random Product ID Performance Test\033[0m"
    echo "Testing 100 random product IDs to find performance anomalies..."
    
    declare -a slow_requests
    declare -a normal_requests
    
    for i in {1..100}; do
        id=$((RANDOM % 10000 + 1))
        start=$(date +%s%N)
        
        if response=$(curl -s -w "\n%{http_code}" --max-time 10 "$BASE_URL/gateway/products/$id" 2>/dev/null); then
            http_code=$(echo "$response" | tail -n1)
            end=$(date +%s%N)
            duration=$(((end - start) / 1000000))
            
            if [ "$duration" -gt 2000 ]; then
                slow_requests+=("$id:$duration")
                echo -n -e "\033[31m!\033[0m"
            else
                normal_requests+=("$id:$duration")
                echo -n -e "\033[32m.\033[0m"
            fi
        else
            echo -n -e "\033[33mX\033[0m"
        fi
        
        if [ $((i % 50)) -eq 0 ]; then echo " $i/100"; fi
    done
    
    echo -e "\n\nResults:"
    if [ ${#slow_requests[@]} -gt 0 ]; then
        echo -e "\033[31mFound ${#slow_requests[@]} slow requests:\033[0m"
        for req in "${slow_requests[@]}"; do
            IFS=':' read -r id duration <<< "$req"
            echo -e "\033[31m  Product ID $id: ${duration}ms\033[0m"
        done
        
        echo -e "\033[33mHypothesis: Check if these IDs have something in common (unlucky numbers?)\033[0m"
    else
        echo -e "\033[32mAll requests performed normally\033[0m"
    fi
}

# Test 2: Sequential Order Range Test (finds range-based failures)
test_order_ranges() {
    echo -e "\n\033[32m[TEST 2] Sequential Order Range Test\033[0m"
    echo "Testing order IDs from 900 to 1200 to find failure patterns..."
    
    declare -a failures
    declare -a successes
    
    for id in {900..1200}; do
        if response=$(curl -s -X POST -w "\n%{http_code}" --max-time 5 "$BASE_URL/gateway/orders?orderId=$id" 2>/dev/null); then
            http_code=$(echo "$response" | tail -n1)
            if [ "$http_code" = "201" ]; then
                successes+=($id)
                echo -n -e "\033[32m.\033[0m"
            else
                failures+=($id)
                echo -n -e "\033[31mX\033[0m"
            fi
        else
            failures+=($id)
            echo -n -e "\033[31mX\033[0m"
        fi
        
        if [ $((id % 50)) -eq 0 ]; then echo " $id"; fi
    done
    
    echo -e "\n\nResults:"
    if [ ${#failures[@]} -gt 0 ]; then
        echo -e "\033[31mFailed order IDs: ${#failures[@]} failures\033[0m"
        
        # Check for continuous ranges
        if [ ${#failures[@]} -gt 50 ]; then
            echo -e "\033[33mHigh failure concentration detected!\033[0m"
            echo -e "\033[36mHypothesis: Check if order IDs 1000-1099 have processing issues\033[0m"
        fi
    fi
    
    failure_rate=$((${#failures[@]} * 100 / 301))
    echo -e "\033[33mOverall failure rate: ${failure_rate}%\033[0m"
}

# Test 3: Prime Number Pattern Test (finds mathematical pattern bugs)
test_prime_numbers() {
    echo -e "\n\033[32m[TEST 3] Prime Number Pattern Test\033[0m"
    echo "Testing prime number IDs for memory anomalies..."
    
    primes=(2 3 5 7 11 13 17 19 23 29 31 37 41 43 47 53 59 61 67 71 73 79 83 89 97)
    non_primes=(4 6 8 9 10 12 14 15 16 18 20 21 22 24 25 26 27 28 30 32 33 34 35 36 38)
    
    echo "Testing prime IDs..."
    prime_total=0
    prime_count=0
    for id in "${primes[@]}"; do
        start=$(date +%s%N)
        if curl -s --max-time 5 "$BASE_URL/gateway/products/$id" > /dev/null 2>&1; then
            end=$(date +%s%N)
            duration=$(((end - start) / 1000000))
            prime_total=$((prime_total + duration))
            prime_count=$((prime_count + 1))
            echo -n -e "\033[32m.\033[0m"
        else
            echo -n -e "\033[31mX\033[0m"
        fi
    done
    
    echo -e "\nTesting non-prime IDs..."
    non_prime_total=0
    non_prime_count=0
    for id in "${non_primes[@]}"; do
        start=$(date +%s%N)
        if curl -s --max-time 5 "$BASE_URL/gateway/products/$id" > /dev/null 2>&1; then
            end=$(date +%s%N)
            duration=$(((end - start) / 1000000))
            non_prime_total=$((non_prime_total + duration))
            non_prime_count=$((non_prime_count + 1))
            echo -n -e "\033[32m.\033[0m"
        else
            echo -n -e "\033[31mX\033[0m"
        fi
    done
    
    if [ $prime_count -gt 0 ] && [ $non_prime_count -gt 0 ]; then
        avg_prime=$((prime_total / prime_count))
        avg_non_prime=$((non_prime_total / non_prime_count))
        
        echo -e "\n\nResults:"
        echo -e "\033[33mAverage prime ID response time: ${avg_prime}ms\033[0m"
        echo -e "\033[33mAverage non-prime ID response time: ${avg_non_prime}ms\033[0m"
        
        if [ $avg_prime -gt $((avg_non_prime * 3 / 2)) ]; then
            echo -e "\033[31mWARNING: Prime number IDs show performance degradation!\033[0m"
            echo -e "\033[36mHypothesis: Check memory usage patterns for prime IDs\033[0m"
        fi
    fi
}

# Test 4: Load Pattern Test (finds concurrency issues)
test_load_pattern() {
    echo -e "\n\033[32m[TEST 4] Load Pattern Test\033[0m"
    echo "Sending 50 rapid requests to find thread pool issues..."
    
    declare -a slow_positions
    
    for i in {1..50}; do
        start=$(date +%s%N)
        if curl -s -X POST --max-time 10 "$BASE_URL/gateway/orders" > /dev/null 2>&1; then
            end=$(date +%s%N)
            duration=$(((end - start) / 1000000))
            
            if [ "$duration" -gt 3000 ]; then
                slow_positions+=($i)
                echo -n -e "\033[31mS\033[0m"
            else
                echo -n -e "\033[32m.\033[0m"
            fi
        else
            echo -n -e "\033[33mX\033[0m"
        fi
    done
    
    echo -e "\n\nResults:"
    if [ ${#slow_positions[@]} -gt 0 ]; then
        echo -e "\033[31mSlow requests detected at positions: ${slow_positions[*]}\033[0m"
        
        # Check if all slow positions are divisible by 10
        all_div_10=true
        for pos in "${slow_positions[@]}"; do
            if [ $((pos % 10)) -ne 0 ]; then
                all_div_10=false
                break
            fi
        done
        
        if [ "$all_div_10" = true ]; then
            echo -e "\033[31mPATTERN DETECTED: Every 10th request is slow!\033[0m"
            echo -e "\033[36mHypothesis: Thread pool exhaustion pattern\033[0m"
        fi
    fi
}

# Test 5: Edge Case Test (finds boundary issues)
test_edge_cases() {
    echo -e "\n\033[32m[TEST 5] Edge Case Test\033[0m"
    echo "Testing edge cases (0, negative, very large IDs)..."
    
    edge_cases=(0 -1 -100 999999 2147483647)
    
    for id in "${edge_cases[@]}"; do
        echo -e "\nTesting Product ID $id..."
        if response=$(curl -s --max-time 5 "$BASE_URL/gateway/products/$id" 2>/dev/null); then
            echo -e "\033[32m  Success\033[0m"
            
            # Check for data corruption
            if echo "$response" | grep -q "CORRUPTED_DATA\|\"price\":-1"; then
                echo -e "\033[31m  WARNING: Data corruption detected!\033[0m"
                echo "$response" | head -n 5
            fi
        else
            echo -e "\033[31m  Failed\033[0m"
        fi
    done
    
    # Test subsequent normal request after edge cases
    echo -e "\nTesting normal request after edge cases..."
    if response=$(curl -s --max-time 5 "$BASE_URL/gateway/products/100" 2>/dev/null); then
        if echo "$response" | grep -q "CORRUPTED_DATA"; then
            echo -e "\033[31mCACHE POISONING DETECTED: Normal requests returning corrupted data!\033[0m"
            echo -e "\033[36mHypothesis: Edge case IDs corrupt the cache\033[0m"
        else
            echo -e "\033[32mNormal request OK\033[0m"
        fi
    else
        echo -e "\033[31mNormal request failed\033[0m"
    fi
}

# Main execution
echo -e "\nStarting bug hunting..."

case "${TEST_TYPE,,}" in
    random)
        test_random_product_ids
        ;;
    range)
        test_order_ranges
        ;;
    prime)
        test_prime_numbers
        ;;
    load)
        test_load_pattern
        ;;
    edge)
        test_edge_cases
        ;;
    all)
        test_random_product_ids
        sleep 2
        test_order_ranges
        sleep 2
        test_prime_numbers
        sleep 2
        test_load_pattern
        sleep 2
        test_edge_cases
        ;;
    *)
        echo -e "\033[31mInvalid test type. Use: random, range, prime, load, edge, or all\033[0m"
        ;;
esac

echo -e "\n\033[36m=== Bug Hunter Complete ===\033[0m"
echo -e "\033[33mCheck Application Insights for detailed telemetry!\033[0m"