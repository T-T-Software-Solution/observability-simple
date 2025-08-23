#!/bin/bash

# Azure Load Test Script - 5 Minutes Continuous Testing
DURATION_MINUTES=${1:-5}
CONCURRENT_REQUESTS=${2:-6}
BASE_URL=${3:-"https://observability-upstream.azurewebsites.net"}

echo "🚀 Starting Azure Load Test"
echo "Duration: $DURATION_MINUTES minutes"
echo "Concurrent Requests: $CONCURRENT_REQUESTS"
echo "Target: $BASE_URL"
echo "Start Time: $(date '+%Y-%m-%d %H:%M:%S')"
echo ""

# Test endpoints with weights
ENDPOINTS=(
    "GET:/gateway/products/123:40"
    "GET:/gateway/products/456?delayMs=500:20"
    "POST:/gateway/orders:15"
    "POST:/gateway/orders?failureMode=transient:10"
    "GET:/health:10"
    "GET:/gateway/products/789?delayMs=1000:5"
)

# Create weighted endpoint array
WEIGHTED_ENDPOINTS=()
for endpoint in "${ENDPOINTS[@]}"; do
    IFS=':' read -r method url weight <<< "$endpoint"
    for ((i=0; i<weight; i++)); do
        WEIGHTED_ENDPOINTS+=("$method:$url")
    done
done

# Statistics
TOTAL_REQUESTS=0
SUCCESSFUL_REQUESTS=0
FAILED_REQUESTS=0
START_TIME=$(date +%s)
END_TIME=$((START_TIME + DURATION_MINUTES * 60))

# Function to make HTTP request
make_request() {
    local method_url="$1"
    IFS=':' read -r method url <<< "$method_url"
    local full_url="${BASE_URL}${url}"
    
    local start_time=$(date +%s%3N)
    if [[ "$method" == "POST" ]]; then
        if curl -s -X POST "$full_url" -w "%{http_code}" -o /dev/null --max-time 30 | grep -q "^[23]"; then
            echo "SUCCESS:$(($(date +%s%3N) - start_time)):$method_url"
        else
            echo "FAILED:$(($(date +%s%3N) - start_time)):$method_url"
        fi
    else
        if curl -s "$full_url" -w "%{http_code}" -o /dev/null --max-time 30 | grep -q "^[23]"; then
            echo "SUCCESS:$(($(date +%s%3N) - start_time)):$method_url"
        else
            echo "FAILED:$(($(date +%s%3N) - start_time)):$method_url"
        fi
    fi
}

echo "⚡ Load test in progress..."
echo "Press Ctrl+C to stop early"
echo ""

# Background process management
ACTIVE_PIDS=()
RESPONSE_TIMES=()

