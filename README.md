# My Personal Document Vault — Offline-first App Package

An offline-first, encrypted personal and family document vault application. Protects sensitive documents (Aadhaar, PAN, Passport, Driving Licence, Medical, etc.) locally on device using AES-256-GCM encryption and PBKDF2 key derivation.

## 📦 What's Included in This Package

1. **Standalone Offline Web App (`index.html`)**:
   - Zero external backend required.
   - Run immediately with any local HTTP server (e.g. `python -m http.server 8080`) or host as a PWA / static site.
   - Master PIN setup & unlock with Web Crypto API (`PBKDF2-HMAC-SHA256` + `AES-256-GCM`).
   - Dynamic member management (Add, filter, and delete members; default: *Mine*, *Wife*, *Father*, *Mother*).
   - Document upload (PDF, PNG, JPG, WebP), auto-categorization, search, and in-browser decrypted preview/download.

2. **Flutter Cross-Platform Source Code (`lib/`, `pubspec.yaml`)**:
   - `lib/main.dart`: App theme, Material 3 styling, and initialization.
   - `lib/features/vault/screens/vault_gate.dart`: PIN & biometric unlock gate.
   - `lib/features/vault/screens/vault_screen.dart`: Vault document explorer, search, filter chips, dynamic member manager, and document viewer.
   - `lib/features/vault/services/vault_service.dart`: AES-256-GCM encrypted local storage service.
   - `lib/features/vault/models/vault_document.dart`: Vault document data model.
   - `assets/branding/`: Brand logo assets.

---

## 🚀 How to Run

### Option A: Run the Standalone Web App
No SDK required — just Python or any HTTP server:
```bash
python -m http.server 8080
```
Then open: **http://localhost:8080**

### Option B: Build and Run with Flutter (Android / iOS / Web / Desktop)
1. Install Flutter SDK: https://flutter.dev
2. In this folder, initialize platform runners:
   ```bash
   flutter create .
   flutter pub get
   ```
3. Run on Chrome or connected Android phone:
   ```bash
   flutter run -d chrome
   # or for Android device:
   flutter run
   ```
4. Build release Android APK:
   ```bash
   flutter build apk --release
   ```

---

## 🔒 Security & Privacy
- **100% Offline-First**: No data is uploaded to external clouds or third-party servers.
- **Strong Encryption**: Every document and index is encrypted with AES-256-GCM.
- **PIN Verification**: Salted hash derived with PBKDF2 (120,000 iterations).
