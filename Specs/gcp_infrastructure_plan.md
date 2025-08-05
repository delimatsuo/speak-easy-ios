# ⚠️ CRITICAL INFRASTRUCTURE UPDATE - GCP EXCLUSIVE
## Universal Translator App - Google Cloud Platform Migration

### 🚨 URGENT COORDINATION NOTICE
**Requirement**: Complete migration to Google Cloud Platform services  
**Timeline**: Immediate adjustment required  
**Impact**: All deployment scripts and configurations must be updated  
**Teams Affected**: Backend PM, Backend Dev, Frontend Dev  

---

## 1. GCP INFRASTRUCTURE ARCHITECTURE

### 1.1 Service Migration Matrix

#### 🔄 **AWS to GCP Service Mapping**
| Component | ❌ AWS Service (OLD) | ✅ GCP Service (NEW) | Migration Status |
|-----------|---------------------|---------------------|------------------|
| **Backend API** | AWS Lambda/ECS | Cloud Run | 🔄 PENDING |
| **Object Storage** | S3 | Cloud Storage | 🔄 PENDING |
| **CDN** | CloudFront | Cloud CDN | 🔄 PENDING |
| **Monitoring** | CloudWatch | Cloud Monitoring | 🔄 PENDING |
| **Secrets** | Secrets Manager | Secret Manager | 🔄 PENDING |
| **Database** | DynamoDB | Firestore | 🔄 PENDING |
| **Authentication** | Cognito | Firebase Auth | 🔄 PENDING |
| **Load Balancer** | ALB | Cloud Load Balancing | 🔄 PENDING |
| **Container Registry** | ECR | Artifact Registry | 🔄 PENDING |
| **CI/CD** | CodePipeline | Cloud Build | 🔄 PENDING |

### 1.2 Updated GCP Architecture

```yaml
# GCP Production Infrastructure Configuration
project_id: universal-translator-prod
region: us-central1
zone: us-central1-a

services:
  backend_api:
    service: Cloud Run
    config:
      name: universal-translator-api
      region: us-central1
      cpu: 2
      memory: 4Gi
      min_instances: 2
      max_instances: 100
      concurrency: 1000
      timeout: 300s
      
  database:
    service: Firestore
    config:
      mode: Native
      location: us-central1
      collections:
        - users
        - translations
        - sessions
        - analytics
      
  storage:
    service: Cloud Storage
    buckets:
      - name: universal-translator-assets
        location: US
        storage_class: STANDARD
        versioning: true
      - name: universal-translator-backups
        location: US
        storage_class: NEARLINE
        lifecycle: 30_days
        
  cdn:
    service: Cloud CDN
    config:
      backend_service: universal-translator-api
      cache_mode: CACHE_ALL_STATIC
      default_ttl: 3600
      max_ttl: 86400
      
  secrets:
    service: Secret Manager
    secrets:
      - gemini_api_key
      - firebase_admin_key
      - monitoring_api_key
      - apple_certificates
```

---

## 2. CLOUD RUN DEPLOYMENT CONFIGURATION

### 2.1 Backend API Deployment

#### 🚀 **Cloud Run Service Configuration**
```dockerfile
# Dockerfile for Cloud Run deployment
FROM node:20-alpine

WORKDIR /app

# Copy package files
COPY package*.json ./
RUN npm ci --only=production

# Copy application code
COPY . .

# Build TypeScript
RUN npm run build

# Set environment variables
ENV NODE_ENV=production
ENV PORT=8080

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD node healthcheck.js

# Start application
CMD ["node", "dist/index.js"]
```

#### 📦 **Cloud Run Deployment Script**
```bash
#!/bin/bash
# deploy-to-cloud-run.sh

# Configuration
PROJECT_ID="universal-translator-prod"
SERVICE_NAME="universal-translator-api"
REGION="us-central1"
IMAGE_NAME="gcr.io/${PROJECT_ID}/${SERVICE_NAME}"

# Build and push Docker image
echo "🔨 Building Docker image..."
docker build -t ${IMAGE_NAME} .

echo "📤 Pushing to Container Registry..."
docker push ${IMAGE_NAME}

# Deploy to Cloud Run
echo "🚀 Deploying to Cloud Run..."
gcloud run deploy ${SERVICE_NAME} \
  --image ${IMAGE_NAME} \
  --platform managed \
  --region ${REGION} \
  --memory 4Gi \
  --cpu 2 \
  --timeout 300 \
  --min-instances 2 \
  --max-instances 100 \
  --concurrency 1000 \
  --port 8080 \
  --allow-unauthenticated \
  --set-env-vars "NODE_ENV=production" \
  --set-secrets "GEMINI_API_KEY=gemini_api_key:latest" \
  --set-secrets "FIREBASE_ADMIN_KEY=firebase_admin_key:latest"

echo "✅ Cloud Run deployment complete!"
```

