#!/bin/bash

# Security testing script using curl

API_URL="https://universal-translator-api-jzqoowo3tq-uc.a.run.app"

echo "🔐 Security Testing Suite"
echo "=" $(printf '=%.0s' {1..50})

# Test 1: Health endpoint
echo ""
echo "🏥 Testing Health Endpoint"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
curl -s -w "  Status: %{http_code}\n  Response time: %{time_total}s\n" \
     -H "Accept: application/json" \
     "${API_URL}/health" | head -10

# Test 2: Basic translation
echo ""
echo "🌐 Testing Translation Endpoint"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Testing basic translation..."
curl -s -w "  Status: %{http_code}\n  Response time: %{time_total}s\n" \
     -X POST "${API_URL}/v1/translate" \
     -H "Content-Type: application/json" \
     -d '{"text":"Hello world","source_language":"en","target_language":"es"}' | head -5

# Test 3: Rate limiting (send multiple requests quickly)
echo ""
echo "🔄 Testing Rate Limiting"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Sending 10 rapid requests to test rate limiting..."

success_count=0
rate_limited_count=0
error_count=0

for i in {1..10}; do
    response=$(curl -s -w "%{http_code}" \
        -X POST "${API_URL}/v1/translate" \
        -H "Content-Type: application/json" \
        -d "{\"text\":\"Test message $i\",\"source_language\":\"en\",\"target_language\":\"es\"}")
    
    status_code=$(echo "$response" | tail -c 4)
    
    case $status_code in
        200)
            success_count=$((success_count + 1))
            echo "  Request $i: SUCCESS ✅"
            ;;
        429)
            rate_limited_count=$((rate_limited_count + 1))
            echo "  Request $i: RATE LIMITED ✅"
            ;;
        *)
            error_count=$((error_count + 1))
            echo "  Request $i: ERROR ($status_code) ❌"
            ;;
    esac
    
    # Small delay to avoid overwhelming
    sleep 0.1
done

echo ""
echo "📊 Rate Limiting Results:"
echo "  • Successful: $success_count"
echo "  • Rate limited: $rate_limited_count"
echo "  • Errors: $error_count"

if [ $rate_limited_count -gt 0 ] || [ $success_count -lt 10 ]; then
    echo "  ✅ Rate limiting appears to be working!"
else
    echo "  ⚠️  All requests succeeded - rate limiting may need adjustment"
fi

# Test 4: Security headers
echo ""
echo "🔒 Testing Security Headers"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Checking security headers..."
curl -s -I "${API_URL}/health" | grep -E "(HTTP|content-type|server|x-|strict-transport)"

# Test 5: HTTPS verification
echo ""
echo "🔐 Testing HTTPS"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if curl -s --head "${API_URL}/health" | grep -q "HTTP/"; then
    echo "  ✅ HTTPS connection successful"
else
    echo "  ❌ HTTPS connection failed"
fi

# Test 6: Invalid endpoints
echo ""
echo "🚫 Testing Invalid Endpoints"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Testing non-existent endpoint..."
curl -s -w "Status: %{http_code}\n" "${API_URL}/invalid-endpoint" | tail -1

echo "Testing malformed request..."
curl -s -w "Status: %{http_code}\n" \
     -X POST "${API_URL}/v1/translate" \
     -H "Content-Type: application/json" \
     -d '{"invalid": "json}' | tail -1

echo ""
echo "🎯 Security Testing Complete!"
echo "=" $(printf '=%.0s' {1..50})
