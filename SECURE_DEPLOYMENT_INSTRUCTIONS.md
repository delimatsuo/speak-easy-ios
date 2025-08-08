# 🔐 Universal Translator App - Secure Production Deployment Instructions

## ⚠️ IMPORTANT: Credential Security Guidelines
This document contains instructions for YOU (the human operator) to securely configure all sensitive credentials. No actual keys or secrets are included in this document.

---

## 📋 PRE-DEPLOYMENT CHECKLIST FOR HUMAN OPERATOR

### 1. Required Accounts & Access
Before proceeding, ensure you have:
- [ ] Google Cloud Platform account with billing enabled
- [ ] Apple Developer account for App Store submission
- [ ] Gemini API access from Google AI Studio
- [ ] Domain name for the app (optional but recommended)

---

## 🔑 STEP 1: SECURE CREDENTIAL CONFIGURATION

### A. Google Cloud Authentication Setup

**Run these commands in your local terminal:**

```bash
# 1. Install Google Cloud SDK if not already installed
# For macOS:
brew install --cask google-cloud-sdk

# 2. Authenticate your local machine with GCP
gcloud auth login

# 3. Set application default credentials
gcloud auth application-default login

# 4. Create and set your project
gcloud projects create universal-translator-prod \
    --name="Universal Translator Production"
    
gcloud config set project universal-translator-prod

# 5. Link billing account (required for Cloud Run)
# List your billing accounts
gcloud billing accounts list

# Link billing to project (replace BILLING_ACCOUNT_ID)
gcloud billing projects link universal-translator-prod \
    --billing-account=BILLING_ACCOUNT_ID
```

### B. Gemini API Key Configuration

**Steps to securely store your Gemini API key:**

1. **Obtain your Gemini API key:**
   - Go to https://makersuite.google.com/app/apikey
   - Click "Create API Key"
   - Copy the key (starts with "AIza...")

2. **Store in GCP Secret Manager:**
   ```bash
   # Enable Secret Manager API
   gcloud services enable secretmanager.googleapis.com
   
   # Create secret (you'll be prompted to enter the key)
   echo -n "PASTE_YOUR_GEMINI_API_KEY_HERE" | \
   gcloud secrets create gemini-api-key \
       --data-file=- \
       --replication-policy="automatic"
   
   # Verify it was created (should show version 1)
   gcloud secrets versions list gemini-api-key
   ```

3. **Grant Cloud Run access to the secret:**
   ```bash
   # Get your project number
   PROJECT_NUMBER=$(gcloud projects describe universal-translator-prod \
       --format="value(projectNumber)")
   
   # Grant access to Cloud Run service account
   gcloud secrets add-iam-policy-binding gemini-api-key \
       --member="serviceAccount:${PROJECT_NUMBER}-compute@developer.gserviceaccount.com" \
       --role="roles/secretmanager.secretAccessor"
   ```

### C. Firebase Configuration

**Steps to set up Firebase:**

1. **Create Firebase project:**
   ```bash
   # Install Firebase CLI
   npm install -g firebase-tools
   
   # Login to Firebase
   firebase login
   
   # Initialize Firebase in your project directory
   cd /Users/delimatsuo/Documents/Codingclaude/UniversalTranslatorApp
   firebase init
   ```
   
   **When prompted, select:**
   - Use existing GCP project: `universal-translator-prod`
   - Services: Firestore, Hosting, Storage, Functions
   - Use default settings for each service

2. **Download iOS configuration:**
   - Go to https://console.firebase.google.com
   - Select your project
   - Click "Add app" → iOS
   - Bundle ID: `com.universaltranslator.app`
   - Download `GoogleService-Info.plist`
   
   **Place the file here:**
   ```bash
   # Move to iOS project
   mv ~/Downloads/GoogleService-Info.plist \
      /Users/delimatsuo/Documents/Codingclaude/UniversalTranslatorApp/iOS/
   ```

