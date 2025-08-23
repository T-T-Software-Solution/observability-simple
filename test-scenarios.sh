#!/bin/bash

# Observability Testing Scenarios Script
# Bash script to test various scenarios

CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
RED='\033[0;31m'
WHITE='\033[1;37m'
GRAY='\033[0;90m'
NC='\033[0m' # No Color

echo -e "${CYAN}========================================"
echo -e "Observability Testing Scenarios"
echo -e "========================================${NC}"
echo ""

DOWNSTREAM_URL="http://localhost:5001"
UPSTREAM_URL="http://localhost:5000"

test_endpoint() {
    local name=$1
    local method=$2
    local url=$3
    local expected_status=$4
    
    echo -e "${YELLOW}Testing: $name${NC}"
    
    if [ "$method" == "GET" ]; then
        response=$(curl -s -w "\n%{http_code}" "$url")
    else
        response=$(curl -s -w "\n%{http_code}" -X POST "$url")
    fi
    
    http_code=$(echo "$response" | tail -n1)
    body=$(echo "$response" | sed '$d')
    
    if [ "$http_code" == "$expected_status" ] || [ "$expected_status" == "Any" ]; then
        echo -e "  ${GREEN}✓ Success: Status $http_code${NC}"
        if [ -n "$body" ]; then
            echo -e "  ${GRAY}Response: $body${NC}"
        fi
    else
        echo -e "  ${RED}✗ Failed: Expected $expected_status, got $http_code${NC}"
    fi
    echo ""
}

# 1. Health Check Tests
echo -e "${MAGENTA}1. HEALTH CHECK TESTS"
echo -e "=====================${NC}"
test_endpoint "Downstream Health" "GET" "$DOWNSTREAM_URL/health" "200"
test_endpoint "Upstream Health" "GET" "$UPSTREAM_URL/health" "200"

# 2. Latency Tests
echo -e "${MAGENTA}2. LATENCY SIMULATION TESTS"
echo -e "============================${NC}"
test_endpoint "Product without delay" "GET" "$DOWNSTREAM_URL/products/100" "200"
test_endpoint "Product with 500ms delay" "GET" "$DOWNSTREAM_URL/products/101?delayMs=500" "200"
test_endpoint "Gateway product with 1000ms delay" "GET" "$UPSTREAM_URL/gateway/products/102?delayMs=1000" "200"

# 3. Error Simulation Tests
echo -e "${MAGENTA}3. ERROR SIMULATION TESTS"
echo -e "==========================${NC}"
test_endpoint "Order with no failure" "POST" "$DOWNSTREAM_URL/orders" "201"

echo -e "${YELLOW}Testing transient failures (50% chance)...${NC}"
success_count=0
failure_count=0
for i in {1..10}; do
    response=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$DOWNSTREAM_URL/orders?failureMode=transient")
    if [ "$response" == "201" ]; then
        ((success_count++))
        echo -ne "  ${GREEN}Attempt $i: Success${NC}"
    else
        ((failure_count++))
        echo -ne "  ${RED}Attempt $i: Failed${NC}"
    fi
    if [ $((i % 5)) -eq 0 ]; then echo ""; fi
done
echo ""
echo -e "  ${CYAN}Transient Results: $success_count successes, $failure_count failures out of 10 attempts${NC}"
echo ""

test_endpoint "Order with persistent failure" "POST" "$DOWNSTREAM_URL/orders?failureMode=persistent" "500"

# 4. Gateway Error Handling Tests
echo -e "${MAGENTA}4. GATEWAY ERROR HANDLING TESTS"
echo -e "================================${NC}"
test_endpoint "Gateway order with no failure" "POST" "$UPSTREAM_URL/gateway/orders" "201"
test_endpoint "Gateway order with persistent failure" "POST" "$UPSTREAM_URL/gateway/orders?failureMode=persistent" "502"

# 5. Resource Pressure Tests
echo -e "${MAGENTA}5. RESOURCE PRESSURE TESTS"
echo -e "===========================${NC}"
test_endpoint "CPU pressure (light)" "GET" "$DOWNSTREAM_URL/pressure/cpu?iterations=100000" "200"
test_endpoint "Memory pressure (10MB)" "GET" "$DOWNSTREAM_URL/pressure/memory?mbToAllocate=10" "200"

# 6. End-to-End Tracing Test
echo -e "${MAGENTA}6. END-TO-END TRACING TEST"
echo -e "===========================${NC}"
echo -e "${YELLOW}Simulating a complex scenario with multiple calls...${NC}"

# Make several correlated calls
for id in 201 202 203; do
    test_endpoint "Gateway Product $id with delay" "GET" "$UPSTREAM_URL/gateway/products/${id}?delayMs=100" "200"
done

echo ""
echo -e "${CYAN}========================================"
echo -e "Testing Complete!"
echo -e "${YELLOW}Check Application Insights for:"
echo -e "${WHITE}  - End-to-end transaction details"
echo -e "  - Performance metrics"
echo -e "  - Error traces and exceptions"
echo -e "  - Dependency calls between services"
echo -e "${CYAN}========================================${NC}"