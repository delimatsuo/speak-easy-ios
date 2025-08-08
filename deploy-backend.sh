#!/bin/bash
# deploy-backend.sh - Cloud Run deployment script for Universal Translator Backend

set -e  # Exit on any error

# Configuration
PROJECT_ID="universal-translator-prod"
SERVICE_NAME="universal-translator-api"
REGION="us-central1"
IMAGE_NAME="gcr.io/${PROJECT_ID}/${SERVICE_NAME}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

# Check prerequisites
check_prerequisites() {
    log_info "Checking deployment prerequisites..."
    
    # Check if gcloud is installed and authenticated
    if ! command -v gcloud &> /dev/null; then
        log_error "gcloud CLI is not installed. Please install Google Cloud SDK."
        exit 1
    fi
    
    # Check if docker is installed
    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed. Please install Docker Desktop."
        exit 1
    fi
    
    # Check if authenticated
    if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" | grep -q .; then
        log_error "Not authenticated with gcloud. Run 'gcloud auth login' first."
        exit 1
    fi
    
    # Check if project exists
    if ! gcloud projects describe ${PROJECT_ID} &> /dev/null; then
        log_error "Project ${PROJECT_ID} does not exist or you don't have access."
        exit 1
    fi
    
    # Set project
    gcloud config set project ${PROJECT_ID}
    
    log_success "Prerequisites check passed"
}

# Enable required APIs
enable_apis() {
    log_info "Enabling required GCP APIs..."
    
    gcloud services enable \
        run.googleapis.com \
        cloudbuild.googleapis.com \
        artifactregistry.googleapis.com \
        containerregistry.googleapis.com \
        monitoring.googleapis.com \
        logging.googleapis.com \
        cloudtrace.googleapis.com \
        clouderrorreporting.googleapis.com \
        secretmanager.googleapis.com
    
    log_success "APIs enabled successfully"
}

# Verify secrets exist
verify_secrets() {
    log_info "Verifying required secrets exist..."
    
    if ! gcloud secrets describe gemini-api-key &> /dev/null; then
        log_error "Secret 'gemini-api-key' not found. Please create it first."
        log_info "Run: gcloud secrets create gemini-api-key --data-file=-"
        exit 1
    fi
    
    log_success "Required secrets verified"
}

# Build and push Docker image
build_and_push() {
    log_info "Building Docker container..."
    
    # Configure Docker to use gcloud as credential helper
    gcloud auth configure-docker --quiet
    
    # Build the image
    # Use backend directory as build context so Dockerfile COPY paths resolve
    docker build -t ${IMAGE_NAME} -f backend/Dockerfile backend
    
    log_info "Pushing container to GCR..."
    docker push ${IMAGE_NAME}
    
    log_success "Container built and pushed successfully"
}

# Deploy to Cloud Run
deploy_service() {
    log_info "Deploying to Cloud Run..."
    
    # Get project number for service account
    PROJECT_NUMBER=$(gcloud projects describe ${PROJECT_ID} --format="value(projectNumber)")
    
    gcloud run deploy ${SERVICE_NAME} \
        --image ${IMAGE_NAME} \
        --platform managed \
        --region ${REGION} \
        --allow-unauthenticated \
        --set-secrets="GEMINI_API_KEY=gemini-api-key:latest" \
        --set-env-vars="GCP_PROJECT=${PROJECT_ID},ENVIRONMENT=production" \
        --min-instances=0 \
        --max-instances=100 \
        --memory=2Gi \
        --cpu=2 \
        --timeout=300 \
        --concurrency=80 \
        --service-account="${PROJECT_NUMBER}-compute@developer.gserviceaccount.com" \
        --quiet
    
    log_success "Service deployed to Cloud Run"
}

# Get service URL and test
test_deployment() {
    log_info "Testing deployment..."
    
    # Get the service URL
    SERVICE_URL=$(gcloud run services describe ${SERVICE_NAME} \
        --platform managed \
        --region ${REGION} \
        --format 'value(status.url)')
    
    if [ -z "$SERVICE_URL" ]; then
        log_error "Failed to get service URL"
        exit 1
    fi
    
    log_info "Service URL: ${SERVICE_URL}"
    
    # Test health endpoint
    log_info "Testing health endpoint..."
    if curl -s -o /dev/null -w "%{http_code}" "${SERVICE_URL}/health" | grep -q "200"; then
        log_success "Health check passed"
    else
        log_warning "Health check failed, but service may still be starting up"
    fi
    
    # Test translation endpoint
    log_info "Testing translation endpoint..."
    RESPONSE=$(curl -s -X POST "${SERVICE_URL}/v1/translate" \
        -H "Content-Type: application/json" \
        -d '{"text": "Hello", "source_language": "en", "target_language": "es"}' \
        -w "%{http_code}")
    
    if echo "$RESPONSE" | tail -c 4 | grep -q "200"; then
        log_success "Translation API test passed"
    else
        log_warning "Translation API test failed - check logs"
    fi
    
    echo ""
    log_success "🚀 Deployment completed successfully!"
    echo ""
    echo "📋 Deployment Summary:"
    echo "   Service Name: ${SERVICE_NAME}"
    echo "   Service URL:  ${SERVICE_URL}"
    echo "   Region:       ${REGION}"
    echo "   Project:      ${PROJECT_ID}"
    echo ""
    echo "📱 Next Steps:"
    echo "   1. Update your iOS app with this URL: ${SERVICE_URL}"
    echo "   2. Configure monitoring alerts"
    echo "   3. Set up custom domain (optional)"
    echo "   4. Run integration tests"
    echo ""
    echo "📊 Monitoring:"
    echo "   Logs:    gcloud logging read 'resource.type=cloud_run_revision'"
    echo "   Metrics: https://console.cloud.google.com/run/detail/${REGION}/${SERVICE_NAME}/metrics"
    echo ""
}

# Main deployment flow
main() {
    echo ""
    log_info "🚀 Starting Universal Translator Backend Deployment"
    echo ""
    
    check_prerequisites
    enable_apis
    verify_secrets
    build_and_push
    deploy_service
    test_deployment
    
    log_success "✅ Deployment process completed!"
}

# Check if running in CI/CD or interactive mode
if [ "$1" = "--ci" ]; then
    # Non-interactive mode for CI/CD
    main
else
    # Interactive mode - confirm before proceeding
    echo ""
    echo "🔍 This will deploy the Universal Translator backend to:"
    echo "   Project: ${PROJECT_ID}"
    echo "   Service: ${SERVICE_NAME}"
    echo "   Region:  ${REGION}"
    echo ""
    read -p "Do you want to continue? (y/N): " -n 1 -r
    echo ""
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        main
    else
        log_info "Deployment cancelled by user"
        exit 0
    fi
fi