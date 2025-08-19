#!/bin/bash

# Deploy Voice Translation Backend to Google Cloud Run

set -e

# Environment-based configuration
PROJECT_ID="${GCP_PROJECT_ID:-universal-translator-prod}"
SERVICE_NAME="${SERVICE_NAME:-universal-translator-api}"
REGION="${GCP_REGION:-us-central1}"
ENVIRONMENT="${ENVIRONMENT:-production}"
IMAGE_NAME="gcr.io/${PROJECT_ID}/${SERVICE_NAME}-voice:latest"

echo "🎤 Deploying Voice Translation Backend to Cloud Run"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📋 Project: ${PROJECT_ID}"
echo "🌍 Environment: ${ENVIRONMENT}"
echo "📍 Region: ${REGION}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

echo "🎤 Deploying Voice Translation Backend to Cloud Run"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# 1. Set project
echo "📋 Setting GCP project..."
gcloud config set project ${PROJECT_ID}

# 2. Enable required APIs
echo "🔧 Enabling required APIs..."
gcloud services enable \
    cloudbuild.googleapis.com \
    run.googleapis.com \
    secretmanager.googleapis.com \
    texttospeech.googleapis.com \
    speech.googleapis.com \
    --quiet

# 3. Build Docker image
echo "🐳 Building Docker image..."
gcloud builds submit \
    --config cloudbuild_voice.yaml \
    --timeout=20m \
    .

# 4. Deploy to Cloud Run
echo "🚀 Deploying to Cloud Run..."
gcloud run deploy ${SERVICE_NAME} \
    --image ${IMAGE_NAME} \
    --platform managed \
    --region ${REGION} \
    --allow-unauthenticated \
    --memory 2Gi \
    --cpu 2 \
    --timeout 60s \
    --max-instances 100 \
    --min-instances 0 \
    --set-secrets "GEMINI_API_KEY=gemini-api-key:latest" \
    --set-env-vars "ENVIRONMENT=production,GCP_PROJECT=${PROJECT_ID},REDIS_URL=redis://10.36.156.179:6379"

# 5. Get service URL
SERVICE_URL=$(gcloud run services describe ${SERVICE_NAME} \
    --platform managed \
    --region ${REGION} \
    --format 'value(status.url)')

echo ""
echo "✅ Deployment Complete!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🌐 Service URL: ${SERVICE_URL}"
echo ""
echo "Test the voice endpoints:"
echo ""
echo "1. Health check:"
echo "   curl ${SERVICE_URL}/health"
echo ""
echo "2. Translate with audio:"
echo "   curl -X POST ${SERVICE_URL}/v1/translate/audio \\"
echo "     -H 'Content-Type: application/json' \\"
echo "     -d '{\"text\":\"Hello world\",\"source_language\":\"en\",\"target_language\":\"es\",\"return_audio\":true}'"
echo ""
echo "3. Supported languages:"
echo "   curl ${SERVICE_URL}/v1/languages"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"