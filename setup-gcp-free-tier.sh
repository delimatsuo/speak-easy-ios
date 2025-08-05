#!/bin/bash

# GCP Free Tier Setup Script for Universal Translator App
# This script sets up services that work within GCP free tier limits

echo "🚀 Setting up Universal Translator App - GCP Free Tier Configuration"
echo "================================================================"

PROJECT_ID="universal-translator-prod"

# Set the project
echo "Setting project to: $PROJECT_ID"
gcloud config set project $PROJECT_ID

# Check current authentication
echo -e "\n📝 Current authenticated account:"
gcloud auth list --filter=status:ACTIVE --format="value(account)"

# Enable free-tier compatible services
echo -e "\n🔧 Enabling free-tier services..."

# These services work without billing or have free tiers
SERVICES=(
    "firebase.googleapis.com"
    "firestore.googleapis.com"
    "storage.googleapis.com"
    "logging.googleapis.com"
    "monitoring.googleapis.com"
)

for service in "${SERVICES[@]}"; do
    echo "Enabling $service..."
    gcloud services enable $service 2>/dev/null || echo "  ⚠️  $service requires billing or is already enabled"
done

echo -e "\n✅ Enabled services:"
gcloud services list --enabled --format="table(config.name)" | head -20

# Create Firebase configuration
echo -e "\n🔥 Firebase Setup Instructions:"
echo "1. Go to: https://console.firebase.google.com"
echo "2. Click 'Add project'"
echo "3. Select existing GCP project: $PROJECT_ID"
echo "4. Follow the setup wizard"
echo "5. Download GoogleService-Info.plist for iOS"

# Set up local development environment
echo -e "\n💻 Local Development Setup:"
echo "Since Cloud Run requires billing, we'll use local development mode:"
echo ""
echo "1. Backend API (Local):"
echo "   cd backend/"
echo "   python -m venv venv"
echo "   source venv/bin/activate"
echo "   pip install -r requirements.txt"
echo "   uvicorn app.main:app --reload --port 8080"
echo ""
echo "2. iOS App Configuration:"
echo "   - Set API_BASE_URL to: http://localhost:8080"
echo "   - For device testing, use your Mac's IP: http://[YOUR-MAC-IP]:8080"
echo ""

# Create local environment file
echo -e "\n📄 Creating local environment configuration..."
cat > backend/.env.local << EOF
# Local Development Configuration
GCP_PROJECT=$PROJECT_ID
ENVIRONMENT=development
PORT=8080

# For local testing, you can set Gemini API key here (DO NOT COMMIT)
# GEMINI_API_KEY=your-key-here
EOF

echo "Created backend/.env.local"

# Alternative deployment options
echo -e "\n🌐 Alternative Free Deployment Options:"
echo "=================================="
echo "Since Cloud Run requires billing, consider these alternatives:"
echo ""
echo "1. Firebase Functions (Free tier: 125K invocations/month):"
echo "   - Can host the translation API"
echo "   - Integrated with Firebase services"
echo ""
echo "2. Google App Engine (Free tier: 28 instance hours/day):"
echo "   - Can host the backend API"
echo "   - Automatic scaling"
echo ""
echo "3. Local Development + ngrok (for testing):"
echo "   - Run backend locally"
echo "   - Use ngrok for public URL"
echo "   - brew install ngrok"
echo "   - ngrok http 8080"
echo ""

# Check for billing workarounds
echo -e "\n💡 To Enable Full GCP Services:"
echo "================================"
echo "You need to resolve the billing quota issue:"
echo "1. Visit: https://console.cloud.google.com/billing"
echo "2. Create a new billing account or"
echo "3. Request quota increase: https://support.google.com/code/contact/billing_quota_increase"
echo ""

echo "✅ Setup script complete!"
echo ""
echo "Next steps:"
echo "1. Set up Firebase in the console"
echo "2. Start local backend development"
echo "3. Configure iOS app for local testing"
echo "4. Consider alternative deployment options"