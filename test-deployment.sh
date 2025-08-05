#!/bin/bash
# test-deployment.sh - Comprehensive deployment testing script

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SERVICE_NAME="universal-translator-api"
REGION="us-central1"
PROJECT_ID="universal-translator-prod"

# Helper functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Get service URL
get_service_url() {
    SERVICE_URL=$(gcloud run services describe ${SERVICE_NAME} \
        --platform managed \
        --region ${REGION} \
        --format 'value(status.url)' 2>/dev/null)
    
    if [ -z "$SERVICE_URL" ]; then
        log_error "Could not get service URL. Is the service deployed?"
        exit 1
    fi
    
    echo "$SERVICE_URL"
}

# Test health endpoint
test_health() {
    log_info "Testing health endpoint..."
    
    local url="$1/health"
    local response=$(curl -s -w "%{http_code}" -o /tmp/health_response.json "$url")
    local http_code="${response: -3}"
    
    if [ "$http_code" = "200" ]; then
        log_success "Health check passed (HTTP $http_code)"
        
        # Show health details
        if command -v jq &> /dev/null; then
            echo "Health Details:"
            cat /tmp/health_response.json | jq .
        else
            cat /tmp/health_response.json
        fi
        return 0
    else
        log_error "Health check failed (HTTP $http_code)"
        cat /tmp/health_response.json
        return 1
    fi
}

# Test translation endpoint
test_translation() {
    log_info "Testing translation endpoint..."
    
    local url="$1/v1/translate"
    local test_data='{
        "text": "Hello, world! How are you today?",
        "source_language": "en",
        "target_language": "es"
    }'
    
    local response=$(curl -s -w "%{http_code}" -o /tmp/translation_response.json \
        -X POST "$url" \
        -H "Content-Type: application/json" \
        -d "$test_data")
    
    local http_code="${response: -3}"
    
    if [ "$http_code" = "200" ]; then
        log_success "Translation test passed (HTTP $http_code)"
        
        # Show translation result
        if command -v jq &> /dev/null; then
            echo "Translation Result:"
            cat /tmp/translation_response.json | jq .
        else
            cat /tmp/translation_response.json
        fi
        return 0
    else
        log_error "Translation test failed (HTTP $http_code)"
        cat /tmp/translation_response.json
        return 1
    fi
}

# Test supported languages endpoint
test_languages() {
    log_info "Testing supported languages endpoint..."
    
    local url="$1/v1/languages"
    local response=$(curl -s -w "%{http_code}" -o /tmp/languages_response.json "$url")
    local http_code="${response: -3}"
    
    if [ "$http_code" = "200" ]; then
        log_success "Languages endpoint test passed (HTTP $http_code)"
        
        # Show supported languages
        if command -v jq &> /dev/null; then
            echo "Supported Languages:"
            cat /tmp/languages_response.json | jq '.languages | length' | xargs echo "Total languages:"
        else
            echo "Languages response saved to /tmp/languages_response.json"
        fi
        return 0
    else
        log_error "Languages endpoint test failed (HTTP $http_code)"
        cat /tmp/languages_response.json
        return 1
    fi
}

# Test error handling
test_error_handling() {
    log_info "Testing error handling..."
    
    local url="$1/v1/translate"
    local invalid_data='{
        "text": "",
        "source_language": "invalid",
        "target_language": "es"
    }'
    
    local response=$(curl -s -w "%{http_code}" -o /tmp/error_response.json \
        -X POST "$url" \
        -H "Content-Type: application/json" \
        -d "$invalid_data")
    
    local http_code="${response: -3}"
    
    if [ "$http_code" = "400" ] || [ "$http_code" = "422" ]; then
        log_success "Error handling test passed (HTTP $http_code)"
        
        # Show error response
        if command -v jq &> /dev/null; then
            echo "Error Response:"
            cat /tmp/error_response.json | jq .
        else
            cat /tmp/error_response.json
        fi
        return 0
    else
        log_warning "Error handling test unexpected result (HTTP $http_code)"
        cat /tmp/error_response.json
        return 1
    fi
}

