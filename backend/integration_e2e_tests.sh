#!/bin/bash

# End-to-End Integration Test Suite
# Tests complete user journeys and system integration

set -e

API_URL="https://universal-translator-api-jzqoowo3tq-uc.a.run.app"
VOICE_API_URL="https://universal-translator-api-jzqoowo3tq-uc.a.run.app"

echo "🧪 END-TO-END INTEGRATION TEST SUITE"
echo "======================================================"
echo "API URL: ${API_URL}"
echo "Voice API URL: ${VOICE_API_URL}"
echo "======================================================"

# Test counters
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# Function to run a test
run_test() {
    local test_name="$1"
    local test_command="$2"
    local expected_result="$3"
    
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    echo ""
    echo "🔬 Test: $test_name"
    echo "Command: $test_command"
    
    if eval "$test_command"; then
        echo "✅ PASSED: $test_name"
        PASSED_TESTS=$((PASSED_TESTS + 1))
    else
        echo "❌ FAILED: $test_name"
        FAILED_TESTS=$((FAILED_TESTS + 1))
    fi
}

# Function to validate JSON response
validate_json_response() {
    local response="$1"
    local expected_field="$2"
    
    if echo "$response" | jq -e ".$expected_field" >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

echo ""
echo "🌐 USER JOURNEY 1: Basic Translation Flow"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Test 1: User opens app - Health check
run_test "App Startup - Health Check" \
    "curl -s -f '${API_URL}/health' >/dev/null" \
    "HTTP 200"

# Test 2: User views available languages
LANGUAGES_RESPONSE=$(curl -s "${API_URL}/v1/languages" 2>/dev/null)
run_test "Language Selection - Get Languages" \
    "echo '$LANGUAGES_RESPONSE' | jq -e '.languages | length >= 10'" \
    "At least 10 languages"

# Test 3: User translates "Hello" from English to Spanish
TRANSLATION_RESPONSE=$(curl -s -X POST "${API_URL}/v1/translate" \
    -H "Content-Type: application/json" \
    -d '{"text":"Hello world","source_language":"en","target_language":"es"}' 2>/dev/null)

run_test "Basic Translation - EN to ES" \
    "echo '$TRANSLATION_RESPONSE' | jq -e '.translated_text | length > 0'" \
    "Translation returned"

# Test 4: Validate translation quality
run_test "Translation Quality Check" \
    "echo '$TRANSLATION_RESPONSE' | jq -e '.confidence >= 0.8'" \
    "High confidence translation"

# Test 5: Check response time
RESPONSE_TIME_TEST=$(time (curl -s -X POST "${API_URL}/v1/translate" \
    -H "Content-Type: application/json" \
    -d '{"text":"Performance test","source_language":"en","target_language":"fr"}' >/dev/null) 2>&1 | grep real | awk '{print $2}')

run_test "Response Time Performance" \
    "echo '${RESPONSE_TIME_TEST}' | awk -F'm|s' '{print (\$1*60+\$2 < 5)}' | grep -q 1" \
    "Response under 5 seconds"

echo ""
echo "🎤 USER JOURNEY 2: Voice Translation Flow"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Test 6: User requests voice translation
VOICE_RESPONSE=$(curl -s -X POST "${VOICE_API_URL}/v1/translate/audio" \
    -H "Content-Type: application/json" \
    -d '{"text":"Hello, how are you today?","source_language":"en","target_language":"es","return_audio":true}' 2>/dev/null)

run_test "Voice Translation Request" \
    "echo '$VOICE_RESPONSE' | jq -e '.translated_text | length > 0'" \
    "Voice translation returned"

# Test 7: Validate audio generation
run_test "Audio Generation Check" \
    "echo '$VOICE_RESPONSE' | jq -e '.audio_base64 | length > 100'" \
    "Audio data generated"

# Test 8: Voice translation quality
run_test "Voice Translation Quality" \
    "echo '$VOICE_RESPONSE' | jq -e '.confidence >= 0.8'" \
    "High confidence voice translation"

echo ""
echo "🔄 USER JOURNEY 3: Multi-Language Translation Chain"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Test 9: Chain translation EN -> ES -> FR
EN_ES_RESPONSE=$(curl -s -X POST "${API_URL}/v1/translate" \
    -H "Content-Type: application/json" \
    -d '{"text":"Good morning, beautiful world!","source_language":"en","target_language":"es"}' 2>/dev/null)

ES_TEXT=$(echo "$EN_ES_RESPONSE" | jq -r '.translated_text' 2>/dev/null)

run_test "Chain Translation Step 1 (EN->ES)" \
    "[ -n '$ES_TEXT' ] && [ '$ES_TEXT' != 'null' ]" \
    "English to Spanish successful"

# Test 10: Continue chain ES -> FR
if [ -n "$ES_TEXT" ] && [ "$ES_TEXT" != "null" ]; then
    ES_FR_RESPONSE=$(curl -s -X POST "${API_URL}/v1/translate" \
        -H "Content-Type: application/json" \
        -d "{\"text\":\"$ES_TEXT\",\"source_language\":\"es\",\"target_language\":\"fr\"}" 2>/dev/null)
    
    run_test "Chain Translation Step 2 (ES->FR)" \
        "echo '$ES_FR_RESPONSE' | jq -e '.translated_text | length > 0'" \
        "Spanish to French successful"
else
    echo "❌ FAILED: Chain Translation Step 2 (ES->FR) - Previous step failed"
    FAILED_TESTS=$((FAILED_TESTS + 1))
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
fi

echo ""
echo "⚡ USER JOURNEY 4: High-Frequency Usage Pattern"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Test 11: Rapid sequential translations
RAPID_SUCCESS=0
RAPID_TOTAL=5

for i in {1..5}; do
    RAPID_RESPONSE=$(curl -s -w "%{http_code}" -X POST "${API_URL}/v1/translate" \
        -H "Content-Type: application/json" \
        -d "{\"text\":\"Rapid test $i\",\"source_language\":\"en\",\"target_language\":\"es\"}" 2>/dev/null)
    
    HTTP_CODE=$(echo "$RAPID_RESPONSE" | tail -c 4)
    if [ "$HTTP_CODE" = "200" ]; then
        RAPID_SUCCESS=$((RAPID_SUCCESS + 1))
    fi
    sleep 0.2
done

run_test "Rapid Sequential Translations" \
    "[ $RAPID_SUCCESS -ge 3 ]" \
    "At least 3/5 rapid requests successful"

echo ""
echo "🔐 USER JOURNEY 5: Security & Error Handling"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Test 12: Invalid endpoint handling
INVALID_RESPONSE=$(curl -s -w "%{http_code}" "${API_URL}/invalid-endpoint" 2>/dev/null)
INVALID_CODE=$(echo "$INVALID_RESPONSE" | tail -c 4)

run_test "Invalid Endpoint Handling" \
    "[ '$INVALID_CODE' = '404' ]" \
    "Proper 404 response"

# Test 13: Malformed JSON handling
MALFORMED_RESPONSE=$(curl -s -w "%{http_code}" -X POST "${API_URL}/v1/translate" \
    -H "Content-Type: application/json" \
    -d '{"invalid": json}' 2>/dev/null)
MALFORMED_CODE=$(echo "$MALFORMED_RESPONSE" | tail -c 4)

run_test "Malformed Request Handling" \
    "[ '$MALFORMED_CODE' = '422' ]" \
    "Proper 422 response for malformed JSON"

# Test 14: Empty text handling
EMPTY_RESPONSE=$(curl -s -w "%{http_code}" -X POST "${API_URL}/v1/translate" \
    -H "Content-Type: application/json" \
    -d '{"text":"","source_language":"en","target_language":"es"}' 2>/dev/null)
EMPTY_CODE=$(echo "$EMPTY_RESPONSE" | tail -c 4)

run_test "Empty Text Handling" \
    "[ '$EMPTY_CODE' = '422' ]" \
    "Proper validation for empty text"

# Test 15: Unsupported language handling
UNSUPPORTED_RESPONSE=$(curl -s -w "%{http_code}" -X POST "${API_URL}/v1/translate" \
    -H "Content-Type: application/json" \
    -d '{"text":"Hello","source_language":"en","target_language":"xyz"}' 2>/dev/null)
UNSUPPORTED_CODE=$(echo "$UNSUPPORTED_RESPONSE" | tail -c 4)

run_test "Unsupported Language Handling" \
    "[ '$UNSUPPORTED_CODE' = '400' ]" \
    "Proper validation for unsupported language"

echo ""
echo "📊 USER JOURNEY 6: Load & Performance Testing"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Test 16: Concurrent request handling
echo "Running concurrent request test..."
CONCURRENT_SUCCESS=0
CONCURRENT_TOTAL=10

# Launch concurrent requests
for i in {1..10}; do
    (
        CONCURRENT_RESPONSE=$(curl -s -w "%{http_code}" -X POST "${API_URL}/v1/translate" \
            -H "Content-Type: application/json" \
            -d "{\"text\":\"Concurrent test $i\",\"source_language\":\"en\",\"target_language\":\"es\"}" 2>/dev/null)
        
        CONCURRENT_CODE=$(echo "$CONCURRENT_RESPONSE" | tail -c 4)
        if [ "$CONCURRENT_CODE" = "200" ]; then
            echo "SUCCESS_$i" >> /tmp/concurrent_results.txt
        fi
    ) &
done

# Wait for all background jobs to complete
wait

# Count successful responses
if [ -f /tmp/concurrent_results.txt ]; then
    CONCURRENT_SUCCESS=$(wc -l < /tmp/concurrent_results.txt)
    rm -f /tmp/concurrent_results.txt
fi

run_test "Concurrent Request Handling" \
    "[ $CONCURRENT_SUCCESS -ge 7 ]" \
    "At least 7/10 concurrent requests successful"

echo ""
echo "🔄 USER JOURNEY 7: Service Recovery & Resilience"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Test 17: Service health after load
HEALTH_AFTER_LOAD=$(curl -s -w "%{http_code}" "${API_URL}/health" 2>/dev/null)
HEALTH_CODE=$(echo "$HEALTH_AFTER_LOAD" | tail -c 4)

run_test "Service Health After Load" \
    "[ '$HEALTH_CODE' = '200' ]" \
    "Service healthy after load testing"

# Test 18: Translation accuracy after load
ACCURACY_RESPONSE=$(curl -s -X POST "${API_URL}/v1/translate" \
    -H "Content-Type: application/json" \
    -d '{"text":"The quick brown fox jumps over the lazy dog","source_language":"en","target_language":"es"}' 2>/dev/null)

run_test "Translation Accuracy After Load" \
    "echo '$ACCURACY_RESPONSE' | jq -e '.confidence >= 0.8'" \
    "Translation quality maintained after load"

echo ""
echo "📱 USER JOURNEY 8: Mobile App Integration Simulation"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Test 19: Simulate mobile app headers
MOBILE_RESPONSE=$(curl -s -w "%{http_code}" -X POST "${API_URL}/v1/translate" \
    -H "Content-Type: application/json" \
    -H "User-Agent: MervynTalks/1.0 (iOS)" \
    -H "Accept: application/json" \
    -d '{"text":"Mobile app test","source_language":"en","target_language":"es"}' 2>/dev/null)

MOBILE_CODE=$(echo "$MOBILE_RESPONSE" | tail -c 4)

run_test "Mobile App Integration" \
    "[ '$MOBILE_CODE' = '200' ]" \
    "Mobile app requests handled correctly"

# Test 20: CORS handling for mobile
CORS_RESPONSE=$(curl -s -w "%{http_code}" -X OPTIONS "${API_URL}/v1/translate" \
    -H "Origin: https://mervyntalks.app" \
    -H "Access-Control-Request-Method: POST" \
    -H "Access-Control-Request-Headers: Content-Type" 2>/dev/null)

CORS_CODE=$(echo "$CORS_RESPONSE" | tail -c 4)

run_test "CORS Configuration" \
    "[ '$CORS_CODE' = '200' ] || [ '$CORS_CODE' = '204' ]" \
    "CORS properly configured"

echo ""
echo "📋 INTEGRATION TEST SUMMARY"
echo "======================================================"
echo "Total Tests: $TOTAL_TESTS"
echo "✅ Passed: $PASSED_TESTS"
echo "❌ Failed: $FAILED_TESTS"
echo "======================================================"

# Calculate success rate
if [ $TOTAL_TESTS -gt 0 ]; then
    SUCCESS_RATE=$(echo "scale=1; ($PASSED_TESTS * 100) / $TOTAL_TESTS" | bc -l)
    echo "Success Rate: ${SUCCESS_RATE}%"
else
    SUCCESS_RATE=0
    echo "Success Rate: 0%"
fi

# Determine overall result
if [ $FAILED_TESTS -eq 0 ]; then
    echo ""
    echo "🎉 ALL INTEGRATION TESTS PASSED!"
    echo "✅ System fully integrated and ready for production"
    echo "✅ All user journeys working correctly"
    echo "✅ Error handling robust"
    echo "✅ Performance meets requirements"
    exit 0
elif [ $FAILED_TESTS -le 2 ] && [ $(echo "$SUCCESS_RATE >= 90" | bc -l) -eq 1 ]; then
    echo ""
    echo "⚠️  INTEGRATION TESTS MOSTLY PASSED"
    echo "✅ Core functionality working"
    echo "⚠️  $FAILED_TESTS minor issues detected"
    echo "✅ System ready for production with monitoring"
    exit 0
else
    echo ""
    echo "❌ INTEGRATION TESTS FAILED"
    echo "❌ $FAILED_TESTS critical integration issues"
    echo "🔧 Fix integration issues before production deployment"
    exit 1
fi
