# 🔑 Enable Gemini API for Your Key

## Current Issue
The Gemini API key needs to be enabled for the Generative Language API.

## Steps to Enable

### 1. Enable the API in Google Cloud Console

Go to: https://console.cloud.google.com/apis/library/generativelanguage.googleapis.com

1. Make sure you're in the correct project
2. Click "ENABLE" if the API is not already enabled
3. Wait a few moments for it to activate

### 2. Alternative: Enable via Command Line

```bash
gcloud services enable generativelanguage.googleapis.com --project=universal-translator-prod
```

### 3. Verify API Key Settings

Go to: https://console.cloud.google.com/apis/credentials

1. Find your API key (AIzaSyDftOOmdUoH5pMfiGoi4VuROetgh_gB5KQ)
2. Click on it to edit
3. Under "API restrictions":
   - Either select "Don't restrict key" (for testing)
   - Or add these specific APIs:
     - Generative Language API
     - Cloud Text-to-Speech API
     - Cloud Speech-to-Text API

### 4. Test the API Key

```bash
# Test Gemini directly
curl -X POST "https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:generateContent?key=AIzaSyDftOOmdUoH5pMfiGoi4VuROetgh_gB5KQ" \
  -H 'Content-Type: application/json' \
  -d '{
    "contents": [{
      "parts": [{
        "text": "Translate to Spanish: Hello world"
      }]
    }]
  }'
```

### 5. Once Working, Test Translation Endpoint

```bash
curl -X POST https://universal-translator-api-jzqoowo3tq-uc.a.run.app/v1/translate \
  -H 'Content-Type: application/json' \
  -d '{"text":"Hello","source_language":"en","target_language":"es"}'
```

## Alternative: Use a Different API Key

If the current key has restrictions, you can create a new one:

1. Go to: https://makersuite.google.com/app/apikey
2. Create a new API key
3. Update the Cloud Run service:

```bash
gcloud run services update universal-translator-api \
  --region=us-central1 \
  --update-env-vars="GEMINI_API_KEY=YOUR_NEW_KEY"
```

## Common Issues

### "API key not valid"
- The key exists but isn't enabled for Gemini
- Solution: Enable the Generative Language API

### "Requests to this API method are blocked"
- The key has API restrictions
- Solution: Add Gemini to allowed APIs or remove restrictions

### "Quota exceeded"
- You've hit the rate limit
- Solution: Wait a bit or upgrade quota

## Quick Debug Commands

```bash
# Check if API is enabled
gcloud services list --enabled | grep generativelanguage

# Check Cloud Run logs
gcloud logging read "resource.type=cloud_run_revision" --limit=10

# Test health endpoint
curl https://universal-translator-api-jzqoowo3tq-uc.a.run.app/health
```

---

Once the API is enabled, your translation service should work immediately!