### 2.2 Cloud Run Service Monitoring

```yaml
# monitoring.yaml - Cloud Monitoring configuration
apiVersion: monitoring.googleapis.com/v1
kind: UptimeCheckConfig
metadata:
  name: universal-translator-uptime
spec:
  displayName: Universal Translator API Uptime
  monitoredResource:
    type: cloud_run_service
    labels:
      service_name: universal-translator-api
      location: us-central1
  httpCheck:
    path: /health
    port: 443
    requestMethod: GET
    acceptedResponseStatusCodes:
      - start: 200
        end: 299
  period: 60s
  timeout: 10s
  
---
apiVersion: monitoring.googleapis.com/v1
kind: AlertPolicy
metadata:
  name: high-latency-alert
spec:
  displayName: High API Latency Alert
  conditions:
    - displayName: Request latency > 2s
      conditionThreshold:
        filter: |
          resource.type="cloud_run_revision"
          resource.labels.service_name="universal-translator-api"
          metric.type="run.googleapis.com/request_latencies"
        comparison: COMPARISON_GT
        thresholdValue: 2000
        duration: 300s
  notificationChannels:
    - projects/universal-translator-prod/notificationChannels/email
```

---

## 3. FIREBASE INTEGRATION FOR iOS

### 3.1 Firebase Configuration

#### 📱 **iOS Firebase Setup**
```swift
// AppDelegate.swift - Firebase initialization
import UIKit
import Firebase
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage
import FirebaseAnalytics

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    
    func application(_ application: UIApplication,
                    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        
        // Configure Firebase
        FirebaseApp.configure()
        
        // Enable offline persistence for Firestore
        let settings = FirestoreSettings()
        settings.isPersistenceEnabled = true
        settings.cacheSizeBytes = FirestoreCacheSizeUnlimited
        Firestore.firestore().settings = settings
        
        // Configure Firebase Auth
        configureAuthentication()
        
        // Initialize Analytics
        Analytics.setAnalyticsCollectionEnabled(true)
        
        return true
    }
    
    private func configureAuthentication() {
        // Anonymous auth for initial usage
        Auth.auth().signInAnonymously { (authResult, error) in
            if let error = error {
                print("Authentication failed: \(error)")
            } else if let user = authResult?.user {
                print("User authenticated: \(user.uid)")
                self.syncUserData(userId: user.uid)
            }
        }
    }
    
    private func syncUserData(userId: String) {
        let db = Firestore.firestore()
        let userRef = db.collection("users").document(userId)
        
        userRef.setData([
            "lastActive": FieldValue.serverTimestamp(),
            "platform": "iOS",
            "appVersion": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        ], merge: true)
    }
}
```

#### 🔥 **Firebase Services Configuration**
```swift
// FirebaseManager.swift
import Firebase
import FirebaseFirestore
import FirebaseStorage
import FirebaseAuth

class FirebaseManager {
    static let shared = FirebaseManager()
    
    private let db = Firestore.firestore()
    private let storage = Storage.storage()
    private let auth = Auth.auth()
    
    // Firestore Collections
    private let usersCollection = "users"
    private let translationsCollection = "translations"
    private let analyticsCollection = "analytics"
    
    // Store translation history
    func saveTranslation(_ translation: Translation) async throws {
        guard let userId = auth.currentUser?.uid else {
            throw FirebaseError.notAuthenticated
        }
        
        let data: [String: Any] = [
            "userId": userId,
            "sourceText": translation.sourceText,
            "translatedText": translation.translatedText,
            "sourceLanguage": translation.sourceLanguage,
            "targetLanguage": translation.targetLanguage,
            "timestamp": FieldValue.serverTimestamp(),
            "deviceModel": UIDevice.current.model,
            "iosVersion": UIDevice.current.systemVersion
        ]
        
        try await db.collection(translationsCollection).addDocument(data: data)
    }
    
    // Retrieve translation history
    func getTranslationHistory(limit: Int = 50) async throws -> [Translation] {
        guard let userId = auth.currentUser?.uid else {
            throw FirebaseError.notAuthenticated
        }
        
        let snapshot = try await db.collection(translationsCollection)
            .whereField("userId", isEqualTo: userId)
            .order(by: "timestamp", descending: true)
            .limit(to: limit)
            .getDocuments()
        
        return snapshot.documents.compactMap { document in
            Translation(from: document.data())
        }
    }
    
    // Upload audio files to Cloud Storage
    func uploadAudioFile(_ audioData: Data, fileName: String) async throws -> URL {
        let storageRef = storage.reference()
        let audioRef = storageRef.child("audio/\(fileName)")
        
        let metadata = StorageMetadata()
        metadata.contentType = "audio/mpeg"
        
        _ = try await audioRef.putDataAsync(audioData, metadata: metadata)
        let downloadURL = try await audioRef.downloadURL()
        
        return downloadURL
    }
}
```

