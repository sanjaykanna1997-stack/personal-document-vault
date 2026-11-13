
# Android setup

1. Install a current stable Flutter SDK and Android Studio.
2. Extract the project and run `flutter create .` once to generate the Android runner folder.
3. Run `flutter pub get`.
4. For `local_auth`, ensure `MainActivity` uses `FlutterFragmentActivity` where required by the plugin setup, and configure biometric permissions / manifest entries according to the installed plugin's Android instructions.
5. Confirm the Android minimum SDK meets the requirements of `local_auth` and the other selected plugins (API 23 or higher is a sensible baseline).
6. Run on a physical Android device to test camera capture, file import, PIN unlock and biometrics.

The app is local-first. No Google Drive or cloud configuration is required.
