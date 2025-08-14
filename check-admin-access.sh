#!/bin/bash

# Check Admin Access Status
# This script helps verify your admin dashboard setup

set -e

echo "🔍 Checking Mervyn Talks Admin Setup..."
echo "======================================"

# Check if Firebase CLI is available
if command -v firebase &> /dev/null; then
    echo "✅ Firebase CLI: Installed"
    
    # Check current project
    CURRENT_PROJECT=$(firebase use | grep -o "Now using project [^[:space:]]*" | awk '{print $4}' 2>/dev/null || echo "none")
    if [ "$CURRENT_PROJECT" != "none" ]; then
        echo "✅ Firebase Project: $CURRENT_PROJECT"
        HOSTING_URL="https://$CURRENT_PROJECT.web.app"
    else
        echo "⚠️  Firebase Project: No project selected"
        echo "   Run: firebase use --add"
        HOSTING_URL="https://your-project.web.app"
    fi
else
    echo "❌ Firebase CLI: Not installed"
    echo "   Install with: npm install -g firebase-tools"
    HOSTING_URL="https://your-project.web.app"
fi

# Check if admin files exist
echo ""
echo "📁 Admin Dashboard Files:"
if [ -f "admin/index.html" ]; then
    BASIC_SIZE=$(wc -c < admin/index.html | tr -d ' ')
    echo "✅ Basic Dashboard: admin/index.html ($BASIC_SIZE bytes)"
else
    echo "❌ Basic Dashboard: Missing admin/index.html"
fi

if [ -f "admin/enhanced-admin.html" ]; then
    ENHANCED_SIZE=$(wc -c < admin/enhanced-admin.html | tr -d ' ')
    echo "✅ Enhanced Dashboard: admin/enhanced-admin.html ($ENHANCED_SIZE bytes)"
else
    echo "❌ Enhanced Dashboard: Missing admin/enhanced-admin.html"
fi

# Check if grant admin script exists
echo ""
echo "🔑 Admin Access Tools:"
if [ -f "scripts/grant_admin.py" ]; then
    echo "✅ Grant Admin Script: scripts/grant_admin.py"
    
    # Check Python dependencies
    if python3 -c "import firebase_admin" 2>/dev/null; then
        echo "✅ Firebase Admin SDK: Installed"
    else
        echo "⚠️  Firebase Admin SDK: Not installed"
        echo "   Install with: pip3 install firebase-admin"
    fi
else
    echo "❌ Grant Admin Script: Missing scripts/grant_admin.py"
fi

# Check deployment script
if [ -f "deploy-admin.sh" ]; then
    echo "✅ Deployment Script: deploy-admin.sh"
else
    echo "❌ Deployment Script: Missing deploy-admin.sh"
fi

# Check if already deployed
echo ""
echo "🌐 Deployment Status:"
if [ "$CURRENT_PROJECT" != "none" ]; then
    echo "🔄 Checking deployment status..."
    
    # Try to check if hosting is configured
    if [ -f ".firebaserc" ] && [ -f "firebase.json" ]; then
        echo "✅ Firebase Configuration: Ready"
        
        # Check if hosting is configured
        if grep -q '"hosting"' firebase.json; then
            echo "✅ Firebase Hosting: Configured"
        else
            echo "⚠️  Firebase Hosting: Not configured in firebase.json"
        fi
    else
        echo "⚠️  Firebase Configuration: Incomplete"
        echo "   Run: firebase init hosting"
    fi
else
    echo "⚠️  Cannot check deployment - no project selected"
fi

echo ""
echo "📋 Summary & Next Steps:"
echo "========================"

# Count issues
ISSUES=0

if ! command -v firebase &> /dev/null; then
    echo "❌ Install Firebase CLI: npm install -g firebase-tools"
    ((ISSUES++))
fi

if [ "$CURRENT_PROJECT" == "none" ]; then
    echo "❌ Select Firebase project: firebase use --add"
    ((ISSUES++))
fi

if ! python3 -c "import firebase_admin" 2>/dev/null; then
    echo "❌ Install Firebase Admin SDK: pip3 install firebase-admin"
    ((ISSUES++))
fi

if [ ! -f "admin/enhanced-admin.html" ]; then
    echo "❌ Enhanced admin dashboard file is missing"
    ((ISSUES++))
fi

if [ $ISSUES -eq 0 ]; then
    echo "🎉 Everything looks good! Ready to deploy and use admin dashboard."
    echo ""
    echo "🚀 Quick Deploy:"
    echo "   ./deploy-admin.sh"
    echo ""
    echo "🔑 Grant Admin Access:"
    echo "   python3 scripts/grant_admin.py your-email@domain.com"
    echo ""
    echo "🌐 Access Dashboard:"
    echo "   $HOSTING_URL/admin/select.html"
else
    echo "⚠️  Found $ISSUES issue(s) that need to be resolved first."
fi

echo ""
echo "💡 Pro Tips:"
echo "   • The enhanced dashboard provides comprehensive analytics"
echo "   • Use the basic dashboard for quick user credit adjustments"
echo "   • Always sign out and back in after granting admin access"
echo "   • Bookmark the admin URL for quick access"
echo ""
echo "📚 Full documentation: ADMIN_DASHBOARD_GUIDE.md"
