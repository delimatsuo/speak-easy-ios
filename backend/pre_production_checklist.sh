#!/bin/bash

# Pre-Production Deployment Checklist
# Comprehensive validation before production launch

set -e

PROJECT_ID="universal-translator-prod"
SERVICE_NAME="universal-translator-api"
REGION="us-central1"
API_URL="https://universal-translator-api-jzqoowo3tq-uc.a.run.app"

echo "🚀 PRE-PRODUCTION DEPLOYMENT CHECKLIST"
echo "======================================================"
echo "Project: ${PROJECT_ID}"
echo "Service: ${SERVICE_NAME}"
echo "Region: ${REGION}"
echo "API URL: ${API_URL}"
echo "======================================================"

# Initialize counters
TOTAL_CHECKS=0
PASSED_CHECKS=0
FAILED_CHECKS=0
WARNING_CHECKS=0

# Function to log results
log_result() {
    local test_name="$1"
    local status="$2"
    local message="$3"
    
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    
    case $status in
        "PASS")
            echo "✅ $test_name: PASS - $message"
            PASSED_CHECKS=$((PASSED_CHECKS + 1))
            ;;
        "FAIL")
            echo "❌ $test_name: FAIL - $message"
            FAILED_CHECKS=$((FAILED_CHECKS + 1))
            ;;
        "WARN")
            echo "⚠️  $test_name: WARNING - $message"
            WARNING_CHECKS=$((WARNING_CHECKS + 1))
            ;;
    esac
}

echo ""
echo "🏥 HEALTH & AVAILABILITY CHECKS"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# 1. Service Health Check
echo "Checking service health..."
health_response=$(curl -s -w "%{http_code}" "${API_URL}/health" || echo "000")
health_code=$(echo "$health_response" | tail -c 4)

if [ "$health_code" = "200" ]; then
    health_data=$(echo "$health_response" | head -n -1)
    service_status=$(echo "$health_data" | jq -r '.status' 2>/dev/null || echo "unknown")
    uptime=$(echo "$health_data" | jq -r '.uptime_seconds' 2>/dev/null || echo "0")
    
    if [ "$service_status" = "healthy" ]; then
        log_result "Service Health" "PASS" "Service healthy, uptime: ${uptime}s"
    else
        log_result "Service Health" "FAIL" "Service status: $service_status"
    fi
else
    log_result "Service Health" "FAIL" "HTTP $health_code - Service unreachable"
fi

# 2. Translation Endpoint Test
echo "Testing translation endpoint..."
translation_response=$(curl -s -w "%{http_code}" \
    -X POST "${API_URL}/v1/translate" \
    -H "Content-Type: application/json" \
    -d '{"text":"Production test","source_language":"en","target_language":"es"}' || echo "000")
translation_code=$(echo "$translation_response" | tail -c 4)

if [ "$translation_code" = "200" ]; then
    translation_data=$(echo "$translation_response" | head -n -1)
    translated_text=$(echo "$translation_data" | jq -r '.translated_text' 2>/dev/null || echo "")
    confidence=$(echo "$translation_data" | jq -r '.confidence' 2>/dev/null || echo "0")
    
    if [ -n "$translated_text" ] && [ "$translated_text" != "null" ]; then
        log_result "Translation API" "PASS" "Translation successful, confidence: $confidence"
    else
        log_result "Translation API" "FAIL" "Translation returned empty result"
    fi
else
    log_result "Translation API" "FAIL" "HTTP $translation_code - Translation failed"
fi

# 3. Voice Translation Test
echo "Testing voice translation endpoint..."
voice_response=$(curl -s -w "%{http_code}" \
    -X POST "${API_URL}/v1/translate/audio" \
    -H "Content-Type: application/json" \
    -d '{"text":"Voice test","source_language":"en","target_language":"es","return_audio":true}' || echo "000")
voice_code=$(echo "$voice_response" | tail -c 4)

if [ "$voice_code" = "200" ]; then
    voice_data=$(echo "$voice_response" | head -n -1)
    audio_data=$(echo "$voice_data" | jq -r '.audio_base64' 2>/dev/null || echo "")
    
    if [ -n "$audio_data" ] && [ "$audio_data" != "null" ]; then
        log_result "Voice Translation" "PASS" "Voice translation with audio successful"
    else
        log_result "Voice Translation" "WARN" "Voice translation without audio"
    fi
else
    log_result "Voice Translation" "FAIL" "HTTP $voice_code - Voice translation failed"
fi

# 4. Languages Endpoint Test
echo "Testing languages endpoint..."
languages_response=$(curl -s -w "%{http_code}" "${API_URL}/v1/languages" || echo "000")
languages_code=$(echo "$languages_response" | tail -c 4)