3. **Store Firebase configuration in Secret Manager:**
   ```bash
   # Create secret from the plist file
   gcloud secrets create firebase-config \
       --data-file=/Users/delimatsuo/Documents/Codingclaude/UniversalTranslatorApp/iOS/GoogleService-Info.plist
   ```

### D. Service Account Creation

**Create service accounts for different components:**

```bash
# 1. Create Cloud Run service account
gcloud iam service-accounts create cloud-run-backend \
    --display-name="Cloud Run Backend Service"

# 2. Create Cloud Build service account
gcloud iam service-accounts create cloud-build \
    --display-name="Cloud Build CI/CD"

# 3. Grant necessary permissions
gcloud projects add-iam-policy-binding universal-translator-prod \
    --member="serviceAccount:cloud-run-backend@universal-translator-prod.iam.gserviceaccount.com" \
    --role="roles/secretmanager.secretAccessor"

gcloud projects add-iam-policy-binding universal-translator-prod \
    --member="serviceAccount:cloud-build@universal-translator-prod.iam.gserviceaccount.com" \
    --role="roles/run.admin"
```

---

## 🚀 STEP 2: BACKEND DEPLOYMENT

### A. Enable Required GCP APIs

**Run this command to enable all necessary APIs:**

```bash
gcloud services enable \
    run.googleapis.com \
    cloudbuild.googleapis.com \
    artifactregistry.googleapis.com \
    containerregistry.googleapis.com \
    monitoring.googleapis.com \
    logging.googleapis.com \
    cloudtrace.googleapis.com \
    clouderrorreporting.googleapis.com \
    storage-api.googleapis.com \
    firestore.googleapis.com \
    firebase.googleapis.com
```

### B. Create Cloud Run Deployment Script

**Create this file: `deploy-backend.sh`**

```bash
#!/bin/bash
# deploy-backend.sh - Cloud Run deployment script

# Configuration
PROJECT_ID="universal-translator-prod"
SERVICE_NAME="universal-translator-api"
REGION="us-central1"
IMAGE_NAME="gcr.io/${PROJECT_ID}/${SERVICE_NAME}"

# Build container
echo "Building Docker container..."
docker build -t ${IMAGE_NAME} ./backend

# Push to Container Registry
echo "Pushing to GCR..."
docker push ${IMAGE_NAME}

# Deploy to Cloud Run
echo "Deploying to Cloud Run..."
gcloud run deploy ${SERVICE_NAME} \
    --image ${IMAGE_NAME} \
    --platform managed \
    --region ${REGION} \
    --allow-unauthenticated \
    --set-secrets="GEMINI_API_KEY=gemini-api-key:latest" \
    --set-env-vars="GCP_PROJECT=${PROJECT_ID}" \
    --min-instances=1 \
    --max-instances=100 \
    --memory=2Gi \
    --cpu=2 \
    --timeout=60 \
    --service-account=cloud-run-backend@${PROJECT_ID}.iam.gserviceaccount.com

# Get the service URL
SERVICE_URL=$(gcloud run services describe ${SERVICE_NAME} \
    --platform managed \
    --region ${REGION} \
    --format 'value(status.url)')

echo "Backend deployed to: ${SERVICE_URL}"
echo "Update your iOS app with this URL"
```

**Make it executable:**
```bash
chmod +x deploy-backend.sh
```

### C. Backend Environment Configuration

**Create `.env.production` file (DO NOT commit to git):**

```bash
# .env.production
# This file should be created locally and NOT committed
GCP_PROJECT=universal-translator-prod
REGION=us-central1
# Secrets are loaded from Secret Manager, not env vars
```

**Add to `.gitignore`:**
```bash
echo ".env.production" >> .gitignore
echo "GoogleService-Info.plist" >> .gitignore
echo "*.serviceaccount.json" >> .gitignore
```

---

## 📱 STEP 3: iOS APP CONFIGURATION

### A. Update iOS App Configuration

**Update these files in your Xcode project:**

