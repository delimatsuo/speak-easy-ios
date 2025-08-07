# 🚀 TestFlight Submission Guide

## Current Status

### ⚠️ Immediate Action Required
1. **Get new Gemini API key**: The current API key has expired
2. **Run update script**: `./update_api_key.sh`
3. **Build iOS app**: Use Xcode to create archive

## 📝 Step-by-Step TestFlight Submission

### Step 1: Fix Backend API (5 minutes)
```bash
# Get new API key from: https://makersuite.google.com/app/apikey
# Then run:
./update_api_key.sh
```

### Step 2: Prepare iOS App (10 minutes)

#### Option A: Using Xcode (Recommended)
1. Open `/iOS/UniversalTranslator.xcodeproj` in Xcode
2. Select "Any iOS Device" as build target
3. Go to Product > Archive
4. Wait for archive to complete
5. In Organizer, click "Distribute App"
6. Select "App Store Connect" > Next
7. Select "Upload" > Next
8. Follow prompts to upload

#### Option B: Command Line
```bash
cd iOS
./build_testflight.sh
```

### Step 3: Configure TestFlight (15 minutes)

1. **Go to App Store Connect**
   - https://appstoreconnect.apple.com

2. **Select your app** (Mervyn Talks)

3. **Go to TestFlight tab**

4. **Set up Test Information**:
   - Beta App Description: "Voice-to-voice translation app"
   - Email: beta@speakeasy.app
   - Privacy Policy URL: (use your website)
   - License Agreement: Standard EULA

5. **Add Beta Testers**:
   - Click "+" next to "Individual Testers"
   - Add email addresses
   - Or create a Public Link for easier distribution

6. **Submit for Beta Review**:
   - Answer export compliance questions (No encryption)
   - Submit for review

### Step 4: Notify Beta Testers

Send this email to your testers:

```
Subject: You're invited to test Mervyn Talks!

Hi [Name],

You're invited to beta test Mervyn Talks, our new voice translation app!

To get started:
1. Download TestFlight from the App Store
2. Open this link on your iPhone: [TestFlight Link]
3. Install Mervyn Talks
4. Start translating!

Please refer to the Beta Testing Guide for instructions and how to provide feedback.

Thanks for your help!
The Mervyn Talks Team
```

## 📋 Pre-Submission Checklist

### Backend
- [ ] New Gemini API key obtained
- [ ] API key updated in Secret Manager
- [ ] Translation endpoint working
- [ ] All endpoints tested

### iOS App
- [ ] Production API URL configured
- [ ] Archive builds successfully
- [ ] No critical warnings
- [ ] Permissions configured (mic, speech)

### TestFlight
- [ ] App uploaded to App Store Connect
- [ ] Test information completed
- [ ] Beta testers added
- [ ] Beta testing guide shared

### Documentation
- [ ] Beta testing guide created
- [ ] Known issues documented
- [ ] Support email configured

## 🧪 Testing Before Release

### Quick Smoke Test
1. Install from TestFlight
2. Allow permissions
3. Test English → Spanish translation
4. Verify audio playback
5. Check history saves

### Full Test Cycle
- [ ] All 12 languages
- [ ] Long sentences
- [ ] Network interruption
- [ ] Background/foreground
- [ ] Memory usage

## 📊 Beta Metrics to Track

- Installation rate
- Crash reports
- Translation success rate
- Average session length
- User feedback scores

## 🚨 Common Issues & Solutions

### Issue: "API Key Invalid"
**Solution**: Run `./update_api_key.sh` with new key

### Issue: Build fails in Xcode
**Solution**: 
1. Clean build folder (Shift+Cmd+K)
2. Reset package cache
3. Check signing settings

### Issue: TestFlight not showing build
**Solution**: Wait 5-10 minutes for processing

### Issue: Testers can't install
**Solution**: Ensure they accepted invite and have compatible iOS version

## 📞 Support Channels

- **Technical Issues**: Check Cloud Run logs
- **Beta Feedback**: Via TestFlight feedback
- **Urgent Issues**: Direct email to team

## 🎯 Success Criteria

Beta is successful when:
- ✅ 10+ active testers
- ✅ <1% crash rate
- ✅ 90%+ translation success
- ✅ Positive feedback on UX
- ✅ No critical bugs

## 🚀 After Beta

1. Incorporate feedback
2. Fix identified issues
3. Prepare for App Store submission
4. Plan marketing launch

---

## Quick Commands Reference

```bash
# Update API key
./update_api_key.sh

# Test backend
curl https://universal-translator-api-932729595834.us-central1.run.app/health

# Build for TestFlight
cd iOS && ./build_testflight.sh

# Check logs
gcloud logging read "resource.type=cloud_run_revision" --limit=20
```

## Timeline

- **Today**: Fix API key, upload to TestFlight
- **Tomorrow**: Send invites to beta testers
- **Week 1**: Collect initial feedback
- **Week 2**: Fix issues, iterate
- **Week 3**: Prepare for public launch

---

**Ready to launch your beta! 🚀**