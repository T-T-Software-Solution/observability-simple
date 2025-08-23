#!/bin/bash

# Performance Testing Script for Observability APIs
# Bash script for load testing and performance analysis

CONCURRENT_USERS=${1:-10}
TEST_DURATION_MINUTES=${2:-2}
TARGET_URL=${3:-"http://localhost:5000"}
TEST_TYPE=${4:-"mixed"}

CYAN='\033[0;36m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
RED='\033[0;31m'
WHITE='\033[1;37m'
MAGENTA='\033[0;35m'
GRAY='\033[0;90m'
NC='\033[0m' # No Color

echo -e "${CYAN}========================================"
echo -e "Performance Testing Script"
echo -e "========================================${NC}"
echo -e "${YELLOW}Target URL: $TARGET_URL"
echo -e "Concurrent Users: $CONCURRENT_USERS"
echo -e "Test Duration: $TEST_DURATION_MINUTES minutes"
echo -e "Test Type: $TEST_TYPE${NC}"
echo ""

# Create temporary files for results
RESULTS_DIR=$(mktemp -d)
SUMMARY_FILE="$RESULTS_DIR/summary.txt"

make_request() {
    local method=$1
    local endpoint=$2
    local description=$3
    local start_time=$(date +%s.%3N)
    
    if [ "$method" == "GET" ]; then
        response=$(curl -s -w "\n%{http_code}\n%{time_total}" "$TARGET_URL$endpoint" 2>/dev/null)
    else
        response=$(curl -s -w "\n%{http_code}\n%{time_total}" -X POST "$TARGET_URL$endpoint" 2>/dev/null)
    fi
    
    http_code=$(echo "$response" | tail -n2 | head -n1)
    time_total=$(echo "$response" | tail -n1)
    time_ms=$(echo "$time_total * 1000" | bc -l | cut -d. -f1)
    
    if [ "$http_code" -ge 200 ] && [ "$http_code" -lt 300 ]; then
        success=1
    else
        success=0
    fi
    
    echo "$success,$http_code,$time_ms,$description,$(date +%s)" >> "$RESULTS_DIR/results.csv"
}

run_mixed_workload() {
    local user_id=$1
    local end_time=$2
    local user_results="$RESULTS_DIR/user_$user_id.csv"
    
    # Initialize CSV with headers
    echo "success,status_code,duration_ms,description,timestamp" > "$user_results"
    
    while [ $(date +%s) -lt $end_time ]; do
        case $((RANDOM % 4)) in
            0)
                product_id=$((RANDOM % 100 + 1))
                make_request "GET" "/gateway/products/$product_id" "Gateway Product"
                ;;
            1)
                product_id=$((RANDOM % 100 + 1))
                delay=$((RANDOM % 400 + 100))
                make_request "GET" "/gateway/products/$product_id?delayMs=$delay" "Gateway Product with delay"
                ;;
            2)
                make_request "POST" "/gateway/orders" "Gateway Order"
                ;;
            3)
                make_request "POST" "/gateway/orders?failureMode=transient" "Gateway Order with transient failure"
                ;;
        esac
        
        # Random delay between requests
        sleep_time=$(echo "scale=3; (($RANDOM % 900) + 100) / 1000" | bc)
        sleep $sleep_time
    done
    
    # Append results to main results file
    tail -n +2 "$user_results" >> "$RESULTS_DIR/results.csv"
}

echo -e "${GREEN}Starting performance test...${NC}"
echo -e "${YELLOW}Press Ctrl+C to stop early${NC}"
echo ""

# Initialize main results file
echo "success,status_code,duration_ms,description,timestamp" > "$RESULTS_DIR/results.csv"

# Calculate end time
END_TIME=$(($(date +%s) + ($TEST_DURATION_MINUTES * 60)))

# Start concurrent users
PIDS=()
for i in $(seq 1 $CONCURRENT_USERS); do
    run_mixed_workload $i $END_TIME &
    PIDS+=($!)
    echo -e "${GRAY}Started user $i${NC}"
done

# Monitor progress
PROGRESS_COUNT=0
while [ $(date +%s) -lt $END_TIME ]; do
    PROGRESS_COUNT=$((PROGRESS_COUNT + 1))
    if [ $((PROGRESS_COUNT % 10)) -eq 0 ]; then
        ELAPSED=$(echo "scale=1; ($(date +%s) - ($(date +%s) - ($TEST_DURATION_MINUTES * 60))) / 60" | bc)
        REMAINING=$(echo "scale=1; ($END_TIME - $(date +%s)) / 60" | bc)
        echo -e "${CYAN}Elapsed: ${ELAPSED} min, Remaining: ${REMAINING} min${NC}"
    fi
    sleep 1
done

echo ""
echo -e "${GREEN}Test completed. Collecting results...${NC}"

# Wait for all background processes to complete
for pid in "${PIDS[@]}"; do
    wait $pid
done

