# 🩺 MediTrack

### One App to Remember, Record & Revive

![Flutter](https://img.shields.io/badge/Flutter-3.x-blue?logo=flutter)
![Firebase](https://img.shields.io/badge/Firebase-Backend-orange?logo=firebase)
![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20iOS-green)
![Status](https://img.shields.io/badge/Status-Active-success)

---

## 🚀 Overview

**MediTrack** is a smart healthcare mobile application that helps users manage **medications, prescriptions, and health records** in one place.

Built using **Flutter + Firebase + AI**, it ensures secure, reliable, and intelligent healthcare tracking.

---

## ✨ Features

### 💊 Smart Medicine Reminder

* Offline notifications
* Snooze & Mark-as-Taken
* Ensures no missed doses

### 📄 OCR Prescription Scanner

* Scan prescriptions using Google ML Kit
* Auto-extract medicine details

### 📊 Health Dashboard

* Track medicine adherence (taken vs missed doses)
* Visual charts using `fl_chart`

### 👨‍👩‍👧 Family Management

* Multiple profiles in one account

### 🔐 Security

* Firebase Authentication  
- Secure cloud storage with Firestore rules 

### 🌐 Multilingual

* English, Hindi, Kannada

### 🤖 AI-Powered Assistant  
- Provides health-related assistance  
- Uses GPT-4o-mini via GitHub Models API  
- Enhances user interaction 

### 📄 PDF Reports

* Generate and share reports

---

## 🛠️ Tech Stack

* **Flutter**
* **Firebase (Firestore, Auth, Storage)**
* **Google ML Kit (OCR)**
* **flutter_local_notifications**
* **fl_chart**
* **AI: GitHub Models API (GPT-4o-mini)**

---

## 📂 Project Structure

```
lib/
 ├── screens/
 ├── services/
 ├── models/
 ├── widgets/
 └── main.dart
```

---

## ⚙️ Setup

### Clone repo

```
git clone https://github.com/your-username/meditrack.git
cd meditrack
```

### Install dependencies

```
flutter pub get
```

### Firebase setup

* Add `google-services.json` → `android/app/`
* Enable Auth, Firestore, Storage

### Add API key

Create `.env`

```
GITHUB_TOKEN=your_api_key_here
```

---

## 🔐 Security

* API keys are not stored in repo
* Firestore rules protect user data

---

## 📱 Screenshots

<img width="394" height="883" alt="Screenshot 2026-04-07 003203" src="https://github.com/user-attachments/assets/e264a609-69df-4ea1-aa50-39f54d3cf56b" />


---

## 🎯 Highlights

* Full-stack Flutter app
* AI-powered healthcare assistant
* Offline-first reminders
* Secure & scalable

---

## 👨‍💻 Authors

* Vinayak Shantha Nayak
* Vijay Ramesh Kai
* Varun V
* Umesh

---

## ⭐ Support

If you like this project, give it a ⭐
