# Adhkar 365 (أذكار ٣٦٥)

[![Flutter](https://img.shields.io/badge/Flutter-3.24%2B-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.4%2B-0175C2?logo=dart&logoColor=white)](https://dart.dev)
[![Target Android](https://img.shields.io/badge/TargetSdk-36%20(Android%2016)-3DDC84?logo=android&logoColor=white)](https://developer.android.com)
[![iOS](https://img.shields.io/badge/iOS-14.0%2B-black?logo=apple&logoColor=white)](https://www.apple.com/ios/)
[![License](https://img.shields.io/badge/License-Proprietary-blue.svg)](#license)

**Adhkar 365** is a modern, privacy-first, and distraction-free daily Islamic companion designed to help Muslims cultivate consistent spiritual remembrance (*dhikr*) and stay connected with their daily prayers.

Built with Flutter, Adhkar 365 combines authentic prophetic supplications from *Hisn al-Muslim* (Fortress of the Muslim) with precise prayer timings, haptic Qibla compass navigation, high-quality audio recitations, and reflective habit tracking.

---

## 🌟 Key Features

### 📖 1. Authentic Adhkar & Duas
- **120+ Prophetic Supplications:** Categorized into Morning & Evening (*Sabah & Masaa*), After Obligatory Prayers, Before Sleep, Waking Up, Food & Dining, Travel, Parents, Seeking Forgiveness (*Istighfar*), Anxiety & Distress, and Healing & Ruqyah.
- **Accurate References:** Includes Arabic text with full tashkeel/diacritics, clear translations, transliterations, authentic Hadith references, and spiritual virtues (*Fada'il*).
- **Custom Dua Plan:** Personalize your daily routine by bookmarking specific adhkar or toggling your preferred daily sets.

### 🕌 2. High-Precision Prayer Times
- **Global Prayer Calculations:** Powered by the astronomical Adhan calculation engine supporting all major methods:
  - Muslim World League (MWL)
  - Islamic Society of North America (ISNA)
  - Umm al-Qura University, Makkah
  - Egyptian General Authority of Survey
  - University of Islamic Sciences, Karachi
  - Dubai, Kuwait, Qatar, Singapore, and Moonsighting Committee methods
- **Juristic Settings:** Hanafi and Shafi'i/Maliki/Hanbali Asr calculation modes.
- **Dynamic Prayer Countdown:** Real-time countdown timer to the upcoming prayer with automated Fajr, Dhuhr, Asr, Maghrib, and Isha scheduling.

### 🧭 3. Interactive Qibla Compass
- **Haptic Alignment Feedback:** Real-time sensor fusion combining device accelerometer and magnetometer to point directly toward the Holy Kaaba in Makkah.
- **Calibration Assistant:** Automatic visual indicators for magnetic sensor accuracy and calibration warnings.

### 🎧 4. Audio Recitations
- **Beautiful Voice Recitations:** Clear, meditative Arabic audio recitations for all essential morning, evening, and daily adhkar.
- **Offline Caching:** Streams smoothly and caches locally for reliable offline recitation.
- **Playback Controls:** Auto-advance, repeat single dhikr, background audio session management, and wake lock support.

### 📊 5. Habit Tracking & Contemplative Mode
- **Daily Streaks & Milestones:** Track consistent days of remembrance with milestone haptic feedback (vibrations at 33, 66, 99, 100, and target completion).
- **Contemplative Mode (*Huḍūr*):** Easily hide numerical counters and progress rings to remove distractions and focus entirely on presence of the heart and sincere contemplation.
- **Monthly Heatmap:** Visual activity calendar illustrating daily completion consistency.

### 🌍 6. 19 Supported Languages
Adhkar 365 is fully internationalized across 19 languages:
- **Arabic** (العربية)
- **Bengali** (বাংলা)
- **English** (English)
- **French** (Français)
- **German** (Deutsch)
- **Spanish** (Español)
- **Hindi** (हिन्दी)
- **Indonesian** (Bahasa Indonesia)
- **Italian** (Italiano)
- **Japanese** (日本語)
- **Malay** (Bahasa Melayu)
- **Dutch** (Nederlands)
- **Portuguese** (Português)
- **Russian** (Русский)
- **Tamil** (தமிழ்)
- **Thai** (ไทย)
- **Turkish** (Türkçe)
- **Urdu** (اردو)
- **Chinese** (中文)

---

## 🔒 Privacy & Security Architecture

1. **100% Offline-First by Default:**
   All core functionality—including daily adhkar, counter state, tasbeeh, and prayer schedules—works completely offline. No account creation is required to use the app.

2. **Optional Cloud Backup (Firebase):**
   Users may optionally sign in with **Google** or **Sign in with Apple** to preserve streaks and custom plans across devices.
   - **Cloud Firestore Security Rules:** Protected by strict owner-only validation rules (`request.auth.uid == userId`) with field whitelisting and payload size limits to prevent oversized data injection.

3. **Data Safety & Minimal Permissions:**
   - **Location:** Used solely on-device to calculate solar angles for prayer times and Qibla direction. Location coordinates are never sold, tracked, or stored externally.
   - **Notifications:** Used strictly for prayer time alerts and adhkar reminders.
   - **Exact Alarms (`SCHEDULE_EXACT_ALARM`):** Used only to fire timely adhan notifications at exact solar prayer times.

4. **Production Code Hardening:**
   - **R8 Minification & Dead Code Elimination:** Enabled for all release builds.
   - **ProGuard Protection:** Proprietary class obfuscation rules configured in `android/app/proguard-rules.pro`.
   - **Google Play App Signing:** Keystore protected; release builds signed with Google Play App Signing key.

---

## 🛠️ Architecture & Tech Stack

```
lib/
├── models/         # Dhikr, Category, PrayerTime, and User models
├── providers/      # ChangeNotifier providers (Dhikr, Audio, Prayer, Theme, Purchase, Auth, CustomPlan)
├── screens/        # UI Screens (Home, DhikrList, Counter, PrayerTimes, Qibla, Settings, Analytics)
├── services/       # Core services (AudioService, NotificationService, PrayerService, AuthService)
├── widgets/        # Reusable UI components (TasbeehCounter, PrayerCard, AudioBar, Sheets)
├── l10n/           # Localization delegates and translation helpers
└── main.dart       # Application bootstrap, theme configuration, and provider tree
```

- **Framework:** [Flutter](https://flutter.dev) (v3.24+)
- **Language:** [Dart](https://dart.dev) (v3.4+)
- **State Management:** [`provider`](https://pub.dev/packages/provider)
- **Prayer Calculations:** [`adhan`](https://pub.dev/packages/adhan)
- **Audio Engine:** [`audioplayers`](https://pub.dev/packages/audioplayers) & [`just_audio`](https://pub.dev/packages/just_audio)
- **Notifications:** [`flutter_local_notifications`](https://pub.dev/packages/flutter_local_notifications)
- **In-App Billing:** [`in_app_purchase`](https://pub.dev/packages/in_app_purchase)
- **Storage:** [`shared_preferences`](https://pub.dev/packages/shared_preferences) & [`cloud_firestore`](https://pub.dev/packages/cloud_firestore)

---

## 🚀 Getting Started

### Prerequisites
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (>= 3.24.0)
- [Android Studio](https://developer.android.com/studio) / [VS Code](https://code.visualstudio.com/)
- JDK 17
- Android SDK Platform 36 (targetSdk 36)

### Installation

1. **Clone the repository:**
   ```bash
   git clone https://github.com/abdullahalmasum365/adhkar-app-with-glow-.git
   cd adhkar-app-with-glow-
   ```

2. **Install dependencies:**
   ```bash
   flutter pub get
   ```

3. **Configure Firebase (Optional for Cloud Sync):**
   - Place your `google-services.json` inside `android/app/`.
   - Place your `GoogleService-Info.plist` inside `ios/Runner/`.

4. **Run tests:**
   ```bash
   flutter test
   ```

5. **Run the app in debug mode:**
   ```bash
   flutter run
   ```

### Building for Release

To generate an optimized, obfuscated release Android App Bundle (AAB):

```bash
flutter build appbundle --release
```

---

## 📜 Medical & Spiritual Disclaimer

Supplications and verses categorized under "Healing (*Shifa*)" and "Anxiety & Distress" are authentic Quranic and Prophetic prayers intended for spiritual comfort and solace. They are **not** a substitute for professional medical advice, psychiatric diagnosis, or clinical healthcare treatment. Always consult qualified healthcare professionals for medical conditions.

---

## 🤲 Sources & Attributions

- **Hisn al-Muslim (حصن المسلم):** Supplications curated from the authentic compilations by Sheikh Sa'id bin Ali bin Wahf Al-Qahtani (رحمه الله).
- **Audio Recitations:** Hisn al-Muslim supplications and Qur'anic verses are freely accessible to all users for educational and devotional purposes.
- **Geocoding & Location:** Reverse geocoding for city names is handled via native platform location services (Google Play Services / iOS CoreLocation). City search and geographic data supported by GeoNames (geonames.org) and © OpenStreetMap contributors.

---

## 📄 License

Copyright © 2024–2026 Abdullah Al Masum. All rights reserved.
Code and assets are proprietary. Built for the Muslim Ummah with sincerity and dedication.
