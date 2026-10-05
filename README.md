# Just Paste ⚡

> **Transform raw text, camera snaps, and documents into comprehensive study flashcards in seconds using Gemini AI.**

[![GitHub Repo](https://img.shields.io/badge/GitHub-Just--Paste-181717?style=for-the-badge&logo=github&logoColor=white)](https://github.com/deeyooonn/Just-Paste)
[![Flutter](https://img.shields.io/badge/Flutter-3.44+-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.12+-0175C2?style=for-the-badge&logo=dart&logoColor=white)](https://dart.dev)
[![Gemini API](https://img.shields.io/badge/Google_Gemini-API-8E75B2?style=for-the-badge&logo=google&logoColor=white)](https://ai.google.dev/)
[![Firebase](https://img.shields.io/badge/Firebase-Core%2FAuth%2FFirestore-FFCA28?style=for-the-badge&logo=firebase&logoColor=black)](https://firebase.google.com/)

---

## 📖 Overview

**Just Paste** is an intelligent, cross-platform study assistant built with **Flutter & Dart** and hosted at [https://github.com/deeyooonn/Just-Paste](https://github.com/deeyooonn/Just-Paste). It empowers students, educators, and lifelong learners to effortlessly convert unorganized study material—including camera photos, clipboard text, PDFs, DOCX, and images—into structured, interactive 3D flashcard decks.

Powered by **Google Gemini AI** and **Firebase Cloud Firestore**, Just Paste delivers instant AI synthesis, real-time cross-device cloud sync, interactive flip decks, search/filter capabilities, and bookmarking.

---

## ✨ Key Features

- **⚡ Multi-Format Input Engine**:
  - **📋 Clipboard Paste**: One-tap text processing from any source.
  - **📸 Optic Camera Capture**: Snap photos of textbooks, whiteboards, or screens.
  - **📂 Multi-Doc Upload**: Natively process PDFs, PNG, JPG, WEBP, DOCX, and TXT files (up to 10MB).
- **🎴 Instant AI Flashcards**:
  - Automatically synthesizes study material into high-yield, comprehensive Q&A flashcards.
  - Interactive **3D Flip Card Animation** with smooth 180-degree rotation.
  - Dual View Modes: **Grid View** (compact multi-card layout) & **Single Focus View** (enlarged single-card focus with `1 / N` counter).
- **☁️ Cloud Sync & Saved Library**:
  - Real-time synchronization via **Firebase Cloud Firestore**.
  - **⭐ Star/Bookmarking System**: Filter saved decks by favorites.
  - **🔍 Search & Local Filter**: Search across document titles and card questions/answers.
- **🎨 Dark Mode First Design**:
  - Custom dark slate `#0D1117` aesthetic with glowing cyan accents (`#00E5FF`) and subtle circuit background patterns.
- **🛡️ Secure & Resilient**:
  - Offline/Anonymous guest authentication fallback.
  - Built-in file size validation (10MB maximum limit).
  - Truncation repair algorithm to salvage incomplete AI responses cleanly.

---

## 🛠️ Tech Stack & Architecture

| Layer | Technology |
| :--- | :--- |
| **Repository** | [https://github.com/deeyooonn/Just-Paste](https://github.com/deeyooonn/Just-Paste) |
| **Frontend Framework** | [Flutter 3.44+](https://flutter.dev) (Dart 3.12+) |
| **Design System** | Material 3, Google Fonts (`Inter`), Custom Circuit Canvas Painter |
| **AI Processing Engine** | [Google Gemini API](https://ai.google.dev/) (`google_generative_ai` REST SDK) |
| **Authentication** | [Firebase Auth](https://firebase.google.com) (Google Sign-In & Anonymous Guest Auth) |
| **Database** | [Cloud Firestore](https://firebase.google.com/docs/firestore) (Real-time NoSQL Sync) |
| **State & Environment** | `flutter_dotenv` for secure environment variable injection |

---

## 📁 Project Structure (`lib/`)

```text
lib/
├── firebase_options.dart         # Auto-generated Firebase platform configuration
├── gemini_flashcard_service.dart # Isolated AI processing engine, JSON repair & DOCX parser
└── main.dart                     # Entry point, Theme System, AuthGate, Dashboard & Results UI
    ├── CleanDarkTheme            # Custom slate dark mode color system
    ├── CircuitPatternPainter     # Custom canvas background painter
    ├── ProcessedDocument         # Firestore document model
    ├── AuthGate                  # Real-time authentication listener & auto-guest router
    ├── MainDashboardScreen       # Document upload, camera, & dropzone interface
    ├── ProfileScreen             # User profile, cloud stats, search bar, & saved library
    └── ResultsScreen             # Interactive 3D flip card deck & Cloud Save action
```

---

## 🚀 Local Setup & Installation

### Prerequisites
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (v3.44.0 or higher)
- [Android Studio](https://developer.android.com/studio) or VS Code with Flutter extension
- [Google AI Studio API Key](https://aistudio.google.com/)
- Connected Android Device or Emulator (API Level 21+) / Google Chrome

### Step-by-Step Instructions

#### 1. Clone the Repository
```bash
git clone https://github.com/deeyooonn/Just-Paste.git
cd Just-Paste
```

#### 2. Install Dependencies
```bash
flutter pub get
```

#### 3. Environment Configuration (`.env`)
Create a `.env` file in the root directory of the project:

```bash
touch .env
```

Add your credentials to `.env`:
```env
GEMINI_API_KEY=AIzaSyYourActualGeminiApiKeyHere
GOOGLE_CLIENT_ID=your_google_client_id.apps.googleusercontent.com
```

#### 4. Run on Android Emulator
```bash
flutter run -d emulator-5554
```

#### 5. Run on Web (Port 3000)
To avoid Google Sign-In origin mismatch errors on web, launch Chrome on port `3000`:
```bash
flutter run -d chrome --web-port 3000
```

---

## 🔒 Security & Best Practices

> ⚠️ **IMPORTANT SECURITY NOTICE**:
> - Never commit your `.env` file or hardcode API keys into version control.
> - The `.env` file is explicitly listed in `.gitignore` to prevent secret leaks.
> - For production mobile releases, restrict your **Gemini API Key** inside [Google AI Studio](https://aistudio.google.com/) to your app's SHA-1 fingerprint and package name (`com.example.justpaste`).

---

## 📄 License

Distributed under the MIT License. See `LICENSE` for details.
