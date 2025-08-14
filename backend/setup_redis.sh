#!/bin/bash

# Setup Redis Memorystore for rate limiting

set -e

PROJECT_ID="universal-translator-prod"
REGION="us-central1"
REDIS_INSTANCE_NAME="rate-limiter-cache"

echo "🔴 Setting up Redis Memorystore for rate limiting"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# 1. Set project
echo "📋 Setting GCP project..."
gcloud config set project ${PROJECT_ID}

# 2. Enable Redis API
echo "🔧 Enabling Redis API..."
gcloud services enable redis.googleapis.com --quiet

# 3. Create Redis instance if it doesn't exist
echo "🔴 Creating Redis instance..."
if ! gcloud redis instances describe ${REDIS_INSTANCE_NAME} --region=${REGION} --quiet 2>/dev/null; then
    gcloud redis instances create ${REDIS_INSTANCE_NAME} \
        --size=1 \
        --region=${REGION} \
        --redis-version=redis_6_x \
        --tier=basic \
        --network=default \
        --redis-config maxmemory-policy=allkeys-lru
    
    echo "✅ Redis instance created successfully"
else
    echo "ℹ️  Redis instance already exists"
fi

# 4. Get Redis IP
REDIS_HOST=$(gcloud redis instances describe ${REDIS_INSTANCE_NAME} \
    --region=${REGION} \
    --format='value(host)')

echo ""
echo "✅ Redis Setup Complete!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔴 Redis Host: ${REDIS_HOST}"
echo "🔴 Redis URL: redis://${REDIS_HOST}:6379"
echo ""
echo "Use this in your Cloud Run deployment:"
echo "REDIS_URL=redis://${REDIS_HOST}:6379"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