# Test performance
test_performance() {
    log_info "Testing response time performance..."
    
    local url="$1/v1/translate"
    local test_data='{
        "text": "This is a performance test message.",
        "source_language": "en",
        "target_language": "fr"
    }'
    
    local start_time=$(date +%s%3N)
    local response=$(curl -s -w "%{http_code}" -o /tmp/perf_response.json \
        -X POST "$url" \
        -H "Content-Type: application/json" \
        -d "$test_data")
    local end_time=$(date +%s%3N)
    
    local http_code="${response: -3}"
    local response_time=$((end_time - start_time))
    
    if [ "$http_code" = "200" ]; then
        if [ "$response_time" -lt 5000 ]; then
            log_success "Performance test passed (${response_time}ms < 5000ms)"
        else
            log_warning "Performance test slow (${response_time}ms >= 5000ms)"
        fi
        
        # Show processing time from API
        if command -v jq &> /dev/null; then
            local api_time=$(cat /tmp/perf_response.json | jq -r '.processing_time_ms // "N/A"')
            echo "API Processing Time: ${api_time}ms"
            echo "Total Round Trip: ${response_time}ms"
        fi
        
        return 0
    else
        log_error "Performance test failed (HTTP $http_code)"
        return 1
    fi
}

# Main test function
run_tests() {
    local service_url="$1"
    local failed_tests=0
    
    echo ""
    log_info "🧪 Starting comprehensive deployment tests"
    echo "Service URL: $service_url"
    echo ""
    
    # Run all tests
    test_health "$service_url" || ((failed_tests++))
    echo ""
    
    test_translation "$service_url" || ((failed_tests++))
    echo ""
    
    test_languages "$service_url" || ((failed_tests++))
    echo ""
    
    test_error_handling "$service_url" || ((failed_tests++))
    echo ""
    
    test_performance "$service_url" || ((failed_tests++))
    echo ""
    
    # Summary
    if [ "$failed_tests" -eq 0 ]; then
        log_success "✅ All tests passed! Deployment is ready for production."
        echo ""
        echo "📋 Next Steps:"
        echo "  1. Update iOS app with service URL: $service_url"
        echo "  2. Configure monitoring alerts"
        echo "  3. Set up custom domain (optional)"
        echo "  4. Run load testing for production traffic"
        echo ""
    else
        log_error "❌ $failed_tests test(s) failed. Please review and fix issues."
        echo ""
        echo "🔍 Troubleshooting:"
        echo "  1. Check Cloud Run logs: gcloud logging read 'resource.type=cloud_run_revision'"
        echo "  2. Verify Gemini API key: gcloud secrets versions access latest --secret=gemini-api-key"
        echo "  3. Check service configuration: gcloud run services describe $SERVICE_NAME --region $REGION"
        echo ""
        exit 1
    fi
}

# Main execution
main() {
    echo ""
    log_info "🚀 Universal Translator Backend Deployment Test"
    echo ""
    
    # Set project
    log_info "Setting GCP project to $PROJECT_ID"
    gcloud config set project "$PROJECT_ID" --quiet
    
    # Get service URL
    SERVICE_URL=$(get_service_url)
    
    # Run comprehensive tests
    run_tests "$SERVICE_URL"
    
    log_success "🎉 Deployment testing completed successfully!"
}

# Check if running in CI or interactive mode
if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
    echo "Usage: $0 [--url SERVICE_URL]"
    echo ""
    echo "Test the deployed Universal Translator backend API"
    echo ""
    echo "Options:"
    echo "  --url URL    Test specific service URL instead of auto-detecting"
    echo "  --help       Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                                           # Auto-detect and test deployed service"
    echo "  $0 --url http://localhost:8080              # Test local development server"
    echo "  $0 --url https://your-service.a.run.app     # Test specific Cloud Run service"
    exit 0
elif [ "$1" = "--url" ] && [ -n "$2" ]; then
    # Test specific URL
    SERVICE_URL="$2"
    echo ""
    log_info "🧪 Testing specific URL: $SERVICE_URL"
    run_tests "$SERVICE_URL"
else
    # Run main function
    main
fi