### 3.2 Firebase Configuration Files

#### 📄 **GoogleService-Info.plist Configuration**
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CLIENT_ID</key>
    <string>[FIREBASE_CLIENT_ID]</string>
    <key>REVERSED_CLIENT_ID</key>
    <string>[FIREBASE_REVERSED_CLIENT_ID]</string>
    <key>API_KEY</key>
    <string>[FIREBASE_API_KEY]</string>
    <key>GCM_SENDER_ID</key>
    <string>[FIREBASE_GCM_SENDER_ID]</string>
    <key>PLIST_VERSION</key>
    <string>1</string>
    <key>BUNDLE_ID</key>
    <string>com.universaltranslator.app</string>
    <key>PROJECT_ID</key>
    <string>universal-translator-prod</string>
    <key>STORAGE_BUCKET</key>
    <string>universal-translator-prod.appspot.com</string>
    <key>IS_ADS_ENABLED</key>
    <false/>
    <key>IS_ANALYTICS_ENABLED</key>
    <true/>
    <key>IS_APPINVITE_ENABLED</key>
    <true/>
    <key>IS_GCM_ENABLED</key>
    <true/>
    <key>IS_SIGNIN_ENABLED</key>
    <true/>
    <key>GOOGLE_APP_ID</key>
    <string>[FIREBASE_APP_ID]</string>
</dict>
</plist>
```

---

## 4. GCP DEPLOYMENT SCRIPTS UPDATE

### 4.1 gcloud CLI Deployment Scripts

#### 🛠️ **Master Deployment Script**
```bash
#!/bin/bash
# deploy-gcp.sh - Complete GCP deployment script

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
PROJECT_ID="universal-translator-prod"
REGION="us-central1"
ZONE="us-central1-a"

echo -e "${GREEN}🚀 Starting GCP Deployment for Universal Translator${NC}"

# 1. Set project
echo -e "${YELLOW}Setting GCP project...${NC}"
gcloud config set project ${PROJECT_ID}

# 2. Enable required APIs
echo -e "${YELLOW}Enabling required GCP APIs...${NC}"
gcloud services enable \
  run.googleapis.com \
  firestore.googleapis.com \
  storage.googleapis.com \
  secretmanager.googleapis.com \
  cloudbuild.googleapis.com \
  monitoring.googleapis.com \
  logging.googleapis.com \
  artifactregistry.googleapis.com

# 3. Create Firestore database
echo -e "${YELLOW}Setting up Firestore database...${NC}"
gcloud firestore databases create \
  --location=${REGION} \
  --type=firestore-native

# 4. Create Cloud Storage buckets
echo -e "${YELLOW}Creating Cloud Storage buckets...${NC}"
gsutil mb -p ${PROJECT_ID} -l ${REGION} gs://universal-translator-assets/
gsutil mb -p ${PROJECT_ID} -l ${REGION} gs://universal-translator-backups/

# 5. Set up Secret Manager
echo -e "${YELLOW}Configuring Secret Manager...${NC}"
echo -n "${GEMINI_API_KEY}" | gcloud secrets create gemini_api_key \
  --data-file=- \
  --replication-policy="automatic"

# 6. Deploy Cloud Run service
echo -e "${YELLOW}Deploying to Cloud Run...${NC}"
./deploy-to-cloud-run.sh

# 7. Set up Cloud CDN
echo -e "${YELLOW}Configuring Cloud CDN...${NC}"
gcloud compute backend-services update universal-translator-backend \
  --enable-cdn \
  --cache-mode=CACHE_ALL_STATIC \
  --default-ttl=3600

# 8. Configure monitoring
echo -e "${YELLOW}Setting up Cloud Monitoring...${NC}"
gcloud monitoring dashboards create --config-from-file=monitoring-dashboard.json

# 9. Set up alerts
echo -e "${YELLOW}Creating monitoring alerts...${NC}"
gcloud alpha monitoring policies create --policy-from-file=alert-policies.yaml

echo -e "${GREEN}✅ GCP Deployment Complete!${NC}"
echo -e "${GREEN}Service URL: https://universal-translator-api-${REGION}-uc.a.run.app${NC}"
```

### 4.2 Infrastructure as Code (Terraform)

#### 📋 **Terraform Configuration for GCP**
```hcl
# main.tf - GCP Infrastructure as Code

terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
  backend "gcs" {
    bucket = "universal-translator-terraform-state"
    prefix = "prod/state"
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

# Variables
variable "project_id" {
  default = "universal-translator-prod"
}

variable "region" {
  default = "us-central1"
}

# Firestore Database
resource "google_firestore_database" "database" {
  project     = var.project_id
  name        = "(default)"
  location_id = var.region
  type        = "FIRESTORE_NATIVE"
}

# Cloud Storage Buckets
resource "google_storage_bucket" "assets" {
  name          = "universal-translator-assets"
  location      = "US"
  storage_class = "STANDARD"
  
  versioning {
    enabled = true
  }
  
  cors {
    origin          = ["*"]
    method          = ["GET", "HEAD"]
    response_header = ["*"]
    max_age_seconds = 3600
  }
}

resource "google_storage_bucket" "backups" {
  name          = "universal-translator-backups"
  location      = "US"
  storage_class = "NEARLINE"
  
  lifecycle_rule {
    condition {
      age = 30
    }
    action {
      type = "Delete"
    }
  }
}

# Cloud Run Service
resource "google_cloud_run_service" "api" {
  name     = "universal-translator-api"
  location = var.region
  
  template {
    spec {
      containers {
        image = "gcr.io/${var.project_id}/universal-translator-api:latest"
        
        resources {
          limits = {
            cpu    = "2"
            memory = "4Gi"
          }
        }
        
        env {
          name  = "NODE_ENV"
          value = "production"
        }
        
        env {
          name = "GEMINI_API_KEY"
          value_from {
            secret_key_ref {
              name = google_secret_manager_secret.gemini_api_key.secret_id
              key  = "latest"
            }
          }
        }
      }
      
      service_account_name = google_service_account.api_service_account.email
    }
    
    metadata {
      annotations = {
        "autoscaling.knative.dev/minScale" = "2"
        "autoscaling.knative.dev/maxScale" = "100"
        "run.googleapis.com/cpu-throttling" = "false"
      }
    }
  }
  
  traffic {
    percent         = 100
    latest_revision = true
  }
}

# Secret Manager
resource "google_secret_manager_secret" "gemini_api_key" {
  secret_id = "gemini_api_key"
  
  replication {
    automatic = true
  }
}

# Service Account
resource "google_service_account" "api_service_account" {
  account_id   = "universal-translator-api"
  display_name = "Universal Translator API Service Account"
}

# IAM Bindings
resource "google_project_iam_member" "firestore_user" {
  project = var.project_id
  role    = "roles/datastore.user"
  member  = "serviceAccount:${google_service_account.api_service_account.email}"
}

resource "google_project_iam_member" "storage_admin" {
  project = var.project_id
  role    = "roles/storage.admin"
  member  = "serviceAccount:${google_service_account.api_service_account.email}"
}

resource "google_project_iam_member" "secret_accessor" {
  project = var.project_id
  role    = "roles/secretmanager.secretAccessor"
  member  = "serviceAccount:${google_service_account.api_service_account.email}"
}

# Output
output "service_url" {
  value = google_cloud_run_service.api.status[0].url
}
```

---

## 5. BACKEND TEAM COORDINATION

### 5.1 Backend PM Action Items

#### 📋 **Critical Migration Tasks**
```yaml
Backend PM Responsibilities:
  Immediate Actions:
    ✅ Update all deployment documentation to GCP
    ✅ Coordinate with Backend Dev on Cloud Run migration
    ✅ Review and approve GCP architecture changes
    ✅ Update cost estimates for GCP services
    
  Infrastructure Migration:
    - Review Cloud Run configuration
    - Validate Firestore schema design
    - Approve Secret Manager setup
    - Confirm monitoring configuration
    
  Team Coordination:
    - Backend Dev: Cloud Run deployment scripts
    - Backend Tester: GCP testing environment
    - Frontend Dev: Firebase integration support
    - DevOps: CI/CD pipeline migration
```

### 5.2 Backend Dev Implementation Tasks

#### 💻 **Development Migration Checklist**
```typescript
// GCP Service Integration Updates

// 1. Update environment configuration
interface GCPConfig {
  projectId: string;
  region: string;
  services: {
    cloudRun: {
      serviceName: string;
      region: string;
    };
    firestore: {
      databaseId: string;
    };
    storage: {
      bucketName: string;
    };
    secretManager: {
      secrets: string[];
    };
  };
}

// 2. Firestore Integration
import { Firestore } from '@google-cloud/firestore';

class FirestoreService {
  private db: Firestore;
  
  constructor() {
    this.db = new Firestore({
      projectId: 'universal-translator-prod',
      databaseId: '(default)'
    });
  }
  
  async saveTranslation(translation: Translation): Promise<void> {
    await this.db.collection('translations').add({
      ...translation,
      timestamp: Firestore.FieldValue.serverTimestamp()
    });
  }
}

// 3. Cloud Storage Integration
import { Storage } from '@google-cloud/storage';

class CloudStorageService {
  private storage: Storage;
  private bucket: string = 'universal-translator-assets';
  
  constructor() {
    this.storage = new Storage({
      projectId: 'universal-translator-prod'
    });
  }
  
  async uploadFile(fileName: string, data: Buffer): Promise<string> {
    const file = this.storage.bucket(this.bucket).file(fileName);
    await file.save(data);
    return `gs://${this.bucket}/${fileName}`;
  }
}

// 4. Secret Manager Integration
import { SecretManagerServiceClient } from '@google-cloud/secret-manager';

class SecretService {
  private client: SecretManagerServiceClient;
  
  constructor() {
    this.client = new SecretManagerServiceClient();
  }
  
  async getSecret(secretName: string): Promise<string> {
    const name = `projects/universal-translator-prod/secrets/${secretName}/versions/latest`;
    const [version] = await this.client.accessSecretVersion({ name });
    return version.payload?.data?.toString() || '';
  }
}
```

---

## 6. FRONTEND TEAM COORDINATION

### 6.1 Frontend iOS Updates

#### 📱 **Firebase SDK Integration**
```swift
// Package.swift or Podfile updates

// Using Swift Package Manager
dependencies: [
  .package(url: "https://github.com/firebase/firebase-ios-sdk.git", from: "10.0.0")
]

// Or using CocoaPods
pod 'Firebase/Analytics'
pod 'Firebase/Auth'
pod 'Firebase/Firestore'
pod 'Firebase/Storage'
pod 'Firebase/Crashlytics'
pod 'Firebase/Performance'
```

### 6.2 Configuration Updates

#### ⚙️ **iOS App Configuration for GCP**
```swift
// Configuration.swift
struct AppConfiguration {
    static let environment = "production"
    
    // GCP Endpoints
    static let apiBaseURL = "https://universal-translator-api-us-central1.run.app"
    static let cdnBaseURL = "https://cdn.universal-translator.app"
    
    // Firebase Configuration
    static let firebaseProject = "universal-translator-prod"
    static let firestoreDatabase = "(default)"
    
    // Feature Flags
    static let useFirebaseAuth = true
    static let enableOfflineMode = true
    static let enableAnalytics = true
}
```

---

## 7. MIGRATION TIMELINE

### 7.1 Critical Path Timeline

#### ⏰ **24-Hour GCP Migration Plan**
```yaml
Hour 0-4: Infrastructure Setup
  - Create GCP project
  - Enable required APIs
  - Set up Firestore database
  - Create Cloud Storage buckets

Hour 4-8: Backend Migration
  - Deploy Cloud Run service
  - Migrate secrets to Secret Manager
  - Configure Cloud CDN
  - Set up monitoring

Hour 8-12: Frontend Integration
  - Update Firebase configuration
  - iOS app Firebase SDK integration
  - Test Firebase Auth flow
  - Validate Firestore connectivity

Hour 12-16: Testing & Validation
  - End-to-end testing on GCP
  - Performance validation
  - Security verification
  - Load testing

Hour 16-20: Production Preparation
  - Final deployment scripts
  - Documentation updates
  - Team training on GCP tools
  - Monitoring dashboard setup

Hour 20-24: Go-Live
  - Production deployment
  - Monitor initial traffic
  - Address any issues
  - Confirm stable operation
```

---

## 📋 COORDINATION STATUS

### ✅ **IMMEDIATE ACTIONS REQUIRED**

**Backend PM**:
- Review and approve GCP architecture
- Coordinate Cloud Run deployment
- Update cost projections

**Backend Dev**:
- Implement Cloud Run service
- Migrate to Firestore
- Update all API integrations

**Frontend Dev**:
- Integrate Firebase SDK
- Update app configuration
- Test Firebase services

**All Teams**:
- Update documentation to GCP
- Test in GCP environment
- Validate production readiness

---

**MIGRATION STATUS**: 🔄 **IN PROGRESS** - GCP infrastructure plan deployed  
**CRITICAL PATH**: Infrastructure setup → Backend migration → Frontend integration  
**TARGET**: Complete GCP migration within 24 hours  
**COORDINATION**: All teams notified and tasks assigned