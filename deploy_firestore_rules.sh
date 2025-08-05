#!/bin/bash

echo "Deploying Firestore security rules..."

cd /Users/delimatsuo/Documents/Codingclaude/UniversalTranslatorApp
firebase deploy --only firestore:rules --project universal-translator-prod

echo "✅ Firestore rules deployed!"