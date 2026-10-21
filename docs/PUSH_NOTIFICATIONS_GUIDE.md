# Adhkar 365 — Custom Push Notifications Guide (FCM)

This guide explains how to send custom push notifications, announcements, reminders, and news to all users of **Adhkar 365** directly from the **Firebase Console**, anytime you want — 100% free with zero Play Store app updates required.

---

## 🚀 Key Features Implemented

1. **Broadcast to All Users:** Send instant or scheduled notifications to every device worldwide.
2. **Language Targeting:** Send notifications to specific language groups (e.g., Bengali only, Arabic only, English only).
3. **Deep Linking:** Tap on the notification can automatically navigate users to a specific screen (Morning Adhkar, Evening Adhkar, Jumu'ah, Protection, etc.).
4. **All App States Supported:** Works when the app is actively open (foreground heads-up banner), minimized (background), or completely closed/terminated.
5. **Always Free:** Powered by Firebase Cloud Messaging (FCM) — unlimited messages with zero cost.

---

## 📲 How to Send a Notification from Firebase Console (Step-by-Step)

### Step 1: Open Firebase Console
1. Open your browser and go to: [https://console.firebase.google.com/](https://console.firebase.google.com/)
2. Select your project: **`adhkar365`** (or your Firebase project name).
3. In the left-hand navigation sidebar, scroll down to **Engage** (or **Build**) and click **Messaging** (Firebase Cloud Messaging).

---

### Step 2: Create a New Campaign
1. Click the **Create your first campaign** button (or **New campaign** ➜ **Firebase Notification messages**).
2. Enter your message content:
   * **Notification title:** e.g., `জুমুআ মোবারক 🕌` (or `Jumu'ah Mubarak`)
   * **Notification text:** e.g., `আজকের দিনে বেশি বেশি দরুদ শরিফ পাঠ করুন এবং সুরা কাহাফ তেলাওয়াত করুন।`
   * *(Optional)* **Notification name:** Internal note for yourself (e.g. `Jumuah Reminder Oct 24`).
3. Click **Next**.

---

### Step 3: Target Your Audience

You have two powerful options:

#### Option A: Send to ALL Users (Recommended for general announcements)
* In the **Target** dropdown:
  * Select **Topic**
  * Type: `all_users`
  * *(Alternative: select the Android app `com.thesunnahrevival.adhkaar365`)*

#### Option B: Target Specific Language (e.g., Bengali only)
* In the **Target** dropdown:
  * Select **Topic**
  * Type: `lang_bn` (for Bengali) or `lang_en` (for English) or `lang_ar` (for Arabic), etc.

---

### Step 4: Scheduling (When to Send)
* Choose **Now** to send immediately.
* Or choose **Scheduled** to pick an exact date and time (e.g. every Friday at 10:00 AM).
* Click **Next**.

---

### Step 5: (Optional) Deep-Linking & Custom Route
If you want tapping the notification to open a specific screen in the app:
1. In the **Additional options** (Optional) step, expand **Custom data**.
2. Add a key-value pair:
   * **Key:** `route`
   * **Value:** One of the following:
     - `morning` ➜ Opens Morning Adhkar screen
     - `evening` ➜ Opens Evening Adhkar screen
     - `sleep` ➜ Opens Before Sleep Adhkar screen
     - `jumuah` or `protection` ➜ Opens Protection Adhkar screen
     - `after_salah` ➜ Opens After Salah Adhkar screen
     - `travel` ➜ Opens Travel Adhkar screen
     - `shifa` ➜ Opens Healing / Shifa Adhkar screen
     - `food` ➜ Opens Food Adhkar screen
     - `parents` ➜ Opens Parents Dua screen
     - `focus` ➜ Opens Focus Adhkar screen

*(If you leave `route` empty, tapping simply opens the app's main Dashboard).*

---

### Step 6: Review and Publish
1. Click **Review**.
2. Double check the title, message, and target.
3. Click **Publish**.

🎉 **Done!** The notification will instantly pop up on all users' phones!