# Main load test loop
while [[ $(date +%s) -lt $END_TIME ]]; do
    # Clean up finished processes
    for i in "${!ACTIVE_PIDS[@]}"; do
        pid="${ACTIVE_PIDS[i]}"
        if ! kill -0 "$pid" 2>/dev/null; then
            # Process is done, collect result
            wait "$pid"
            unset ACTIVE_PIDS[i]
        fi
    done
    
    # Compact the array
    ACTIVE_PIDS=("${ACTIVE_PIDS[@]}")
    
    # Start new requests if we have capacity
    while [[ ${#ACTIVE_PIDS[@]} -lt $CONCURRENT_REQUESTS ]]; do
        # Select random weighted endpoint
        endpoint="${WEIGHTED_ENDPOINTS[$((RANDOM % ${#WEIGHTED_ENDPOINTS[@]}))]}"
        
        # Start background request
        {
            result=$(make_request "$endpoint")
            echo "$result" >> /tmp/load_test_results_$$
        } &
        
        ACTIVE_PIDS+=($!)
    done
    
    # Progress update every 10 seconds
    current_time=$(date +%s)
    if [[ $((current_time % 10)) -eq 0 ]] && [[ $TOTAL_REQUESTS -gt 0 ]]; then
        elapsed=$((current_time - START_TIME))
        remaining=$(((END_TIME - current_time) / 60))
        
        # Count results so far
        if [[ -f "/tmp/load_test_results_$$" ]]; then
            total_so_far=$(wc -l < /tmp/load_test_results_$$)
            success_so_far=$(grep -c "^SUCCESS" /tmp/load_test_results_$$)
            
            if [[ $total_so_far -gt 0 ]]; then
                rps=$(echo "scale=1; $total_so_far / $elapsed" | bc -l)
                success_rate=$(echo "scale=1; $success_so_far * 100 / $total_so_far" | bc -l)
                echo "⏱️  Elapsed: $((elapsed / 60))m | Remaining: ${remaining}m | Requests: $total_so_far | RPS: $rps | Success: $success_rate%"
            fi
        fi
    fi
    
    sleep 0.2
done

echo ""
echo "⏳ Waiting for remaining requests to complete..."

# Wait for all remaining processes
for pid in "${ACTIVE_PIDS[@]}"; do
    wait "$pid" 2>/dev/null
done

# Process results
if [[ -f "/tmp/load_test_results_$$" ]]; then
    while IFS=':' read -r status duration endpoint; do
        TOTAL_REQUESTS=$((TOTAL_REQUESTS + 1))
        RESPONSE_TIMES+=("$duration")
        
        if [[ "$status" == "SUCCESS" ]]; then
            SUCCESSFUL_REQUESTS=$((SUCCESSFUL_REQUESTS + 1))
        else
            FAILED_REQUESTS=$((FAILED_REQUESTS + 1))
        fi
    done < /tmp/load_test_results_$$
    
    rm -f "/tmp/load_test_results_$$"
fi

# Calculate statistics
ACTUAL_DURATION=$(($(date +%s) - START_TIME))
if [[ $TOTAL_REQUESTS -gt 0 ]]; then
    AVERAGE_RPS=$(echo "scale=2; $TOTAL_REQUESTS / $ACTUAL_DURATION" | bc -l)
    SUCCESS_RATE=$(echo "scale=2; $SUCCESSFUL_REQUESTS * 100 / $TOTAL_REQUESTS" | bc -l)
else
    AVERAGE_RPS=0
    SUCCESS_RATE=0
fi

# Calculate response time statistics
if [[ ${#RESPONSE_TIMES[@]} -gt 0 ]]; then
    # Sort response times
    IFS=$'\n' sorted_times=($(sort -n <<<"${RESPONSE_TIMES[*]}"))
    
    # Calculate average
    total_time=0
    for time in "${RESPONSE_TIMES[@]}"; do
        total_time=$((total_time + time))
    done
    AVERAGE_RESPONSE_TIME=$((total_time / ${#RESPONSE_TIMES[@]}))
    
    # Get min, max, median
    MIN_RESPONSE_TIME="${sorted_times[0]}"
    MAX_RESPONSE_TIME="${sorted_times[-1]}"
    median_index=$(( ${#sorted_times[@]} / 2 ))
    MEDIAN_RESPONSE_TIME="${sorted_times[$median_index]}"
else
    AVERAGE_RESPONSE_TIME=0
    MIN_RESPONSE_TIME=0
    MAX_RESPONSE_TIME=0
    MEDIAN_RESPONSE_TIME=0
fi

# Display results
echo ""
echo "🎯 Azure Load Test Results"
echo "================================"
echo "Duration: $(echo "scale=2; $ACTUAL_DURATION / 60" | bc -l) minutes"
echo "Total Requests: $TOTAL_REQUESTS"
echo "Successful: $SUCCESSFUL_REQUESTS"
echo "Failed: $FAILED_REQUESTS"
echo "Success Rate: $SUCCESS_RATE%"
echo "Average RPS: $AVERAGE_RPS"
echo ""
echo "Response Times (ms):"
echo "  Average: ${AVERAGE_RESPONSE_TIME} ms"
echo "  Median:  ${MEDIAN_RESPONSE_TIME} ms"
echo "  Min:     ${MIN_RESPONSE_TIME} ms"
echo "  Max:     ${MAX_RESPONSE_TIME} ms"
echo ""
echo "✅ Load test completed! Check Application Insights for detailed telemetry."
echo "🔗 Application Insights URL: https://portal.azure.com/#blade/AppInsightsExtension/QuickPulseBladeV2"