1. **AppConfig.swift** - Create this file:
```swift
// AppConfig.swift
import Foundation

struct AppConfig {
    // These will be loaded from Info.plist or build configuration
    static let apiBaseURL: String = {
        // For local testing
        #if DEBUG
        return "http://localhost:8080"
## Production API key handling

- Do not hardcode API keys in source or plist files.
- Use GCP Secret Manager and reference via `--set-secrets GEMINI_API_KEY=gemini-api-key:latest` on Cloud Run.
- In iOS, store keys in the Keychain only; ship `api_keys.plist` with placeholders (no real keys).

        #else
        // Production URL - will be set after Cloud Run deployment
        return ProcessInfo.processInfo.environment["API_BASE_URL"] 
            ?? "https://universal-translator-api-xxxxx.a.run.app"
        #endif
    }()
    
    // Firebase is configured via GoogleService-Info.plist
    // No hardcoded keys needed
}
```

2. **Info.plist Configuration:**
```xml
<!-- Add to Info.plist -->
<key>API_BASE_URL</key>
<string>$(API_BASE_URL)</string>
```

3. **Build Configuration:**
   - In Xcode, go to Project → Build Settings
   - Add User-Defined Setting: `API_BASE_URL`
   - Set value after Cloud Run deployment

### B. Firebase Integration

**After placing `GoogleService-Info.plist` in your project:**

1. In Xcode:
   - Drag `GoogleService-Info.plist` into project navigator
   - Ensure "Copy items if needed" is checked
   - Add to target: Universal Translator

2. Initialize Firebase in `AppDelegate.swift`:
```swift
import Firebase

func application(_ application: UIApplication,
                didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    FirebaseApp.configure()
    return true
}
```

---

## 📊 STEP 4: MONITORING SETUP

### A. Create Monitoring Dashboard

**Run these commands to set up monitoring:**

```bash
# 1. Create uptime check
gcloud monitoring uptime-check-configs create api-health-check \
    --display-name="API Health Check" \
    --monitored-resource="type=uptime_url,labels.host=universal-translator-api-xxxxx.a.run.app" \
    --http-check="path=/health,port=443,use_ssl=true" \
    --period=60s

# 2. Create alert policy for high error rate
cat > alert-policy.yaml << EOF
displayName: High Error Rate Alert
conditions:
  - displayName: Error rate above 1%
    conditionThreshold:
      filter: resource.type="cloud_run_revision"
              AND metric.type="run.googleapis.com/request_count"
              AND metric.labels.response_code_class!="2xx"
      comparison: COMPARISON_GT
      thresholdValue: 0.01
      duration: 300s
EOF

gcloud alpha monitoring policies create --policy-from-file=alert-policy.yaml
```

### B. Set Up Notification Channels

```bash
# Create email notification channel
gcloud alpha monitoring channels create \
    --display-name="Team Email" \
    --type=email \
    --channel-labels=email_address=YOUR_EMAIL@example.com

# List channels to get ID
gcloud alpha monitoring channels list
```

---

## 🚢 STEP 5: PRODUCTION DEPLOYMENT COMMANDS

### Execute Deployment (Run in Order)

```bash
# 1. Ensure you're in the project directory
cd /Users/delimatsuo/Documents/Codingclaude/UniversalTranslatorApp

# 2. Deploy backend to Cloud Run
./deploy-backend.sh

# 3. Deploy Firebase services
firebase deploy --only firestore,hosting,storage

# 4. Run production tests
gcloud builds submit --config=cloudbuild-test.yaml

# 5. Verify deployment
curl https://YOUR-CLOUD-RUN-URL.a.run.app/health
```

---

## 📝 STEP 6: APP STORE SUBMISSION PREPARATION

### A. Generate App Store Connect API Key

1. Go to https://appstoreconnect.apple.com
2. Users and Access → Keys → App Store Connect API
3. Create new key with "Admin" role
4. Download the `.p8` file
5. Note the Key ID and Issuer ID

### B. Store Apple credentials securely:

