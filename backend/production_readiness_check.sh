#!/bin/bash

# Production Readiness Check - Simplified Version

set -e

PROJECT_ID="universal-translator-prod"
SERVICE_NAME="universal-translator-api"
API_URL="https://universal-translator-api-jzqoowo3tq-uc.a.run.app"

echo "🚀 PRODUCTION READINESS CHECK"
echo "=============================================="
echo "Project: ${PROJECT_ID}"
echo "Service: ${SERVICE_NAME}"
echo "API URL: ${API_URL}"
echo "=============================================="

PASSED=0
FAILED=0
WARNINGS=0

check_result() {
    local name="$1"
    local status="$2"
    local message="$3"
    
    case $status in
        "PASS")
            echo "✅ $name: $message"
            PASSED=$((PASSED + 1))
            ;;
        "FAIL")
            echo "❌ $name: $message"
            FAILED=$((FAILED + 1))
            ;;
        "WARN")
            echo "⚠️  $name: $message"
            WARNINGS=$((WARNINGS + 1))
            ;;
    esac
}

echo ""
echo "🏥 HEALTH CHECKS"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# 1. Health Endpoint
echo "Testing health endpoint..."
health_status=$(curl -s -o /dev/null -w "%{http_code}" "${API_URL}/health" || echo "000")
if [ "$health_status" = "200" ]; then
    check_result "Health Endpoint" "PASS" "Service responding (HTTP 200)"
else
    check_result "Health Endpoint" "FAIL" "Service not responding (HTTP $health_status)"
fi

# 2. Translation API
echo "Testing translation API..."
translation_test=$(curl -s -w "%{http_code}" \
    -X POST "${API_URL}/v1/translate" \
    -H "Content-Type: application/json" \
    -d '{"text":"Hello","source_language":"en","target_language":"es"}')

translation_status=$(echo "$translation_test" | tail -c 4)
if [ "$translation_status" = "200" ]; then
    check_result "Translation API" "PASS" "Translation working (HTTP 200)"
else
    check_result "Translation API" "FAIL" "Translation failed (HTTP $translation_status)"
fi

# 3. Voice Translation API
echo "Testing voice translation API..."
voice_status=$(curl -s -o /dev/null -w "%{http_code}" \
    -X POST "${API_URL}/v1/translate/audio" \
    -H "Content-Type: application/json" \
    -d '{"text":"Hello","source_language":"en","target_language":"es","return_audio":true}' || echo "000")

if [ "$voice_status" = "200" ]; then
    check_result "Voice Translation" "PASS" "Voice API working (HTTP 200)"
else
    check_result "Voice Translation" "FAIL" "Voice API failed (HTTP $voice_status)"
fi

# 4. Languages Endpoint
echo "Testing languages endpoint..."
languages_status=$(curl -s -o /dev/null -w "%{http_code}" "${API_URL}/v1/languages" || echo "000")
if [ "$languages_status" = "200" ]; then
    check_result "Languages API" "PASS" "Languages endpoint working (HTTP 200)"
else
    check_result "Languages API" "FAIL" "Languages endpoint failed (HTTP $languages_status)"
fi

echo ""
echo "🔒 SECURITY CHECKS"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# 5. HTTPS Check
echo "Verifying HTTPS..."
if curl -s --head "${API_URL}/health" | grep -q "HTTP"; then
    check_result "HTTPS" "PASS" "HTTPS connection successful"
else
    check_result "HTTPS" "FAIL" "HTTPS connection failed"
fi

# 6. Rate Limiting Test
echo "Testing rate limiting (sending 12 requests)..."
rate_limit_blocked=0
for i in {1..12}; do
    status=$(curl -s -o /dev/null -w "%{http_code}" \
        -X POST "${API_URL}/v1/translate" \
        -H "Content-Type: application/json" \
        -d "{\"text\":\"Test $i\",\"source_language\":\"en\",\"target_language\":\"es\"}")
    
    if [ "$status" = "429" ]; then
        rate_limit_blocked=$((rate_limit_blocked + 1))
    fi
    sleep 0.1
done

if [ "$rate_limit_blocked" -gt 0 ]; then
    check_result "Rate Limiting" "PASS" "$rate_limit_blocked requests blocked"
else
    check_result "Rate Limiting" "WARN" "No rate limiting detected"
fi

echo ""
echo "🏗️ INFRASTRUCTURE CHECKS"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# 7. Cloud Run Service
echo "Checking Cloud Run service..."
if gcloud run services describe ${SERVICE_NAME} --region=us-central1 --quiet >/dev/null 2>&1; then
    check_result "Cloud Run Service" "PASS" "Service exists and accessible"
