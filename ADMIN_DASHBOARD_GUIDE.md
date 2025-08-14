# 🗣️ Mervyn Talks Admin Dashboard Guide

## Overview

The Mervyn Talks Admin Dashboard provides comprehensive tools for monitoring, managing, and analyzing your translation app. There are two dashboard options available:

- **Enhanced Dashboard**: Full-featured analytics and management interface
- **Basic Dashboard**: Lightweight interface for quick user management

## 🚀 Quick Start

### 1. Deploy the Admin Dashboard

```bash
# Deploy both dashboards to Firebase Hosting
./deploy-admin.sh
```

### 2. Grant Admin Access

```bash
# Grant admin privileges to your account
python3 scripts/grant_admin.py your-email@domain.com
```

### 3. Access the Dashboard

Visit your Firebase Hosting URL:
- Dashboard Selector: `https://your-project.web.app/admin/select.html`
- Enhanced Dashboard: `https://your-project.web.app/admin/index.html`

## 📊 Enhanced Dashboard Features

### Overview Metrics
- **Total Users**: Complete user count across all time
- **Total Revenue**: Calculated based on IAP transactions
- **Active Users (30d)**: Users who had sessions in the last 30 days
- **Total Sessions**: Aggregate session count across all users

### 👥 User Management Tab

#### User Table Features
- **Search**: Find users by email or UID
- **Filtering**: Filter by activity, usage, or credit levels
- **Bulk Actions**: Perform operations on multiple users
- **Export**: Download user data for analysis

#### Individual User Actions
- **Edit Credits**: Add, subtract, or set user credits
- **View Statistics**: See user's usage history and revenue
- **Account Management**: Access user details and session data

#### Bulk Operations
1. Select multiple users using checkboxes
2. Click "Bulk Actions" 
3. Choose from:
   - Add credits to all selected users
   - Set credits for all selected users
   - Send notifications (future feature)

### 💰 Revenue Analytics Tab

#### Revenue Tracking
- **Total Revenue**: All-time revenue with trend indicators
- **Monthly Revenue**: Current month performance
- **Product Performance**: Breakdown by 5-min vs 10-min packages
- **ARPU**: Average Revenue Per User calculation

#### Transaction History
- View recent purchases
- Transaction details and status
- User purchase patterns
- Revenue attribution

#### Revenue Configuration
- Set product prices for accurate calculations
- Prices are stored locally in your browser
- Update pricing to reflect App Store changes

### 📈 Analytics Tab

#### Language Usage
- Most popular translation pairs
- Language preference trends
- Geographic usage patterns (if available)

#### Session Analytics
- Average session duration
- Peak usage times
- User retention patterns
- Platform distribution (iOS/iPad)

#### User Behavior
- Retention cohorts
- Usage frequency patterns
- Feature adoption rates

### ⚙️ System Tab

#### Health Monitoring
- API endpoint status
- External service health (Gemini, Firebase)
- System uptime and performance
- Error rates and alerts

#### System Statistics
- Database document counts
- API request volumes
- Performance metrics
- Resource utilization

#### Configuration Management
- Update product pricing
- System settings
- Feature flags (future)

## 🔧 Technical Details

### Firebase Integration
The dashboard connects directly to your Firebase project:
- **Authentication**: Google Sign-In with admin custom claims
- **Firestore**: Direct access to user, credit, and transaction data
- **Hosting**: Deployed via Firebase Hosting for security

### Data Sources
- **Users Collection**: User profiles and session data
- **Credits Collection**: Current credit balances
- **Transaction Sub-collections**: Purchase history per user
- **Backend Analytics**: Real-time API usage (via `/v1/admin/analytics`)

### Security
- **Admin-Only Access**: Requires Firebase custom claim `admin: true`
- **No Personal Data**: No conversation content is stored or displayed
- **Secure Authentication**: Google OAuth with Firebase Auth
- **Audit Logging**: All admin actions are logged

## 📱 Mobile-Responsive Design

The enhanced dashboard is fully responsive and works on:
- Desktop computers
- Tablets (iPad, Android tablets)
- Mobile phones (limited functionality)

## 🔍 Common Admin Tasks