# Analyze results
if [ -f "$RESULTS_DIR/results.csv" ]; then
    TOTAL_REQUESTS=$(tail -n +2 "$RESULTS_DIR/results.csv" | wc -l)
    SUCCESSFUL_REQUESTS=$(tail -n +2 "$RESULTS_DIR/results.csv" | awk -F, '$1==1' | wc -l)
    FAILED_REQUESTS=$(tail -n +2 "$RESULTS_DIR/results.csv" | awk -F, '$1==0' | wc -l)
    
    if [ $TOTAL_REQUESTS -gt 0 ]; then
        SUCCESS_RATE=$(echo "scale=2; $SUCCESSFUL_REQUESTS * 100 / $TOTAL_REQUESTS" | bc)
    else
        SUCCESS_RATE=0
    fi
    
    if [ $SUCCESSFUL_REQUESTS -gt 0 ]; then
        AVG_RESPONSE_TIME=$(tail -n +2 "$RESULTS_DIR/results.csv" | awk -F, '$1==1 {sum+=$3; count++} END {if(count>0) print sum/count; else print 0}')
        MIN_RESPONSE_TIME=$(tail -n +2 "$RESULTS_DIR/results.csv" | awk -F, '$1==1 {print $3}' | sort -n | head -1)
        MAX_RESPONSE_TIME=$(tail -n +2 "$RESULTS_DIR/results.csv" | awk -F, '$1==1 {print $3}' | sort -n | tail -1)
        
        # Calculate percentiles
        P50=$(tail -n +2 "$RESULTS_DIR/results.csv" | awk -F, '$1==1 {print $3}' | sort -n | awk '{all[NR] = $0} END{print all[int(NR*0.50 - 0.5)+1]}')
        P90=$(tail -n +2 "$RESULTS_DIR/results.csv" | awk -F, '$1==1 {print $3}' | sort -n | awk '{all[NR] = $0} END{print all[int(NR*0.90 - 0.5)+1]}')
        P95=$(tail -n +2 "$RESULTS_DIR/results.csv" | awk -F, '$1==1 {print $3}' | sort -n | awk '{all[NR] = $0} END{print all[int(NR*0.95 - 0.5)+1]}')
        P99=$(tail -n +2 "$RESULTS_DIR/results.csv" | awk -F, '$1==1 {print $3}' | sort -n | awk '{all[NR] = $0} END{print all[int(NR*0.99 - 0.5)+1]}')
    else
        AVG_RESPONSE_TIME=0
        MIN_RESPONSE_TIME=0
        MAX_RESPONSE_TIME=0
        P50=P90=P95=P99=0
    fi
    
    THROUGHPUT=$(echo "scale=2; $TOTAL_REQUESTS / $TEST_DURATION_MINUTES" | bc)
    
    echo -e "${YELLOW}Collected $TOTAL_REQUESTS total requests${NC}"
    echo ""
    
    echo -e "${CYAN}========================================"
    echo -e "PERFORMANCE TEST RESULTS"
    echo -e "========================================${NC}"
    echo ""
    echo -e "${WHITE}Total Requests: $TOTAL_REQUESTS${NC}"
    echo -e "${GREEN}Successful Requests: $SUCCESSFUL_REQUESTS${NC}"
    echo -e "${RED}Failed Requests: $FAILED_REQUESTS${NC}"
    
    if (( $(echo "$SUCCESS_RATE > 95" | bc -l) )); then
        COLOR=$GREEN
    elif (( $(echo "$SUCCESS_RATE > 90" | bc -l) )); then
        COLOR=$YELLOW
    else
        COLOR=$RED
    fi
    echo -e "${COLOR}Success Rate: $SUCCESS_RATE%${NC}"
    echo ""
    
    echo -e "${YELLOW}Response Times (ms):${NC}"
    echo -e "${WHITE}  Average: $(printf "%.2f" $AVG_RESPONSE_TIME)${NC}"
    echo -e "${WHITE}  Minimum: $MIN_RESPONSE_TIME${NC}"
    echo -e "${WHITE}  Maximum: $MAX_RESPONSE_TIME${NC}"
    echo -e "${WHITE}  50th Percentile: $P50${NC}"
    echo -e "${WHITE}  90th Percentile: $P90${NC}"
    echo -e "${WHITE}  95th Percentile: $P95${NC}"
    echo -e "${WHITE}  99th Percentile: $P99${NC}"
    echo ""
    echo -e "${MAGENTA}Throughput: $THROUGHPUT requests/minute${NC}"
    echo ""
    
    # Status Code Distribution
    echo -e "${YELLOW}Status Code Distribution:${NC}"
    tail -n +2 "$RESULTS_DIR/results.csv" | awk -F, '{print $2}' | sort | uniq -c | while read count code; do
        percentage=$(echo "scale=1; $count * 100 / $TOTAL_REQUESTS" | bc)
        echo -e "${WHITE}  $code: $count ($percentage%)${NC}"
    done
    
else
    echo -e "${RED}No results found!${NC}"
fi

# Clean up
rm -rf "$RESULTS_DIR"

echo ""
echo -e "${CYAN}========================================"
echo -e "${GREEN}Test completed successfully!"
echo -e "${YELLOW}Check Application Insights for detailed metrics"
echo -e "${CYAN}========================================${NC}"