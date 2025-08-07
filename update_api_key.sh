#!/bin/bash

echo "🔑 Updating Gemini API Key for Speak Easy"
echo "=========================================="
echo ""
echo "Please enter your new Gemini API key:"
echo "(Get one at: https://makersuite.google.com/app/apikey)"
echo ""
read -r API_KEY

if [[ ! "$API_KEY" =~ ^AIzaSy ]]; then
    echo "❌ Invalid API key format. Should start with 'AIzaSy'"
    exit 1
fi

echo ""
echo "📝 Updating Secret Manager..."
echo "$API_KEY" | gcloud secrets versions add gemini-api-key --data-in-file=- --project=universal-translator-prod

if [ $? -ne 0 ]; then
    echo "❌ Failed to update secret. Please check your permissions."
    exit 1
fi

echo "🔄 Restarting Cloud Run service..."
gcloud run services update universal-translator-api \
  --region=us-central1 \
  --clear-secrets \
  --set-secrets="GEMINI_API_KEY=gemini-api-key:latest" \
  --quiet

if [ $? -ne 0 ]; then
    echo "❌ Failed to update Cloud Run service."
    exit 1
fi

echo "✅ Waiting for service to be ready..."
sleep 10

echo "🧪 Testing translation API..."
RESPONSE=$(curl -s -X POST https://universal-translator-api-932729595834.us-central1.run.app/v1/translate \
  -H 'Content-Type: application/json' \
  -d '{"text":"Hello world","source_language":"en","target_language":"es"}')

if echo "$RESPONSE" | grep -q "translated_text"; then
    echo "✅ Success! Translation API is working:"
    echo "$RESPONSE" | jq
    echo ""
    echo "🎉 API Key update complete! Your backend is ready for testing."
else
    echo "❌ Translation test failed. Response:"
    echo "$RESPONSE"
    echo ""
    echo "Please check the logs:"
    echo "gcloud logging read 'resource.type=cloud_run_revision' --limit=10"
fi