if [ "$languages_code" = "200" ]; then
    languages_data=$(echo "$languages_response" | head -n -1)
    language_count=$(echo "$languages_data" | jq '.languages | length' 2>/dev/null || echo "0")
    
    if [ "$language_count" -ge "10" ]; then
        log_result "Languages API" "PASS" "$language_count languages available"
    else
        log_result "Languages API" "WARN" "Only $language_count languages available"
    fi
else
    log_result "Languages API" "FAIL" "HTTP $languages_code - Languages endpoint failed"
fi

echo ""
echo "🔒 SECURITY VALIDATION"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# 5. HTTPS Verification
echo "Verifying HTTPS configuration..."
if curl -s --head "${API_URL}/health" | grep -q "HTTP/2"; then
    log_result "HTTPS Protocol" "PASS" "HTTP/2 over TLS active"
else
    log_result "HTTPS Protocol" "FAIL" "HTTPS not properly configured"
fi

# 6. Security Headers Check
echo "Checking security headers..."
security_headers=$(curl -s -I "${API_URL}/health")

if echo "$security_headers" | grep -qi "server.*Google Frontend"; then
    log_result "Server Header" "PASS" "Google Frontend proxy active"
else
    log_result "Server Header" "WARN" "Server header not as expected"
fi

if echo "$security_headers" | grep -qi "content-type.*application/json"; then
    log_result "Content-Type" "PASS" "Proper content-type headers"
else
    log_result "Content-Type" "WARN" "Content-type headers missing"
fi

# 7. Rate Limiting Test
echo "Testing rate limiting..."
rate_limit_success=0
rate_limit_blocked=0

for i in {1..12}; do
    response=$(curl -s -w "%{http_code}" \
        -X POST "${API_URL}/v1/translate" \
        -H "Content-Type: application/json" \
        -d "{\"text\":\"Rate limit test $i\",\"source_language\":\"en\",\"target_language\":\"es\"}" 2>/dev/null)
    
    status_code=$(echo "$response" | tail -c 4)
    
    if [ "$status_code" = "200" ]; then
        rate_limit_success=$((rate_limit_success + 1))
    elif [ "$status_code" = "429" ]; then
        rate_limit_blocked=$((rate_limit_blocked + 1))
    fi
    
    sleep 0.1
done

if [ "$rate_limit_blocked" -gt 0 ]; then
    log_result "Rate Limiting" "PASS" "$rate_limit_blocked requests blocked, $rate_limit_success allowed"
elif [ "$rate_limit_success" -eq 12 ]; then
    log_result "Rate Limiting" "WARN" "All requests succeeded - rate limiting may be disabled"
else
    log_result "Rate Limiting" "FAIL" "Unexpected rate limiting behavior"
fi

echo ""
echo "🏗️ INFRASTRUCTURE CHECKS"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# 8. Cloud Run Service Status
echo "Checking Cloud Run service status..."
service_status=$(gcloud run services describe ${SERVICE_NAME} \
    --region=${REGION} \
    --format='value(status.conditions[0].status)' 2>/dev/null || echo "Unknown")

if [ "$service_status" = "True" ]; then
    log_result "Cloud Run Status" "PASS" "Service ready and serving traffic"
else
    log_result "Cloud Run Status" "FAIL" "Service status: $service_status"
fi

# 9. Redis Connection Test
echo "Checking Redis connectivity..."
redis_host="10.36.156.179"
if timeout 5 bash -c "</dev/tcp/${redis_host}/6379" 2>/dev/null; then
    log_result "Redis Connectivity" "PASS" "Redis accessible at $redis_host:6379"
else
    log_result "Redis Connectivity" "WARN" "Redis connection test failed"
fi

# 10. Secret Manager Access
echo "Checking Secret Manager access..."
secret_test=$(gcloud secrets versions access latest --secret="gemini-api-key" --project=${PROJECT_ID} 2>/dev/null)
if [ $? -eq 0 ] && [ -n "$secret_test" ]; then
    log_result "Secret Manager" "PASS" "API key accessible from Secret Manager"
else
    log_result "Secret Manager" "FAIL" "Cannot access secrets"
fi

echo ""
echo "📊 PERFORMANCE CHECKS"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# 11. Response Time Test
echo "Testing response times..."
total_time=0
successful_requests=0

for i in {1..5}; do
    start_time=$(date +%s.%N)
    response=$(curl -s -w "%{http_code}" \
        -X POST "${API_URL}/v1/translate" \
        -H "Content-Type: application/json" \
        -d "{\"text\":\"Performance test $i\",\"source_language\":\"en\",\"target_language\":\"es\"}")
    end_time=$(date +%s.%N)
    
    status_code=$(echo "$response" | tail -c 4)
    
    if [ "$status_code" = "200" ]; then
        request_time=$(echo "$end_time - $start_time" | bc)
        total_time=$(echo "$total_time + $request_time" | bc)
        successful_requests=$((successful_requests + 1))
    fi
    
    sleep 1
