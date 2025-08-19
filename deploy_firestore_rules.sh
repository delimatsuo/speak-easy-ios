#!/bin/bash

# Deploy Firestore security rules with environment-based project

set -e

PROJECT_ID="${GCP_PROJECT_ID:-universal-translator-prod}"
ENVIRONMENT="${ENVIRONMENT:-production}"

echo "🔥 Deploying Firestore security rules..."
echo "📋 Project: ${PROJECT_ID}"
echo "🌍 Environment: ${ENVIRONMENT}"

cd /Users/delimatsuo/Documents/Codingclaude/UniversalTranslatorApp
firebase deploy --only firestore:rules --project ${PROJECT_ID}

echo "✅ Firestore rules deployed to ${PROJECT_ID}!"