# 🍎 App Store Connect Setup Guide for Payment Testing

## **📋 OVERVIEW**

This guide will walk you through setting up App Store Connect for in-app purchase testing with **Mervyn Talks**.

### **🎯 Product IDs to Configure**
```
com.mervyntalks.credits.300s  (5 minutes)
com.mervyntalks.credits.600s  (10 minutes)
```

### **📱 App Bundle ID**
```
com.universaltranslator.app
```

---

## **STEP 1: CREATE APP IN APP STORE CONNECT**

### **1.1 Access App Store Connect**
1. Go to [appstoreconnect.apple.com](https://appstoreconnect.apple.com)
2. Sign in with your Apple Developer account
3. Click **"My Apps"**

### **1.2 Create New App**
1. Click the **"+"** button → **"New App"**
2. Fill in the details:
   - **Platform**: iOS
   - **Name**: `Mervyn Talks`
   - **Primary Language**: English (U.S.)
   - **Bundle ID**: Select `com.universaltranslator.app`
   - **SKU**: `mervyn-talks-2025` (or any unique identifier)
   - **User Access**: Full Access
3. Click **"Create"**

---

## **STEP 2: CONFIGURE IN-APP PURCHASES**

### **2.1 Navigate to In-App Purchases**
1. In your app's page, click **"Features"** tab
2. Click **"In-App Purchases"**
3. Click **"Create"** (+ button)

### **2.2 Create First Product (5 Minutes)**
1. **Type**: Select **"Consumable"**
2. **Product ID**: `com.mervyntalks.credits.300s`
3. **Reference Name**: `5 Minutes Translation Credits`
4. **Price**: Select appropriate tier (e.g., $0.99 - Tier 1)
5. **Display Name**: `5 Minutes`
6. **Description**: `5 minutes of translation time`

### **2.3 Create Second Product (10 Minutes)**
1. Click **"Create"** again
2. **Type**: Select **"Consumable"**
3. **Product ID**: `com.mervyntalks.credits.600s`
4. **Reference Name**: `10 Minutes Translation Credits`
5. **Price**: Select appropriate tier (e.g., $1.99 - Tier 2)
6. **Display Name**: `10 Minutes`
7. **Description**: `10 minutes of translation time`

### **2.4 Submit for Review**
1. For each product, click **"Submit for Review"**
2. Status should change to **"Waiting for Review"**
3. ⚠️ **Note**: Products must be approved before testing

---

## **STEP 3: CREATE SANDBOX TEST ACCOUNT**

### **3.1 Navigate to Sandbox**
1. In App Store Connect, go to **"Users and Access"**
2. Click **"Sandbox"** tab
3. Click **"Testers"** section

### **3.2 Create Test User**
1. Click **"+"** to add new tester
2. Fill in details:
   - **First Name**: Test
   - **Last Name**: User
   - **Email**: Use a **NEW email** (not associated with any Apple ID)
   - **Password**: Create strong password
   - **Confirm Password**: Same password
   - **Date of Birth**: Set to adult age
   - **App Store Territory**: United States
3. Click **"Invite"**

### **3.3 Important Notes**
- ⚠️ **Use a completely new email address**
- ⚠️ **Don't use your personal Apple ID**
- ⚠️ **Remember the credentials** - you'll need them for testing

---

## **STEP 4: DEVICE SETUP FOR TESTING**

### **4.1 Sign Out of Production Apple ID**
1. On your test device, go to **Settings** → **App Store**
2. Tap your Apple ID at the top
3. Tap **"Sign Out"**

### **4.2 Install and Launch App**
1. Install your app via Xcode or TestFlight
2. Launch the app
3. **DO NOT sign into App Store yet**

### **4.3 Test Purchase Flow**
1. In your app, navigate to purchase screen
2. Tap on a credit package (5 or 10 minutes)
3. When prompted for Apple ID, use your **sandbox account credentials**
4. Complete the purchase flow

---

## **STEP 5: VERIFICATION CHECKLIST**

### **✅ Before Testing**
- [ ] App created in App Store Connect
- [ ] Both in-app purchase products created and submitted
- [ ] Sandbox test account created
- [ ] Signed out of production Apple ID on test device
- [ ] App installed on physical device (required for StoreKit)

### **✅ During Testing**
- [ ] Purchase flow initiates correctly
- [ ] Sandbox login prompt appears
- [ ] Purchase completes successfully
- [ ] Credits are added to user balance
- [ ] Receipt verification works
- [ ] Transaction is marked as finished

### **✅ After Testing**
- [ ] Check Xcode console for debug logs
- [ ] Verify credits balance increased
- [ ] Test multiple purchases
- [ ] Test purchase cancellation
- [ ] Test network interruption scenarios

---

## **STEP 6: TROUBLESHOOTING**

### **Common Issues**

#### **"No products available"**
- **Cause**: Products not approved or wrong product IDs
- **Solution**: Check product status in App Store Connect, verify IDs match code

#### **"Cannot connect to iTunes Store"**
- **Cause**: Using production Apple ID or network issues
- **Solution**: Sign out completely, use sandbox account

#### **"This Apple ID has not yet been used with the App Store"**
- **Cause**: Sandbox account not properly created
- **Solution**: Create new sandbox account with different email

#### **Purchase fails with error**
- **Cause**: Various StoreKit issues
- **Solution**: Check Xcode console logs, verify device setup

---

## **STEP 7: DEBUG INFORMATION**

### **Expected Console Output**
When testing, you should see logs like:
```
🔍 [ProfileBadge] User data available:
📱 [Store] Loading products for IDs: ["com.mervyntalks.credits.300s", "com.mervyntalks.credits.600s"]
✅ [Purchase] Product loaded: 5 Minutes ($0.99)
✅ [Purchase] Product loaded: 10 Minutes ($1.99)
✅ [Purchase] Transaction verified and credits granted
```

### **Product Configuration Verification**
The app expects these exact product IDs:
- `com.mervyntalks.credits.300s` → Grants 300 seconds (5 minutes)
- `com.mervyntalks.credits.600s` → Grants 600 seconds (10 minutes)

---

## **🚀 READY TO TEST!**

Once you've completed all steps:

1. **Launch the app** on a physical device
2. **Navigate to purchase screen** (when credits are low)
3. **Select a credit package**
4. **Sign in with sandbox account** when prompted
5. **Complete purchase**
6. **Verify credits are added**

### **Next Steps After Successful Testing**
1. Test all purchase scenarios
2. Verify cross-device sync (if applicable)
3. Test purchase restoration
4. Submit app for App Store Review
5. Plan production launch strategy

---

**📞 Need Help?**
- Check Xcode console for detailed logs
- Verify all product IDs match exactly
- Ensure using physical device (not simulator)
- Confirm sandbox account is properly set up

**Status: Ready for App Store Connect configuration! 🎉**
