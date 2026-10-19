# Adhkaar 365 — Over-The-Air (OTA) Dua Corrections Guide

This guide explains how to instantly correct any typo, Arabic harakat, translation, transliteration, or reference in any Dhikr or Dua in **Adhkaar 365** directly from **Firebase Console**, without releasing a new app update to the Google Play Store.

---

## How It Works

1. **100% Offline-First:** The app continues to load all default duas from bundled asset files instantly.
2. **Instant Hot Patch:** When the app opens, it checks local cache for any previously downloaded corrections.
3. **Background Sync:** Once every 12 hours (when internet is available), the app silently checks Firestore collection `dua_corrections`.
4. If a correction exists for a Dua ID, it updates the text seamlessly on the user's screen.
5. **Zero Font Degradation:** Fonts (like Amiri for Arabic and Manrope for translations) are applied by the UI typography system, so harakat (হরকত), diacritics, and ligatures render in crisp, authentic calligraphy.

---

## Step-by-Step: How to Correct a Dua in Firebase Console

### Step 1: Open Firebase Console
1. Go to [https://console.firebase.google.com/](https://console.firebase.google.com/)
2. Open your project: **`adhkar365`**
3. In the left menu under **Build**, click **Firestore Database**.

### Step 2: Open the `dua_corrections` Collection
1. Click **Start collection** (or click into `dua_corrections` if already created).
2. Collection ID: `dua_corrections`
3. Click **Next**.

### Step 3: Add a Correction for a Specific Dua
* **Document ID:** Enter the exact ID of the dua you want to correct (e.g. `morning_1`, `morning_ayat_al_kursi`, `evening_3`, `food_bismillah`, `parents_rabbir_hamhuma`, `protection_la_ilaha_illa_allah_wahdahu`, etc.).
* Add any of the following fields you wish to correct:

| Field Name | Type | Example / Value | Description |
|---|---|---|---|
| `arabicText` | string | `اللَّهُمَّ بِكَ أَصْبَحْنَا...` | Corrected Arabic text (with full harakat) |
| `translation_bn` | string | `হে আল্লাহ! আপনার অনুগ্রহেই আমরা সকাল করেছি...` | Corrected Bengali translation |
| `translation_en` | string | `O Allah, by You we enter the morning...` | Corrected English translation |
| `translation` | string | `...` | Generic fallback translation (all languages) |
| `transliteration` | string | `Allahumma bika asbahna...` | Corrected transliteration |
| `reference` | string | `Abu Dawud: 5068, Sahih` | Corrected Hadith / Qur'an reference |
| `benefit` | string | `Recite once in the morning...` | Corrected virtues / benefit notes |

> **Note:** You only need to add the fields you want to change! For example, if only the Bengali translation has a typo, just add the `translation_bn` field. The original Arabic, audio, and all other fields remain completely intact.

### Step 4: Click Save
That's it! As soon as users open the app with internet, the correction is automatically applied to their screen.
