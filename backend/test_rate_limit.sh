#!/bin/bash

# Aggressive rate limiting test

API_URL="https://universal-translator-api-jzqoowo3tq-uc.a.run.app"

echo "🔄 Aggressive Rate Limiting Test"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Sending 15 rapid requests (limit is 10/minute)..."

success_count=0
rate_limited_count=0
error_count=0

# Send 15 requests as fast as possible
for i in {1..15}; do
    start_time=$(date +%s.%N)
    
    response=$(curl -s -w "%{http_code}" \
        -X POST "${API_URL}/v1/translate" \
        -H "Content-Type: application/json" \
        -d "{\"text\":\"Rapid test $i\",\"source_language\":\"en\",\"target_language\":\"es\"}")
    
    end_time=$(date +%s.%N)
    duration=$(echo "$end_time - $start_time" | bc)
    
    status_code=$(echo "$response" | tail -c 4)
    
    case $status_code in
        200)
            success_count=$((success_count + 1))
            echo "  Request $i: SUCCESS ✅ (${duration}s)"
            ;;
        429)
            rate_limited_count=$((rate_limited_count + 1))
            echo "  Request $i: RATE LIMITED ✅ (${duration}s)"
            ;;
        *)
            error_count=$((error_count + 1))
            echo "  Request $i: ERROR ($status_code) ❌ (${duration}s)"
            ;;
    esac
done

echo ""
echo "📊 Final Results:"
echo "  • Total requests: 15"
echo "  • Successful: $success_count"
echo "  • Rate limited: $rate_limited_count"
echo "  • Errors: $error_count"

if [ $rate_limited_count -gt 0 ]; then
    echo "  ✅ Rate limiting is working! $rate_limited_count requests were blocked."
elif [ $success_count -eq 15 ]; then
    echo "  ⚠️  All requests succeeded - rate limiting may need adjustment"
else
    echo "  ❓ Mixed results - check for other issues"
fi

echo ""
echo "🔍 Checking logs for rate limiting info..."
gcloud logging read "resource.type=cloud_run_revision AND resource.labels.service_name=universal-translator-api AND textPayload:*rate*" --limit 5 --format="text(textPayload)" | head -10