### Adding Credits to a User
1. Go to Users tab
2. Search for the user by email or UID
3. Click "Edit" in their row
4. Choose "Add Credits" and enter amount
5. Click "Save Changes"

### Viewing Revenue Performance
1. Go to Revenue tab
2. Set correct product prices if not already set
3. Review total revenue and monthly trends
4. Check recent transactions for details

### Monitoring System Health
1. Go to System tab
2. Check API Health section for any issues
3. Review error rates and performance metrics
4. Monitor uptime and resource usage

### Bulk Credit Operations
1. Go to Users tab
2. Use checkboxes to select multiple users
3. Click "Bulk Actions"
4. Choose operation type and enter amount
5. Confirm the bulk operation

### Exporting User Data
1. Go to Users tab
2. Apply any desired filters
3. Click "Export" button
4. Download CSV file for analysis

## 📊 Analytics Insights

### Key Metrics to Monitor
- **Daily Active Users**: Indicates app engagement
- **Revenue per User**: Shows monetization effectiveness
- **Session Duration**: Measures user engagement depth
- **Error Rates**: Identifies technical issues
- **Language Pair Popularity**: Informs feature development

### Growth Indicators
- User registration trends
- Revenue growth month-over-month
- Session frequency improvements
- Retention rate increases

## 🚨 Alerts & Monitoring

### Automatic Alerts (Future Feature)
- High error rates detected
- Unusual usage spikes
- Revenue anomalies
- System health issues

### Manual Monitoring
- Check dashboard daily for key metrics
- Review error rates weekly
- Analyze user feedback and support requests
- Monitor App Store reviews and ratings

## 🔒 Privacy & Compliance

### Data Protection
- **No Conversation Storage**: Conversations are never stored
- **Minimal User Data**: Only essential metadata is collected
- **Secure Access**: Admin dashboard requires authentication
- **Audit Trail**: All admin actions are logged

### GDPR Compliance
- Users can request data deletion
- Data retention policies are enforced
- Personal data is minimized
- Consent is properly managed

## 📞 Support & Troubleshooting

### Common Issues

#### "Not signed in" Error
- Ensure you have admin custom claim
- Sign out and back in to refresh token
- Check with `python3 scripts/grant_admin.py your-email@domain.com`

#### Dashboard Not Loading
- Check Firebase Hosting deployment
- Verify project configuration
- Check browser console for errors

#### Data Not Appearing
- Ensure Firebase rules allow admin access
- Check internet connection
- Verify Firestore data exists

### Getting Help
- Check Firebase Console for deployment issues
- Review browser developer tools for JavaScript errors
- Verify admin permissions in Firebase Auth
- Contact technical support if issues persist

## 🎯 Best Practices

### Daily Operations
1. Check overview metrics for any anomalies
2. Review revenue performance
3. Monitor system health status
4. Respond to any user support requests

### Weekly Analysis
1. Analyze user growth trends
2. Review revenue patterns
3. Check for technical issues
4. Plan feature improvements

### Monthly Reviews
1. Generate comprehensive analytics reports
2. Review user feedback and ratings
3. Assess monetization performance
4. Plan strategic improvements

## 🚀 Future Enhancements

### Planned Features
- **Real-time Notifications**: Push alerts for critical events
- **Advanced Analytics**: Machine learning insights
- **A/B Testing Tools**: Feature experimentation
- **User Communication**: In-app messaging and notifications
- **Automated Reports**: Scheduled analytics emails
- **Custom Dashboards**: Personalized admin views

### Integration Opportunities
- **App Store Connect API**: Revenue reconciliation
- **Customer Support Tools**: Integrated help desk
- **Business Intelligence**: Data warehouse integration
- **Mobile Admin App**: iOS admin companion app

---

## 🎉 Conclusion

The Mervyn Talks Admin Dashboard provides everything you need to successfully monitor and manage your translation app. From user management to revenue analytics, the dashboard gives you complete visibility into your app's performance.

Start with the basic dashboard for simple tasks, then graduate to the enhanced dashboard as your needs grow. The modular design ensures you can scale your admin capabilities alongside your business.

**Happy managing!** 🗣️✨