done

if [ "$successful_requests" -gt 0 ]; then
    avg_time=$(echo "scale=3; $total_time / $successful_requests" | bc)
    if (( $(echo "$avg_time < 3.0" | bc -l) )); then
        log_result "Response Time" "PASS" "Average response time: ${avg_time}s"
    elif (( $(echo "$avg_time < 5.0" | bc -l) )); then
        log_result "Response Time" "WARN" "Average response time: ${avg_time}s (acceptable)"
    else
        log_result "Response Time" "FAIL" "Average response time: ${avg_time}s (too slow)"
    fi
else
    log_result "Response Time" "FAIL" "No successful requests for timing"
fi

echo ""
echo "📝 LOGGING & MONITORING"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# 12. Log Availability
echo "Checking log availability..."
recent_logs=$(gcloud logging read "resource.type=cloud_run_revision AND resource.labels.service_name=${SERVICE_NAME}" \
    --limit=5 --format="text(timestamp)" 2>/dev/null | wc -l)

if [ "$recent_logs" -gt 0 ]; then
    log_result "Logging System" "PASS" "$recent_logs recent log entries found"
else
    log_result "Logging System" "WARN" "No recent logs found"
fi

# 13. Error Rate Check
echo "Checking error rates..."
error_logs=$(gcloud logging read "resource.type=cloud_run_revision AND resource.labels.service_name=${SERVICE_NAME} AND severity>=ERROR" \
    --limit=10 --format="text(timestamp)" 2>/dev/null | wc -l)

if [ "$error_logs" -eq 0 ]; then
    log_result "Error Rate" "PASS" "No recent errors in logs"
elif [ "$error_logs" -lt 5 ]; then
    log_result "Error Rate" "WARN" "$error_logs recent errors found"
else
    log_result "Error Rate" "FAIL" "$error_logs recent errors found"
fi

echo ""
echo "🔧 CONFIGURATION AUDIT"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# 14. Environment Variables
echo "Checking environment configuration..."
service_config=$(gcloud run services describe ${SERVICE_NAME} --region=${REGION} --format=json 2>/dev/null)

if echo "$service_config" | jq -e '.spec.template.spec.containers[0].env[] | select(.name=="ENVIRONMENT") | select(.value=="production")' >/dev/null 2>&1; then
    log_result "Environment Config" "PASS" "Production environment configured"
else
    log_result "Environment Config" "FAIL" "Environment not set to production"
fi

if echo "$service_config" | jq -e '.spec.template.spec.containers[0].env[] | select(.name=="REDIS_URL")' >/dev/null 2>&1; then
    log_result "Redis Config" "PASS" "Redis URL configured"
else
    log_result "Redis Config" "WARN" "Redis URL not configured"
fi

# 15. Resource Limits
echo "Checking resource configuration..."
memory_limit=$(echo "$service_config" | jq -r '.spec.template.spec.containers[0].resources.limits.memory' 2>/dev/null || echo "null")
cpu_limit=$(echo "$service_config" | jq -r '.spec.template.spec.containers[0].resources.limits.cpu' 2>/dev/null || echo "null")

if [ "$memory_limit" != "null" ] && [ "$cpu_limit" != "null" ]; then
    log_result "Resource Limits" "PASS" "Memory: $memory_limit, CPU: $cpu_limit"
else
    log_result "Resource Limits" "WARN" "Resource limits not properly configured"
fi

echo ""
echo "📋 FINAL SUMMARY"
echo "======================================================"
echo "Total Checks: $TOTAL_CHECKS"
echo "✅ Passed: $PASSED_CHECKS"
echo "⚠️  Warnings: $WARNING_CHECKS"
echo "❌ Failed: $FAILED_CHECKS"
echo "======================================================"

# Calculate success rate
success_rate=$(echo "scale=1; ($PASSED_CHECKS * 100) / $TOTAL_CHECKS" | bc)
echo "Success Rate: ${success_rate}%"

# Determine overall status
if [ "$FAILED_CHECKS" -eq 0 ] && [ "$WARNING_CHECKS" -le 3 ]; then
    echo ""
    echo "🎉 PRODUCTION READY!"
    echo "✅ All critical checks passed"
    echo "✅ System ready for production deployment"
    exit 0
elif [ "$FAILED_CHECKS" -eq 0 ]; then
    echo ""
    echo "⚠️  PRODUCTION READY WITH WARNINGS"
    echo "✅ No critical failures detected"
    echo "⚠️  $WARNING_CHECKS warnings need attention"
    exit 0
else
    echo ""
    echo "❌ NOT READY FOR PRODUCTION"
    echo "❌ $FAILED_CHECKS critical failures detected"
    echo "🔧 Fix failures before deploying to production"
    exit 1
fi
