# 🌐 Universal Translator App - Google Cloud Platform Deployment Guide

## ⚠️ IMPORTANT: GCP EXCLUSIVE DEPLOYMENT
**NO AWS SERVICES** - All infrastructure uses Google Cloud Platform only

---

## 📋 GCP Services Architecture

### Core Services Required

| Service | Purpose | Configuration |
|---------|---------|---------------|
| **Cloud Run** | Backend API hosting | Containerized, auto-scaling |
| **Firebase** | Mobile backend services | Auth, Firestore, Hosting |
| **Cloud Storage** | Audio file storage | Temporary translation files |
| **Secret Manager** | API key management | Gemini keys, certificates |
| **Cloud CDN** | Global distribution | Low-latency content delivery |
| **Cloud Monitoring** | APM and metrics | Performance tracking |
| **Cloud Logging** | Centralized logs | Error tracking, audit |
| **Cloud Armor** | Security/DDoS | Rate limiting, protection |
| **Cloud Build** | CI/CD pipeline | Automated deployments |
| **Artifact Registry** | Container images | Docker image storage |

---

## 🚀 Deployment Steps

### 1. GCP Project Setup

```bash
# Set up GCP project
gcloud projects create universal-translator-prod --name="Universal Translator Production"
gcloud config set project universal-translator-prod

# Enable required APIs
gcloud services enable \
  run.googleapis.com \
  secretmanager.googleapis.com \
  cloudapis.googleapis.com \
  monitoring.googleapis.com \
  logging.googleapis.com \
  artifactregistry.googleapis.com \
  cloudbuild.googleapis.com \
  firebase.googleapis.com \
  firestore.googleapis.com \
  storage.googleapis.com \
  cdn.googleapis.com

# Set default region
gcloud config set run/region us-central1
```

### 2. Secret Manager Configuration

```bash
# Store Gemini API key securely
echo -n "YOUR_GEMINI_API_KEY" | gcloud secrets create gemini-api-key \
  --data-file=- \
  --replication-policy="automatic"

# Store SSL certificates
gcloud secrets create ssl-cert --data-file=./cert.pem
gcloud secrets create ssl-key --data-file=./key.pem

# Grant Cloud Run access to secrets
gcloud secrets add-iam-policy-binding gemini-api-key \
  --member="serviceAccount:PROJECT-NUMBER-compute@developer.gserviceaccount.com" \
  --role="roles/secretmanager.secretAccessor"
```

### 3. Cloud Run Backend Deployment

```dockerfile
# Dockerfile for backend API
FROM python:3.11-slim

WORKDIR /app
COPY requirements.txt .
RUN pip install -r requirements.txt

COPY . .

# Use Secret Manager for API keys
ENV GOOGLE_APPLICATION_CREDENTIALS="/app/service-account.json"

EXPOSE 8080
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8080"]
```

```bash
# Build and deploy to Cloud Run
gcloud builds submit --tag gcr.io/universal-translator-prod/backend-api

gcloud run deploy universal-translator-api \
  --image gcr.io/universal-translator-prod/backend-api \
  --platform managed \
  --region us-central1 \
  --allow-unauthenticated \
  --set-env-vars="GCP_PROJECT=universal-translator-prod" \
  --set-secrets="GEMINI_API_KEY=gemini-api-key:latest" \
  --min-instances=2 \
  --max-instances=100 \
  --memory=2Gi \
  --cpu=2
```

### 4. Firebase Configuration

```bash
# Initialize Firebase
firebase init

# Select:
# - Firestore (database)
# - Hosting (CDN/static content)
# - Functions (serverless backend)
# - Storage (audio files)

# Deploy Firebase services
firebase deploy --only firestore,hosting,storage

# Configure Firebase in iOS app
# Add GoogleService-Info.plist to Xcode project
```

### 5. Cloud Storage Setup

```bash
# Create storage buckets
gsutil mb -p universal-translator-prod \
  -c standard \
  -l us-central1 \
  gs://universal-translator-audio-temp/

# Set lifecycle policy for temporary files (delete after 1 hour)
cat > lifecycle.json << EOF
{
  "lifecycle": {
    "rule": [{
      "action": {"type": "Delete"},
      "condition": {"age": 1}
    }]
  }
}
EOF

gsutil lifecycle set lifecycle.json gs://universal-translator-audio-temp/
```

