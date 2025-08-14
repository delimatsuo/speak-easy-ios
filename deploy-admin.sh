#!/bin/bash

# Deploy Enhanced Admin Dashboard to Firebase Hosting
# This script deploys the enhanced admin dashboard alongside the existing one

set -e

echo "🚀 Deploying Enhanced Admin Dashboard..."

# Check if we're in the right directory
if [ ! -f "firebase.json" ]; then
    echo "❌ Error: Please run this script from the project root directory"
    exit 1
fi

# Check if Firebase CLI is installed
if ! command -v firebase &> /dev/null; then
    echo "❌ Error: Firebase CLI is not installed"
    echo "Install it with: npm install -g firebase-tools"
    exit 1
fi

# Backup the existing admin page
if [ -f "admin/index.html" ]; then
    cp admin/index.html admin/index-basic.html
    echo "✅ Backed up existing admin page to admin/index-basic.html"
fi

# Copy the enhanced admin as the main admin page
cp admin/enhanced-admin.html admin/index.html
echo "✅ Set enhanced admin as main admin page"

# Create a simple landing page for admin selection
cat > admin/select.html << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Mervyn Talks - Admin Dashboard Selection</title>
    <style>
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            margin: 0;
            padding: 0;
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
        }
        .container {
            background: white;
            border-radius: 20px;
            padding: 3rem;
            text-align: center;
            box-shadow: 0 20px 40px rgba(0,0,0,0.1);
            max-width: 500px;
            width: 90%;
        }
        .logo {
            font-size: 3rem;
            margin-bottom: 1rem;
        }
        h1 {
            color: #333;
            margin-bottom: 0.5rem;
            font-size: 1.75rem;
        }
        .subtitle {
            color: #666;
            margin-bottom: 2rem;
            font-size: 1rem;
        }
        .dashboard-option {
            display: block;
            background: #2563eb;
            color: white;
            text-decoration: none;
            padding: 1rem 2rem;
            border-radius: 12px;
            margin: 1rem 0;
            font-weight: 600;
            transition: all 0.3s ease;
            border: 2px solid #2563eb;
        }
        .dashboard-option:hover {
            background: #1d4ed8;
            transform: translateY(-2px);
            box-shadow: 0 8px 20px rgba(37, 99, 235, 0.3);
        }
        .dashboard-option.secondary {
            background: white;
            color: #2563eb;
            border: 2px solid #e5e7eb;
        }
        .dashboard-option.secondary:hover {
            background: #f9fafb;
            border-color: #2563eb;
        }
        .feature-list {
            text-align: left;
            margin: 1rem 0;
            color: #666;
            font-size: 0.875rem;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="logo">🗣️</div>
        <h1>Mervyn Talks Admin</h1>
        <p class="subtitle">Choose your admin dashboard experience</p>
        
        <a href="index.html" class="dashboard-option">
            📊 Enhanced Dashboard
            <div class="feature-list">
                • Real-time analytics & metrics<br>
                • Advanced user management<br>
                • Revenue tracking & insights<br>
                • System health monitoring
            </div>
        </a>
        
        <a href="index-basic.html" class="dashboard-option secondary">
            ⚡ Basic Dashboard
            <div class="feature-list">
                • Simple user listing<br>
                • Basic credit adjustments<br>
                • Revenue overview<br>
                • Lightweight & fast
            </div>
        </a>
        
        <p style="color: #999; font-size: 0.8rem; margin-top: 2rem;">
            Admin access required • Firebase Authentication
        </p>
    </div>
</body>
</html>
EOF

echo "✅ Created admin dashboard selector"

# Deploy to Firebase Hosting
echo "🔄 Deploying to Firebase Hosting..."
firebase deploy --only hosting

# Get the hosting URL
PROJECT_ID=$(firebase use | grep -o "Now using project [^[:space:]]*" | awk '{print $4}' || echo "your-project")
HOSTING_URL="https://$PROJECT_ID.web.app"

echo ""
echo "🎉 Enhanced Admin Dashboard Deployed Successfully!"
echo ""
echo "📍 Access URLs:"
echo "   Dashboard Selector: $HOSTING_URL/admin/select.html"
echo "   Enhanced Dashboard: $HOSTING_URL/admin/index.html"
echo "   Basic Dashboard:    $HOSTING_URL/admin/index-basic.html"
echo ""
echo "🔑 Next Steps:"
echo "   1. Grant admin access to your account:"
echo "      python3 scripts/grant_admin.py your-email@domain.com"
echo ""
echo "   2. Sign out and back in to refresh your admin token"
echo ""
echo "   3. Visit the dashboard and explore the new features!"
echo ""
echo "💡 Pro Tip: Bookmark $HOSTING_URL/admin/select.html for quick access"
