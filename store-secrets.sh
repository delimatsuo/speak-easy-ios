#!/bin/bash

# Script to securely store API keys in GCP Secret Manager

echo "🔐 Secret Manager Setup for Universal Translator App"
echo "=================================================="

PROJECT_ID="universal-translator-prod"
gcloud config set project $PROJECT_ID

echo -e "\n📝 This script will help you securely store your API keys."
echo "DO NOT paste your actual keys in any file that will be committed to git!"

# Function to create or update a secret
store_secret() {
    local SECRET_NAME=$1
    local SECRET_DESC=$2
    
    echo -e "\n🔑 Setting up: $SECRET_DESC"
    echo "-----------------------------------"
    
    # Check if secret exists
    if gcloud secrets describe $SECRET_NAME &>/dev/null; then
        echo "Secret '$SECRET_NAME' already exists. Creating new version..."
        echo -n "Enter your $SECRET_DESC (input hidden): "
        read -s SECRET_VALUE
        echo
        echo -n "$SECRET_VALUE" | gcloud secrets versions add $SECRET_NAME --data-file=-
    else
        echo "Creating new secret '$SECRET_NAME'..."
        echo -n "Enter your $SECRET_DESC (input hidden): "
        read -s SECRET_VALUE
        echo
        echo -n "$SECRET_VALUE" | gcloud secrets create $SECRET_NAME \
            --replication-policy="automatic" \
            --data-file=-
    fi
    
    if [ $? -eq 0 ]; then
        echo "✅ Secret '$SECRET_NAME' stored successfully!"
        
        # Grant Cloud Run service account access
        PROJECT_NUMBER=$(gcloud projects describe $PROJECT_ID --format="value(projectNumber)")
        gcloud secrets add-iam-policy-binding $SECRET_NAME \
            --member="serviceAccount:${PROJECT_NUMBER}-compute@developer.gserviceaccount.com" \
            --role="roles/secretmanager.secretAccessor" &>/dev/null
        echo "✅ Granted Cloud Run access to secret"
    else
        echo "❌ Failed to store secret '$SECRET_NAME'"
    fi
}

# Main menu
echo -e "\n🚀 Starting Secret Storage Process..."

# 1. Gemini API Key (REQUIRED)
echo -e "\n============================================"
echo "1️⃣  GEMINI API KEY (Required for translation)"
echo "============================================"
echo "Get your key from: https://makersuite.google.com/app/apikey"
echo "The key should start with 'AIza'"
store_secret "gemini-api-key" "Gemini API Key"

# 2. Firebase Config (Optional - if using Firebase)
echo -e "\n============================================"
echo "2️⃣  FIREBASE CONFIGURATION (Optional)"
echo "============================================"
echo "Only needed if you're using Firebase services"
echo -n "Do you want to store Firebase config? (y/n): "
read STORE_FIREBASE

if [[ "$STORE_FIREBASE" == "y" ]]; then
    echo "Please provide the path to your GoogleService-Info.plist file"
    echo -n "File path (or press Enter to skip): "
    read FIREBASE_FILE
    
    if [[ -f "$FIREBASE_FILE" ]]; then
        gcloud secrets create firebase-config --data-file="$FIREBASE_FILE" \
            --replication-policy="automatic" 2>/dev/null || \
        gcloud secrets versions add firebase-config --data-file="$FIREBASE_FILE"
        echo "✅ Firebase config stored successfully!"
    else
        echo "⏭️  Skipping Firebase config"
    fi
fi

# 3. List all secrets
echo -e "\n📋 Current Secrets in Project:"
echo "-----------------------------------"
gcloud secrets list --format="table(name,created,replication.automatic)"

# 4. Test secret access
echo -e "\n🧪 Testing secret access..."
if gcloud secrets versions access latest --secret="gemini-api-key" &>/dev/null; then
    echo "✅ Successfully accessed gemini-api-key"
else
    echo "❌ Failed to access gemini-api-key"
fi

echo -e "\n✅ Secret setup complete!"
echo ""
echo "Next steps:"
echo "1. Deploy your backend to Cloud Run using ./deploy-backend.sh"
echo "2. The backend will automatically load these secrets at runtime"
echo "3. Never commit actual API keys to your repository"
echo ""
echo "To manually access a secret:"
echo "  gcloud secrets versions access latest --secret=gemini-api-key"