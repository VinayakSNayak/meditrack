# MediTrack – Setup Guide

## Prerequisites
- Flutter SDK ≥ 3.9
- Android Studio / VS Code
- Firebase project configured
- Gemini API key (optional — for AI chatbot)

---

## Step 1: Install Dependencies

```bash
flutter pub get
```

## Step 2: Generate Hive Adapters

The `adherence_log_model.g.dart` file is already generated and included.
If you modify `adherence_log_model.dart`, regenerate with:

```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

## Step 3: Configure Gemini API Key

Edit `assets/config.json`:

```json
{
  "gemini_api_key": "YOUR_ACTUAL_KEY_HERE"
}
```

Get your key from: https://ai.google.dev/

The app works fully without the key — AI chatbot will show a friendly "not configured" message.

## Step 4: Configure Firebase

`google-services.json` is already placed in `android/app/`.
If you need to reconnect to your own Firebase project:
1. Go to Firebase Console → Project Settings
2. Download `google-services.json`
3. Place it in `android/app/`

## Step 5: Deploy Firestore Security Rules

In Firebase Console → Firestore → Rules, paste the contents of `firestore.rules`.

OR using Firebase CLI:
```bash
firebase deploy --only firestore:rules
```

## Step 6: Run the App

```bash
flutter run
```

---

## Architecture Overview

```
lib/
├── main.dart                    # App entry — MultiProvider, Hive, Notifications, Gemini init
├── backend/
│   └── services/
│       ├── auth_service.dart          # Email/Google/Biometric auth
│       ├── firestore_service.dart     # All Firestore operations (per-member)
│       ├── notification_service.dart  # Daily reminders, Taken/Missed/Snooze
│       ├── ocr_service.dart           # ML Kit prescription scanning
│       ├── gemini_service.dart        # RAG-based AI chatbot
│       ├── pdf_service.dart           # Health report PDF generation
│       ├── local_cache_service.dart   # Offline status caching
│       └── sync_service.dart          # Offline → Firestore sync
├── core/
│   ├── errors/app_exception.dart      # Typed exceptions
│   ├── theme/app_theme.dart           # Light + Dark themes
│   └── utils/
│       ├── validators.dart            # Form validators
│       └── context_extensions.dart   # showError / showSuccess helpers
├── models/                            # fromMap/toMap data classes
├── providers/
│   ├── auth_provider.dart             # Auth state management
│   ├── chatbot_provider.dart          # Chat state + RAG context builder
│   └── theme_provider.dart            # Dark mode persistence
└── screens/
    ├── splash/                        # Auth check + notification reschedule
    ├── auth/                          # Login, Signup, Forgot Password
    ├── home/                          # Dashboard-style home + 7-tab nav
    ├── prescription/                  # List, Add, Edit, OCR scan
    ├── reminder/                      # Today's meds with Taken/Missed/Snooze
    ├── health/                        # Body vitals, Blood, Conditions, Other
    ├── dashboard/                     # fl_chart analytics + adherence rate
    ├── chatbot/                       # Gemini AI chat UI
    ├── profile/                       # Family members, settings, language
    └── report/                        # PDF health report + share
```

## Firestore Structure

```
users/{uid}/
  activeMemberId: string
  members/{memberId}/
    name, age, relation, isSelf
    prescriptions/{prescriptionId}/
      medicineName, dosage, foodTiming, time, notificationId, ...
      dailyStatus/{dateId}/
        status: "taken" | "missed" | "snoozed" | "pending"
    bodyVitals/{vitalId}/
      type, value, unit, recordDate
    bloodRecords/{recordId}/
      type, value, unit, recordDate
    conditions/{conditionId}/
      conditionName, status, diagnosedDate, medication, ...
    otherRecords/{recordId}/
      recordName, measurement, recordDate
```

## Key Features

| Feature | Status |
|---------|--------|
| Email/Password Auth | ✅ |
| Google Sign-in | ✅ |
| Biometric (fingerprint/face) | ✅ |
| Family member management | ✅ |
| Per-member Firestore isolation | ✅ |
| OCR prescription scan | ✅ |
| Daily notifications (exact) | ✅ |
| Taken / Missed / Snooze actions | ✅ |
| Offline status caching | ✅ |
| Auto-sync on reconnect | ✅ |
| Reboot notification reschedule | ✅ |
| Dashboard with fl_chart | ✅ |
| RAG AI chatbot (Gemini) | ✅ |
| PDF health report + share | ✅ |
| Dark mode | ✅ |
| English / Hindi / Kannada | ✅ |
| Firestore security rules | ✅ |