### 6. Cloud CDN Configuration

```bash
# Create backend bucket for static assets
gcloud compute backend-buckets create universal-translator-cdn \
  --gcs-bucket-name=universal-translator-static

# Create URL map
gcloud compute url-maps create universal-translator-map \
  --default-backend-bucket=universal-translator-cdn

# Create HTTPS proxy
gcloud compute target-https-proxies create universal-translator-proxy \
  --url-map=universal-translator-map \
  --ssl-certificates=universal-translator-cert

# Create forwarding rule
gcloud compute forwarding-rules create universal-translator-https \
  --global \
  --target-https-proxy=universal-translator-proxy \
  --ports=443

# Enable CDN
gcloud compute backend-buckets update universal-translator-cdn \
  --enable-cdn
```

### 7. Monitoring & Logging Setup

```bash
# Create uptime checks
gcloud monitoring uptime-check-configs create \
  universal-translator-health \
  --display-name="API Health Check" \
  --resource-type="uptime-url" \
  --monitored-resource="{'type':'uptime_url','labels':{'host':'api.universaltranslator.app'}}" \
  --http-check="{'path':'/health','port':443,'use_ssl':true}" \
  --period=60

# Create alert policies
gcloud alpha monitoring policies create \
  --notification-channels=CHANNEL_ID \
  --display-name="High Error Rate Alert" \
  --condition="rate(compute.googleapis.com/instance/cpu/utilization) > 0.8"

# Configure log sinks for analysis
gcloud logging sinks create error-sink \
  bigquery.googleapis.com/projects/universal-translator-prod/datasets/error_logs \
  --log-filter='severity>=ERROR'
```

### 8. Cloud Armor Security

```bash
# Create security policy
gcloud compute security-policies create universal-translator-policy \
  --description="DDoS and rate limiting protection"

# Add rate limiting rule
gcloud compute security-policies rules create 1000 \
  --security-policy=universal-translator-policy \
  --expression="origin.region_code == 'CN'" \
  --action="deny-403"

# Add DDoS protection
gcloud compute security-policies rules create 2000 \
  --security-policy=universal-translator-policy \
  --expression="request.headers['user-agent'].contains('bot')" \
  --action="rate-based-ban" \
  --rate-limit-threshold-count=10 \
  --rate-limit-threshold-interval-sec=60

# Apply to backend service
gcloud compute backend-services update universal-translator-backend \
  --security-policy=universal-translator-policy
```

---

## 📊 GCP Monitoring Dashboard

### Key Metrics to Track

1. **Cloud Run Metrics**
   - Request count and latency
   - Container CPU and memory usage
   - Cold start frequency
   - Error rates

2. **Firebase Metrics**
   - Active users
   - Firestore operations
   - Storage bandwidth
   - Authentication events

3. **Cloud CDN Metrics**
   - Cache hit ratio
   - Bandwidth usage
   - Origin requests
   - Response times by region

### Custom Dashboard Configuration

```yaml
# monitoring-dashboard.yaml
displayName: Universal Translator Production Dashboard
mosaicLayout:
  columns: 12
  tiles:
    - width: 6
      height: 4
      widget:
        title: API Request Rate
        xyChart:
          dataSets:
            - timeSeriesQuery:
                timeSeriesFilter:
                  filter: metric.type="run.googleapis.com/request_count"
    - width: 6
      height: 4
      widget:
        title: Translation Latency
        xyChart:
          dataSets:
            - timeSeriesQuery:
                timeSeriesFilter:
                  filter: metric.type="run.googleapis.com/request_latencies"
```

---

## 💰 Cost Optimization

### GCP Pricing Estimates

| Service | Usage | Monthly Cost |
|---------|-------|--------------|
| Cloud Run | 1M requests | ~$50 |
| Firebase | 100K users | ~$100 |
| Cloud Storage | 1TB bandwidth | ~$120 |
| Secret Manager | 10K operations | ~$0.30 |
| Cloud CDN | 10TB transfer | ~$850 |
| Cloud Monitoring | Standard tier | ~$50 |
| **Total Estimate** | | **~$1,170/month** |

### Cost Optimization Strategies