```bash
# Store App Store Connect API key
gcloud secrets create app-store-key \
    --data-file=~/Downloads/AuthKey_XXXXXX.p8

# Store key metadata (create this file first)
cat > app-store-config.json << EOF
{
  "key_id": "YOUR_KEY_ID",
  "issuer_id": "YOUR_ISSUER_ID",
  "bundle_id": "com.universaltranslator.app"
}
EOF

gcloud secrets create app-store-config \
    --data-file=app-store-config.json

# Clean up local files
rm app-store-config.json
rm ~/Downloads/AuthKey_XXXXXX.p8
```

---

## ✅ FINAL PRODUCTION CHECKLIST

### Pre-Launch Verification

#### GCP Infrastructure
- [ ] GCP project created and billing enabled
- [ ] All required APIs enabled
- [ ] Gemini API key stored in Secret Manager
- [ ] Cloud Run backend deployed and accessible
- [ ] Firebase services configured
- [ ] Monitoring and alerts configured
- [ ] Custom domain configured (optional)

#### iOS App
- [ ] GoogleService-Info.plist added to Xcode project
- [ ] Firebase SDK integrated
- [ ] Production API URL configured
- [ ] App builds successfully in Release mode
- [ ] All required App Store assets prepared

#### Security
- [ ] No hardcoded API keys in code
- [ ] All secrets in Secret Manager
- [ ] Service accounts have minimal permissions
- [ ] SSL/TLS certificates valid
- [ ] API rate limiting configured

#### Testing
- [ ] Backend health check passing
- [ ] iOS app connects to production backend
- [ ] Translation functionality working
- [ ] Offline mode tested
- [ ] Performance benchmarks met

### App Store Submission
- [ ] App Store Connect account active
- [ ] App metadata completed
- [ ] Screenshots for all device sizes
- [ ] App preview video uploaded
- [ ] Privacy policy URL live
- [ ] Terms of service URL live
- [ ] TestFlight beta testing completed
- [ ] App binary uploaded
- [ ] Submitted for review

---

## 🚨 TROUBLESHOOTING GUIDE

### Common Issues and Solutions

**Issue: Cloud Run deployment fails**
```bash
# Check Cloud Run service logs
gcloud logging read "resource.type=cloud_run_revision" --limit 50

# Verify service account permissions
gcloud projects get-iam-policy universal-translator-prod
```

**Issue: Secret Manager access denied**
```bash
# Grant explicit access
gcloud secrets add-iam-policy-binding gemini-api-key \
    --member="serviceAccount:YOUR-SERVICE-ACCOUNT@PROJECT.iam.gserviceaccount.com" \
    --role="roles/secretmanager.secretAccessor"
```

**Issue: Firebase configuration not found**
```bash
# Verify Firebase project
firebase projects:list

# Re-initialize if needed
firebase init
```

---

## 📞 SUPPORT RESOURCES

- **GCP Console**: https://console.cloud.google.com
- **Firebase Console**: https://console.firebase.google.com
- **Cloud Run Logs**: `gcloud logging read "resource.type=cloud_run_revision"`
- **Secret Manager**: `gcloud secrets list`
- **Monitoring**: `gcloud monitoring dashboards list`

---

## 🎉 POST-LAUNCH MONITORING

After successful deployment:

1. **Monitor Cloud Run metrics:**
   ```bash
   gcloud monitoring metrics-descriptors list --filter="metric.type:run.googleapis.com"
   ```

2. **Check error logs:**
   ```bash
   gcloud logging read "severity>=ERROR" --limit 20
   ```

3. **View real-time metrics:**
   - Go to Cloud Console → Cloud Run → Your Service → Metrics

4. **Track costs:**
   ```bash
   gcloud billing accounts list
   gcloud alpha billing budgets list
   ```

---

**IMPORTANT REMINDERS:**
- Never commit sensitive files to Git
- Always use Secret Manager for credentials
- Test in staging before production
- Keep backups of all configuration files
- Document any custom configuration changes

**This document provides secure instructions without exposing any actual credentials. Follow each step carefully and ensure all sensitive data is properly secured.**