#!/bin/bash

# Security Validation Script for Universal AI Translator
# Validates production deployment security before release

set -e

echo "🔒 Universal AI Translator - Security Validation"
echo "════════════════════════════════════════════════"

VALIDATION_PASSED=true
CRITICAL_ISSUES=0
WARNING_ISSUES=0

# Function to report issues
report_critical() {
    echo "❌ CRITICAL: $1"
    CRITICAL_ISSUES=$((CRITICAL_ISSUES + 1))
    VALIDATION_PASSED=false
}

report_warning() {
    echo "⚠️ WARNING: $1"
    WARNING_ISSUES=$((WARNING_ISSUES + 1))
}

report_pass() {
    echo "✅ PASSED: $1"
}

echo "📋 Starting security validation..."
echo ""

# Check 1: Sensitive files not in repository
echo "🔍 Checking for sensitive files in repository..."

if git ls-files | grep -q "api_keys.plist"; then
    report_critical "api_keys.plist found in repository"
else
    report_pass "api_keys.plist not in repository"
fi

if git ls-files | grep "GoogleService-Info.plist" | grep -v "\.template$"; then
    report_critical "GoogleService-Info.plist found in repository (non-template)"
else
    # Additional check for ignored files
    if find . -name "GoogleService-Info.plist" -type f | grep -q .; then
        if git check-ignore iOS/Resources/Configuration/GoogleService-Info.plist &>/dev/null; then
            report_pass "GoogleService-Info.plist properly ignored by git"
        else
            report_critical "GoogleService-Info.plist exists but not ignored"
        fi
    else
        report_pass "GoogleService-Info.plist not in repository"
    fi
fi

if git ls-files | grep -E "\.(p8|p12|mobileprovision)$"; then
    report_critical "Code signing files found in repository"
else
    report_pass "No code signing files in repository"
fi

if git ls-files | grep -E "\.env\.(production|staging)$"; then
    report_critical "Environment files found in repository"
else
    report_pass "Environment files not in repository"
fi

# Check 2: .gitignore configuration
echo ""
echo "🔍 Checking .gitignore configuration..."

if grep -q "api_keys.plist" .gitignore; then
    report_pass ".gitignore blocks api_keys.plist"
else
    report_critical ".gitignore missing api_keys.plist"
fi

if grep -q "GoogleService-Info.plist" .gitignore; then
    report_pass ".gitignore blocks GoogleService-Info.plist"
else
    report_critical ".gitignore missing GoogleService-Info.plist"
fi

if grep -q "secrets/" .gitignore; then
    report_pass ".gitignore blocks secrets directory"
else
    report_warning ".gitignore missing secrets directory"
fi

# Check 3: Environment template files
echo ""
echo "🔍 Checking environment configuration..."

if [ -f "scripts/production.env.template" ]; then
    report_pass "Production environment template exists"
else
    report_warning "Production environment template missing"
fi

if [ -f "scripts/staging.env.template" ]; then
    report_pass "Staging environment template exists"
else
    report_warning "Staging environment template missing"
fi

# Check 4: Secure configuration implementation
echo ""
echo "🔍 Checking secure configuration implementation..."

if [ -f "iOS/Sources/Configuration/SecureConfig.swift" ]; then
    report_pass "SecureConfig.swift implementation exists"
else
    report_critical "SecureConfig.swift missing"
fi

if [ -f "iOS/Sources/Configuration/FirebaseConfigManager.swift" ]; then
    report_pass "FirebaseConfigManager.swift implementation exists"
else
    report_critical "FirebaseConfigManager.swift missing"
fi

# Check 5: Deployment script security
echo ""
echo "🔍 Checking deployment script security..."

if grep -q "GCP_PROJECT_ID:-" backend/deploy_voice.sh; then
    report_pass "deploy_voice.sh uses environment variables"
else
    report_warning "deploy_voice.sh may have hardcoded values"
fi

if grep -q "GCP_PROJECT_ID:-" deploy-backend.sh; then
    report_pass "deploy-backend.sh uses environment variables"
else
    report_warning "deploy-backend.sh may have hardcoded values"
fi

# Check 6: Code signing configuration
echo ""
echo "🔍 Checking code signing configuration..."

if [ -f "scripts/ExportOptions.plist" ]; then
    report_pass "ExportOptions.plist exists for App Store export"
else
    report_warning "ExportOptions.plist missing"
fi

if [ -f "scripts/build_production.sh" ]; then
    report_pass "Production build script exists"
    if [ -x "scripts/build_production.sh" ]; then
        report_pass "Build script is executable"
    else
        report_warning "Build script not executable"
    fi
else
    report_warning "Production build script missing"
fi

# Check 7: Documentation completeness
echo ""
echo "🔍 Checking documentation..."

if [ -f "iOS/Documentation/PRODUCTION_SIGNING_SETUP.md" ]; then
    report_pass "Production signing documentation exists"
else
    report_warning "Production signing documentation missing"
fi

if [ -f "PRODUCTION_DEPLOYMENT_COMPREHENSIVE_AUDIT.md" ]; then
    report_pass "Comprehensive audit documentation exists"
else
    report_warning "Audit documentation missing"
fi

# Check 8: Backend security
echo ""
echo "🔍 Checking backend security configuration..."

if grep -q "get_secret" backend/app/main_voice.py; then
    report_pass "Backend uses secure secret management"
else
    report_warning "Backend secret management needs review"
fi

if [ -f "backend/requirements.txt" ]; then
    report_pass "Backend dependencies documented"
else
    report_warning "Backend requirements.txt missing"
fi

# Final assessment
echo ""
echo "════════════════════════════════════════════════"
echo "🎯 SECURITY VALIDATION SUMMARY"
echo "════════════════════════════════════════════════"
echo ""

if [ "$VALIDATION_PASSED" = true ]; then
    echo "🎉 VALIDATION PASSED"
    echo "✅ All critical security checks passed"
    
    if [ "$WARNING_ISSUES" -gt 0 ]; then
        echo "⚠️ $WARNING_ISSUES warning(s) found - consider addressing"
    fi
    
    echo ""
    echo "🚀 DEPLOYMENT APPROVED"
    echo "The application is ready for production deployment"
    echo ""
    echo "Next steps:"
    echo "1. Set up production environment variables"
    echo "2. Configure code signing certificates"
    echo "3. Build and test on physical device"
    echo "4. Deploy to App Store Connect"
    
    exit 0
else
    echo "❌ VALIDATION FAILED"
    echo "🚨 $CRITICAL_ISSUES critical issue(s) must be resolved"
    
    if [ "$WARNING_ISSUES" -gt 0 ]; then
        echo "⚠️ $WARNING_ISSUES warning(s) should be addressed"
    fi
    
    echo ""
    echo "🛑 DEPLOYMENT BLOCKED"
    echo "Please resolve critical issues before proceeding"
    
    exit 1
fi