else
    check_result "Cloud Run Service" "FAIL" "Service not found or inaccessible"
fi

# 8. Redis Connectivity
echo "Testing Redis connectivity..."
redis_host="10.36.156.179"
if timeout 3 bash -c "</dev/tcp/${redis_host}/6379" 2>/dev/null; then
    check_result "Redis Connection" "PASS" "Redis accessible"
else
    check_result "Redis Connection" "WARN" "Redis connection test failed"
fi

# 9. Secret Manager
echo "Testing Secret Manager access..."
if gcloud secrets versions access latest --secret="gemini-api-key" --project=${PROJECT_ID} >/dev/null 2>&1; then
    check_result "Secret Manager" "PASS" "Secrets accessible"
else
    check_result "Secret Manager" "FAIL" "Cannot access secrets"
fi

echo ""
echo "📊 PERFORMANCE CHECKS"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# 10. Response Time Test
echo "Testing response times (5 requests)..."
total_time=0
successful_requests=0

for i in {1..5}; do
    start_time=$(date +%s.%N)
    status=$(curl -s -o /dev/null -w "%{http_code}" \
        -X POST "${API_URL}/v1/translate" \
        -H "Content-Type: application/json" \
        -d "{\"text\":\"Performance test $i\",\"source_language\":\"en\",\"target_language\":\"es\"}")
    end_time=$(date +%s.%N)
    
    if [ "$status" = "200" ]; then
        request_time=$(echo "$end_time - $start_time" | bc -l)
        total_time=$(echo "$total_time + $request_time" | bc -l)
        successful_requests=$((successful_requests + 1))
    fi
    sleep 0.5
done

if [ "$successful_requests" -gt 0 ]; then
    avg_time=$(echo "scale=2; $total_time / $successful_requests" | bc -l)
    if (( $(echo "$avg_time < 3.0" | bc -l) )); then
        check_result "Response Time" "PASS" "Average: ${avg_time}s"
    else
        check_result "Response Time" "WARN" "Average: ${avg_time}s (slow)"
    fi
else
    check_result "Response Time" "FAIL" "No successful requests"
fi

echo ""
echo "📝 LOGGING CHECKS"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# 11. Recent Logs
echo "Checking for recent logs..."
recent_logs=$(gcloud logging read "resource.type=cloud_run_revision AND resource.labels.service_name=${SERVICE_NAME}" \
    --limit=1 --format="text(timestamp)" 2>/dev/null | wc -l)

if [ "$recent_logs" -gt 0 ]; then
    check_result "Logging System" "PASS" "Recent logs available"
else
    check_result "Logging System" "WARN" "No recent logs found"
fi

# 12. Error Logs
echo "Checking for recent errors..."
error_count=$(gcloud logging read "resource.type=cloud_run_revision AND resource.labels.service_name=${SERVICE_NAME} AND severity>=ERROR" \
    --limit=5 --format="text(timestamp)" 2>/dev/null | wc -l)

if [ "$error_count" -eq 0 ]; then
    check_result "Error Rate" "PASS" "No recent errors"
elif [ "$error_count" -lt 3 ]; then
    check_result "Error Rate" "WARN" "$error_count recent errors"
else
    check_result "Error Rate" "FAIL" "$error_count recent errors"
fi

echo ""
echo "📋 SUMMARY"
echo "=============================================="
total_checks=$((PASSED + FAILED + WARNINGS))
echo "Total Checks: $total_checks"
echo "✅ Passed: $PASSED"
echo "⚠️  Warnings: $WARNINGS"
echo "❌ Failed: $FAILED"
echo "=============================================="

success_rate=$(echo "scale=1; ($PASSED * 100) / $total_checks" | bc -l)
echo "Success Rate: ${success_rate}%"

if [ "$FAILED" -eq 0 ] && [ "$WARNINGS" -le 2 ]; then
    echo ""
    echo "🎉 PRODUCTION READY!"
    echo "✅ System ready for production deployment"
    exit 0
elif [ "$FAILED" -eq 0 ]; then
    echo ""
    echo "⚠️  PRODUCTION READY WITH WARNINGS"
    echo "✅ No critical failures"
    echo "⚠️  Address warnings when possible"
    exit 0
else
    echo ""
    echo "❌ NOT READY FOR PRODUCTION"
    echo "❌ Critical failures must be fixed"
    exit 1
fi
