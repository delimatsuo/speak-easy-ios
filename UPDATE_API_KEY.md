# 🔑 Update Gemini API Key Instructions

## ⚠️ Current Issue
The Gemini API key has expired and needs to be replaced.

## 📝 Steps to Get New API Key

### 1. Get a New Gemini API Key

1. Go to: https://makersuite.google.com/app/apikey
2. Sign in with your Google account
3. Click "Create API Key" or "Get API Key"
4. Select your project or create a new one
5. Copy the new API key (starts with `AIzaSy...`)

### 2. Update Secret Manager

Once you have the new API key, run this command:

```bash
# Replace YOUR_NEW_API_KEY with the actual key
gcloud secrets versions add gemini-api-key --data-in-file=- <<< "YOUR_NEW_API_KEY" --project=universal-translator-prod
```

### 3. Restart Cloud Run Service

```bash
# Force the service to use the new secret
gcloud run services update universal-translator-api \
  --region=us-central1 \
  --clear-secrets \
  --set-secrets="GEMINI_API_KEY=gemini-api-key:latest"
```

### 4. Test the API

```bash
# Test translation endpoint
curl -X POST https://universal-translator-api-932729595834.us-central1.run.app/v1/translate \
  -H 'Content-Type: application/json' \
  -d '{"text":"Hello world","source_language":"en","target_language":"es"}'
```

## 🚀 Quick Fix Script

Save this as `update_api_key.sh` and run it:

```bash
#!/bin/bash

echo "🔑 Updating Gemini API Key for VoiceBridge"
echo "=========================================="
echo ""
echo "Please enter your new Gemini API key:"
read -r API_KEY

if [[ ! "$API_KEY" =~ ^AIzaSy ]]; then
    echo "❌ Invalid API key format. Should start with 'AIzaSy'"
    exit 1
fi

echo "📝 Updating Secret Manager..."
echo "$API_KEY" | gcloud secrets versions add gemini-api-key --data-in-file=- --project=universal-translator-prod

echo "🔄 Restarting Cloud Run service..."
gcloud run services update universal-translator-api \
  --region=us-central1 \
  --clear-secrets \
  --set-secrets="GEMINI_API_KEY=gemini-api-key:latest"

echo "✅ Waiting for service to be ready..."
sleep 10

echo "🧪 Testing translation API..."
curl -X POST https://universal-translator-api-932729595834.us-central1.run.app/v1/translate \
  -H 'Content-Type: application/json' \
  -d '{"text":"Hello world","source_language":"en","target_language":"es"}' | jq

echo ""
echo "✅ API Key update complete!"
```

## 📱 For iOS Testing

After updating the API key, the iOS app should work without any changes since it uses the Cloud Run backend.

## 🆘 Alternative: Use Environment Variable

If Secret Manager continues to have issues, you can set the API key directly:

```bash
gcloud run services update universal-translator-api \
  --update-env-vars "GEMINI_API_KEY=YOUR_NEW_API_KEY" \
  --region=us-central1
```

## 📞 Need Help?

1. Make sure you're logged into the correct Google Cloud project:
   ```bash
   gcloud config get-value project
   # Should show: universal-translator-prod
   ```

2. Verify the secret exists:
   ```bash
   gcloud secrets list --project=universal-translator-prod
   ```

3. Check service logs:
   ```bash
   gcloud logging read "resource.type=cloud_run_revision" --limit=20
   ```

## 🎯 Next Steps After Fixing

1. ✅ Backend API working
2. ✅ Build iOS app for TestFlight
3. ✅ Submit to beta testers
4. ✅ Start collecting feedback

---

**Important**: Keep your API key secure and never commit it to the repository!