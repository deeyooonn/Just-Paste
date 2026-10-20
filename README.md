# Just Paste ⚡

> **Transform raw text, camera snaps, and documents into comprehensive study flashcards in seconds using Gemini AI.**

[![GitHub Repo](https://img.shields.io/badge/GitHub-Just--Paste-181717?style=for-the-badge&logo=github&logoColor=white)](https://github.com/deeyooonn/Just-Paste)
[![Flutter](https://img.shields.io/badge/Flutter-3.44+-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.12+-0175C2?style=for-the-badge&logo=dart&logoColor=white)](https://dart.dev)
[![Gemini API](https://img.shields.io/badge/Google_Gemini-API-8E75B2?style=for-the-badge&logo=google&logoColor=white)](https://ai.google.dev/)
[![Firebase](https://img.shields.io/badge/Firebase-Core%2FAuth%2FFirestore-FFCA28?style=for-the-badge&logo=firebase&logoColor=black)](https://firebase.google.com/)

---

## 📖 Overview

**Just Paste** is an intelligent, cross-platform study assistant built with **Flutter & Dart** and hosted at [https://github.com/deeyooonn/Just-Paste](https://github.com/deeyooonn/Just-Paste). It empowers students, educators, and lifelong learners to effortlessly convert unorganized study material—including camera photos, clipboard text, PDFs, DOCX, and images—into structured, interactive flashcard decks.

Powered by **Google Gemini AI** and **Firebase Cloud Firestore**, Just Paste delivers instant AI synthesis, real-time cross-device cloud sync, interactive flip decks, search/filter capabilities, and bookmarking.

---

## ✨ Key Features

- **⚡ Multi-Format Input Engine**:
  - **📋 Clipboard Paste**: One-tap text processing from any source.
  - **📸 Optic Camera Capture**: Snap photos of textbooks, whiteboards, or screens.
  - **📂 Multi-Doc Upload**: Natively process PDFs, PNG, JPG, WEBP, DOCX, and TXT files (up to 10MB).
- **🎴 Instant AI Flashcards**:
  - Automatically synthesizes study material into high-yield, comprehensive Q&A flashcards.
  - Focused flashcards with a gentle answer reveal and a browsable grid.
  - Dual View Modes: **Grid View** (compact multi-card layout) & **Single Focus View** (enlarged single-card focus with `1 / N` counter).
- **☁️ Cloud Sync & Saved Library**:
  - Real-time synchronization via **Firebase Cloud Firestore**.
  - **⭐ Star/Bookmarking System**: Filter saved decks by favorites.
  - **🔍 Search & Local Filter**: Search across document titles and card questions/answers.
- **🎨 Dark Mode First Design**:
  - Deep ink `#101017`, muted violet accents, warm ivory typography, and subtle celestial artwork. Bundled Inter and Cormorant Garamond fonts work offline.
- **🛡️ Secure & Resilient**:
  - Google login is required for new and anonymous users. Returning authenticated users retain their session; signing out clears protected navigation.
  - Built-in file size validation (10MB maximum limit).
  - Truncation repair algorithm to salvage incomplete AI responses cleanly.

---

## 🛠️ Tech Stack & Architecture

| Layer | Technology |
| :--- | :--- |
| **Repository** | [https://github.com/deeyooonn/Just-Paste](https://github.com/deeyooonn/Just-Paste) |
| **Frontend Framework** | [Flutter 3.44+](https://flutter.dev) (Dart 3.12+) |
| **Design System** | Material 3, bundled Inter / Cormorant Garamond, celestial vector artwork |
| **AI Processing Engine** | [Google Gemini API](https://ai.google.dev/) (`google_generative_ai` REST SDK) |
| **Authentication** | [Firebase Auth](https://firebase.google.com) (Google Sign-In) |
| **Database** | [Cloud Firestore](https://firebase.google.com/docs/firestore) (Real-time NoSQL Sync) |
| **State & Environment** | `flutter_dotenv` for secure environment variable injection |

---

## 📁 Project Structure (`lib/`)

```text
lib/
├── firebase_options.dart         # Auto-generated Firebase platform configuration
├── gemini_flashcard_service.dart # Isolated AI processing engine, JSON repair & DOCX parser
├── main.dart                     # Auth routing, data models, library, results & service calls
└── ui/
    ├── nocturne_theme.dart       # Shared palette, bundled typefaces & celestial artwork
    ├── login_screen.dart         # Google sign-in, loading & recovery states
    └── dashboard_view.dart       # Notes editor, clipboard, camera & file import
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

## Interface and authentication checks

The native Flutter interface uses `lib/ui/nocturne_theme.dart`,
`lib/ui/login_screen.dart`, and `lib/ui/dashboard_view.dart`. Google is the
existing sign-in provider; cancelled or failed sign-in attempts remain on login.
Previously cached anonymous sessions also see login.

Run `flutter analyze` and `flutter test` to check routing, sign-in loading/error
states, protected route cleanup, note input, library filters, flashcard
interaction, and narrow layouts at normal and doubled text sizes. To generate
local screen previews with sample data, run:

```sh
flutter test --dart-define=CAPTURE_UI_PREVIEWS=true
```

Previews are written to `build/ui-previews/`. The tests do not sign into a real
Google account or make Firestore/Gemini requests. Those services require the
project's existing Firebase and API configuration.