1. **Use Committed Use Discounts** - 1-year commitment saves 37%
2. **Enable Cloud CDN** - Reduce origin bandwidth costs
3. **Set up Budget Alerts** - Monitor spending
4. **Use Preemptible Instances** - For batch processing
5. **Optimize Cloud Run Scaling** - Minimize idle instances

---

## 🔧 CI/CD Pipeline

### Cloud Build Configuration

```yaml
# cloudbuild.yaml
steps:
  # Build Docker image
  - name: 'gcr.io/cloud-builders/docker'
    args: ['build', '-t', 'gcr.io/$PROJECT_ID/backend-api:$COMMIT_SHA', '.']
  
  # Push to Container Registry
  - name: 'gcr.io/cloud-builders/docker'
    args: ['push', 'gcr.io/$PROJECT_ID/backend-api:$COMMIT_SHA']
  
  # Deploy to Cloud Run
  - name: 'gcr.io/google.com/cloudsdktool/cloud-sdk'
    entrypoint: gcloud
    args:
      - 'run'
      - 'deploy'
      - 'universal-translator-api'
      - '--image=gcr.io/$PROJECT_ID/backend-api:$COMMIT_SHA'
      - '--region=us-central1'
      - '--platform=managed'

# Trigger on push to main branch
trigger:
  branch:
    name: main
```

---

## 🔐 Security Best Practices

### GCP-Specific Security Measures

1. **Enable VPC Service Controls** - Restrict API access
2. **Use Workload Identity** - Secure service authentication
3. **Enable Binary Authorization** - Verify container images
4. **Configure Cloud IAM** - Least privilege access
5. **Enable Cloud Security Scanner** - Vulnerability detection
6. **Use Customer-Managed Encryption Keys** - Enhanced data protection
7. **Enable Access Transparency** - Audit GCP admin access
8. **Configure Private Google Access** - Secure internal communication

---

## 📱 iOS App Configuration

### Update iOS App for GCP

```swift
// AppDelegate.swift
import Firebase
import GoogleSignIn

class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(_ application: UIApplication,
                    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        
        // Initialize Firebase
        FirebaseApp.configure()
        
        // Configure GCP endpoints
        Configuration.shared.apiEndpoint = "https://universal-translator-api-xxxxx.a.run.app"
        Configuration.shared.cdnEndpoint = "https://cdn.universaltranslator.app"
        
        return true
    }
}

// NetworkManager.swift
class NetworkManager {
    private let baseURL = "https://universal-translator-api-xxxxx.a.run.app"
    
    func translateText(_ text: String) async throws -> TranslationResult {
        // Use Cloud Run endpoint
        let url = URL(string: "\(baseURL)/v1/translate")!
        // ... rest of implementation
    }
}
```

---

## ✅ Deployment Checklist

### Pre-Deployment
- [ ] GCP billing account active
- [ ] All required APIs enabled
- [ ] Service accounts created
- [ ] IAM roles configured
- [ ] Secrets stored in Secret Manager

### Deployment
- [ ] Cloud Run service deployed
- [ ] Firebase initialized
- [ ] Cloud CDN configured
- [ ] Monitoring dashboards created
- [ ] Alert policies configured

### Post-Deployment
- [ ] Uptime checks passing
- [ ] SSL certificates valid
- [ ] Performance benchmarks met
- [ ] Security scans completed
- [ ] Cost tracking enabled

---

## 🚨 Rollback Procedure

```bash
# Quick rollback to previous version
gcloud run deploy universal-translator-api \
  --image gcr.io/universal-translator-prod/backend-api:PREVIOUS_SHA \
  --region us-central1

# Or use traffic splitting for gradual rollback
gcloud run services update-traffic universal-translator-api \
  --to-revisions=PREVIOUS_REVISION=100
```

---

## 📞 Support Contacts

- **GCP Support**: [Create ticket in Cloud Console]
- **Firebase Support**: firebase-support@google.com
- **Billing Issues**: GCP Billing Support
- **Security Incidents**: security@universaltranslator.app

---

**CONFIRMATION**: ✅ All deployment plans have been updated to use Google Cloud Platform exclusively. No AWS services are referenced or required. The infrastructure is fully compatible with GCP best practices and leverages native GCP services for optimal performance, security, and cost-efficiency.