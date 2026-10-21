# Adhkaar 365 — Firebase, App Check & Production Security Setup Guide

This guide contains the exact step-by-step production setup instructions for Firebase, Firebase App Check (Play Integrity), Google Cloud API key restrictions, and Cloud Firestore security rules for **Adhkaar 365** (`com.adhkaar365.app`).

> **Note:** This document is internal developer documentation and is **not** linked in the mobile application UI.

---

## Overview of App Credentials & Identifiers

| Parameter | Value |
|---|---|
| **Android Package Name** | `com.adhkaar365.app` |
| **Firebase Project ID** | `adhkar365` |
| **Project Number** | `622768800935` |
| **Android App ID** | `1:622768800935:android:609e1d06e5d0205f180782` |
| **Android API Key** | `AIzaSyBWLKSbVtQ-u5hEr9LXMTL7x0d4MBe5PGg` |

---

## Table of Contents

1. [Step 1: Link Play Console & Enable Play Integrity in App Check](#step-1-link-play-console--enable-play-integrity-in-app-check)
2. [Step 2: Register Debug Token for Local Development](#step-2-register-debug-token-for-local-development)
3. [Step 3: App Check Enforcement Strategy (Safe Rollout)](#step-3-app-check-enforcement-strategy-safe-rollout)
4. [Step 4: Restrict Android API Key in Google Cloud Console](#step-4-restrict-android-api-key-in-google-cloud-console)
5. [Step 5: Add Google Play App Signing SHA-1 and SHA-256 to Firebase](#step-5-add-google-play-app-signing-sha-1-and-sha-256-to-firebase)
6. [Step 6: Deploy Production Firestore Security Rules](#step-6-deploy-production-firestore-security-rules)
7. [Step 7: Set Billing Budget & Alerts](#step-7-set-billing-budget--alerts)
8. [Step 8: Offline-First Architecture & Fault Resilience (Verification)](#step-8-offline-first-architecture--fault-resilience-verification)

---

## Step 1: Link Play Console & Enable Play Integrity in App Check

Firebase App Check uses the **Play Integrity API** on Android to attest that incoming requests originate from your genuine, unmodified app installed from Google Play.

### 1.1 Link Google Play Console to Google Cloud / Firebase
1. Open the [Firebase Console](https://console.firebase.google.com/) and select the **adhkar365** project.
2. Go to **Project Settings** (gear icon) → **Integrations** tab.
3. Find **Google Play** and click **Link** (or manage if already linked).
4. Select your Google Play Developer Account that owns `com.adhkaar365.app`.

### 1.2 Enable Play Integrity in App Check
1. In the Firebase Console left navigation, select **Build** → **App Check**.
2. Click the **Apps** tab.
3. Find your Android app: `com.adhkaar365.app`.
4. Click **Play Integrity** under the provider column.
5. In the configuration dialog:
   - Ensure the SHA-256 fingerprint matches your Google Play App Signing key (see [Step 5](#step-5-add-google-play-app-signing-sha-1-and-sha-256-to-firebase)).
   - Set **Token Time-to-Live (TTL)** to `1 hour` (default and recommended).
6. Click **Save**.

---

## Step 2: Register Debug Token for Local Development

When running the app locally in debug mode (`flutter run`), the app uses `AndroidDebugProvider()`. It generates a unique debug token so your local development environment does not get blocked by Play Integrity.

### 2.1 Retrieve the Debug Token from Console Logs
1. Run the app on your emulator or physical test device in debug mode:
   ```bash
   flutter run
   ```
2. Inspect the terminal or Android Logcat for a log entry like:
   ```text
   D/FirebaseAppCheck: Enter this debug secret into the allow list in the Firebase Console for your project: XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX
   ```
3. Copy the UUID string token (`XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX`).

### 2.2 Add Debug Token to Firebase Console
1. In the [Firebase Console](https://console.firebase.google.com/), navigate to **App Check** → **Apps**.
2. Click the three dots (`⋮`) next to `com.adhkaar365.app` and select **Manage debug tokens**.
3. Click **Add debug token**.
4. Enter a descriptive name (e.g. `Developer-Workstation-Emulator`) and paste the copied token.
5. Click **Save**.
6. Repeat for any other developer devices as needed.

---

## Step 3: App Check Enforcement Strategy (Safe Rollout)

> ⚠️ **CRITICAL:** Do NOT enforce App Check immediately on day one. Enforcing before users upgrade or before Play Integrity propagates will reject legitimate user requests.

### 3.1 Phase 1: Monitoring Mode (Enforcement OFF)
1. Keep enforcement **OFF** initially.
2. In the Firebase Console, go to **App Check** → **APIs**.
3. Observe the metrics graph over 3 to 7 days after releasing to production.
4. Verify that:
   - **Verified requests** represent > 98-99% of all traffic.
   - Unverified requests correspond only to old builds, emulators without debug tokens, or unauthorized scrapers.

### 3.2 Phase 2: Enforce Cloud Firestore ONLY
1. Once metrics confirm genuine traffic is verified:
   - Go to **App Check** → **APIs** tab.
   - Click on **Cloud Firestore**.
   - Click **Enforce**.
2. **Important Rule:** Do **NOT** enforce App Check on Firebase Authentication or APIs that don't support it in your client workflow. Enforce **strictly for Cloud Firestore**.

---

## Step 4: Restrict Android API Key in Google Cloud Console

Your Firebase Android API key (`AIzaSyBWLKSbVtQ-u5hEr9LXMTL7x0d4MBe5PGg`) should be locked down to prevent quota abuse and unauthorized third-party usage.

### 4.1 Set Application Restrictions
1. Open the [Google Cloud Console Credentials Page](https://console.cloud.google.com/apis/credentials?project=adhkar365).
2. Under **API Keys**, locate the key used by Android (`AIzaSyBWLKSbVtQ-u5hEr9LXMTL7x0d4MBe5PGg` or `Android key (auto created by Firebase)`).
3. Under **Application restrictions**:
   - Select **Android apps**.
4. Click **Add an item** under Android applications:
   - **Package name:** `com.adhkaar365.app`
   - **SHA-1 certificate fingerprint:** Add your **Google Play App Signing SHA-1** (see Step 5).
5. Click **Add an item** again:
   - **Package name:** `com.adhkaar365.app`
   - **SHA-1 certificate fingerprint:** Add your **Upload Keystore SHA-1** (from `android/key.properties`).
6. (Optional for local debug): Add your local debug keystore SHA-1 if debugging against restricted endpoints.

### 4.2 Set API Restrictions (Only Needed APIs)
1. On the same key settings page, scroll down to **API restrictions**.
2. Select **Restrict key**.
3. In the dropdown, select **ONLY** the services Adhkaar 365 utilizes:
   - **Cloud Firestore API**
   - **Identity Toolkit API** (Firebase Auth)
   - **Token Service API** (Firebase Auth Token Refresh)
   - **Play Integrity API**
   - **Firebase App Check API**
4. Click **Save**.

---

## Step 5: Add Google Play App Signing SHA-1 and SHA-256 to Firebase

When Google Play App Signing is enabled, Google re-signs your app with the App Signing Key before distributing it to end users. Both the **Upload Key** and the **Play App Signing Key** must be registered in Firebase for Google Sign-In and Play Integrity to work.

### 5.1 Obtain Play App Signing Fingerprints
1. Open the [Google Play Console](https://play.google.com/console).
2. Select **Adhkaar 365** (`com.adhkaar365.app`).
3. In the left menu, navigate to **Test and release** → **Setup** → **App signing**.
4. Under **App signing key certificate**:
   - Copy the **SHA-1 certificate fingerprint**.
   - Copy the **SHA-256 certificate fingerprint**.
5. Under **Upload key certificate**:
   - Copy the **SHA-1 certificate fingerprint**.
   - Copy the **SHA-256 certificate fingerprint**.

### 5.2 Add Fingerprints to Firebase Console
1. Open the [Firebase Console](https://console.firebase.google.com/) → **Project Settings** → **General** tab.
2. Scroll down to **Your apps** and select `com.adhkaar365.app`.
3. Under **SHA certificate fingerprints**, click **Add fingerprint**:
   - Paste the **App Signing SHA-1** → Save.
   - Paste the **App Signing SHA-256** → Save.
   - Paste the **Upload Key SHA-1** → Save.
   - Paste the **Upload Key SHA-256** → Save.

> 💡 **Why this is critical:**
> - Missing Play App Signing SHA-1 causes Google Sign-In to fail with `ApiException: 10` on Play Store downloads.
> - Missing Play App Signing SHA-256 causes Firebase App Check (Play Integrity) to reject release builds.

---

## Step 6: Deploy Production Firestore Security Rules

Production Firestore rules are located in `firestore.rules` and enforce owner-only access, whitelist data schemas, and block privilege escalation.

### 6.1 Install & Authenticate Firebase CLI
If not already installed on your machine:
```bash
npm install -g firebase-tools
firebase login
```

### 6.2 Target the Project & Deploy Rules
From the repository root (`c:\Users\UNSTOPPABLE\Music\apps\Adhkar365 working\dhikr365`):
```bash
# Verify active project
firebase use adhkar365

# Deploy Firestore rules only
firebase deploy --only firestore:rules
```

### 6.3 Verify in Firebase Console
1. Navigate to [Firebase Console](https://console.firebase.google.com/) → **Firestore Database** → **Rules** tab.
2. Confirm the active rules match `firestore.rules`:
   - Only `users/{userId}` and subcollections `plan`, `progress`, `settings` are accessible by authenticated owners (`request.auth.uid == userId`).
   - All unauthorized collections and wildcards are denied by default (`match /{document=**} { allow read, write: if false; }`).

---

## Step 7: Set Billing Budget & Alerts

Prevent unexpected billing spikes from runaway bots, accidental loops, or high traffic.

1. Open the [Google Cloud Billing Budgets & Alerts Page](https://console.cloud.google.com/billing/budgets?project=adhkar365).
2. Select your Cloud Billing Account.
3. Click **Create Budget**:
   - **Name:** `Adhkaar365-Monthly-Safety-Budget`
   - **Time range:** Monthly
   - **Projects:** Select `adhkar365`
   - **Amount:** Set target amount (e.g., `$5.00` or `$10.00` USD)
4. Under **Actions & Thresholds**:
   - Threshold 1: **50%** of budget (Sends warning email)
   - Threshold 2: **90%** of budget (Sends urgent warning email)
   - Threshold 3: **100%** of budget (Sends alert email)
5. Under **Notifications**:
   - Check **Email alerts to billing account admins and users**.
6. Click **Finish**.

---

## Step 8: Offline-First Architecture & Fault Resilience (Verification)

Adhkaar 365 is designed to be **100% functional offline** and completely immune to cloud outages.

### Code Resilience Verification

| Service / Area | Implementation in Code | Resilience Behavior |
|---|---|---|
| **App Startup (`main.dart`)** | `Firebase.initializeApp()` wrapped in `try-catch` | App launches normally even with no internet or missing Google Services config. |
| **App Check Activation (`main.dart`)** | `FirebaseAppCheck.instance.activate()` wrapped in `try-catch` | Never throws or blocks `runApp()`; seamlessly logs notice and falls back. |
| **Splash Screen (`splash_screen.dart`)** | Storage and provider loaders enforce `.timeout(const Duration(seconds: 5))` | Splash never hangs on an infinite loading spinner. |
| **Dua Plan (`custom_plan_provider.dart`)** | Reads/writes directly to local `SharedPreferences` first; `unawaited(_pushToCloud())` | User can customize plans immediately; cloud sync is fire-and-forget. |
| **Dhikr Tracking (`dhikr_provider.dart`)** | 100% local counts and streaks in `SharedPreferences` | All counters, tasbih, reset logic, and progress work with zero network. |
| **Audio Recitation (`audio_service.dart`)** | Streams bundled local or cached audio; handles errors gracefully | No crashes on failed downloads or offline usage. |
| **Prayer & Notifications (`notification_service.dart`)** | Pure astronomical calculation via Adhan library locally; offline WorkManager | Calculates prayer times and alarms offline without any server API. |
| **Account Auth (`auth_provider.dart`)** | `finally { _isLoading = false; notifyListeners(); }` | Login buttons never get stuck in infinite progress indicators on network failure. |

---

## Verification Checklist

Before submitting your release to Google Play Open Testing or Production:

- [ ] Release AAB built cleanly: `flutter build appbundle --release`
- [ ] SHA-1 and SHA-256 for both Upload and Play Signing keys added to Firebase Console
- [ ] Google Play Console linked under Firebase Integrations
- [ ] Play Integrity provider configured in Firebase App Check
- [ ] App Check enforcement is **OFF** (monitoring mode)
- [ ] Google Cloud API Key restricted to Android (`com.adhkaar365.app`) + required APIs
- [ ] Production rules deployed via `firebase deploy --only firestore:rules`
- [ ] Monthly budget alert configured in Google Cloud Billing
- [ ] App tested on physical device in airplane mode (verifying 100% offline functionality)
