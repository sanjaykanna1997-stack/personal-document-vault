# SANJ AI architecture

## Branding
- Supplied logo: `assets/branding/sanj_ai_logo.png`
- Deep navy: `#071536`
- Secondary navy: `#0D2148`
- Teal: `#009B83`
- Teal highlight: `#16B99B`
- White / mist background: `#FFFFFF` / `#F4F7FA`

## Local-first structure
- `lib/main.dart`: app theme and entry point.
- `lib/app_shell.dart`: bottom navigation, dashboard, assistant UI, local tasks, and module entry points.
- `lib/features/vault/`: PIN gate, vault UI, encrypted local vault service and document model.
- `assets/branding/`: supplied brand logo.

## Storage
- Family documents and encrypted document index: app-private support directory.
- Vault encryption: AES-256-GCM.
- PIN verifier: PBKDF2-HMAC-SHA256.
- Secrets: `flutter_secure_storage`.
- Tasks: local key-value persistence via `shared_preferences`.
- No network or cloud sync is included.

## Next development milestones
1. Replace placeholder Planner, Reminder, Goal and Notes pages with persisted CRUD modules.
2. Add local notification scheduling and recurrence handling.
3. Add encrypted local backup / restore with user-controlled export.
4. Add on-device OCR and document expiry extraction.
5. Integrate a small on-device language model for genuine offline assistant reasoning.
6. Add offline speech recognition and text-to-speech.
7. Add secure in-app document viewing, key lifecycle hardening and security testing.
