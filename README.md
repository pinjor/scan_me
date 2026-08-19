# ScanMe

Offline CamScanner-style document scanner by **Apptriangle**.

- **Package ID:** `app.atl.scanme`
- Android: Google ML Kit Document Scanner  
- iOS: VisionKit  
- Local-only storage · folders / tags / favorites / trash · converters · print · Apptriangle watermark on exports  

## Docs

- **[Project log (living)](docs/PROJECT_LOG.md)** — status, task history, Play / test / audit (agents update after every task)
- **[UI pages (deep)](docs/UI_PAGES.md)** — every screen, sheet, flow, motion  
- **[iOS App Store](docs/IOS_APP_STORE.md)** — VisionKit, privacy, review notes, upload

## Run

### Fedora (unchanged)

Your existing Flutter, JDK, Android SDK, and gitignored `android/local.properties` stay on that machine. After `git pull`:

```bash
flutter run
```

Do **not** edit Gradle, do **not** run `tool/bootstrap.sh`, do **not** commit `local.properties`.

### Mac (first time)

Flutter must be on PATH (`~/Projects/flutter/bin` is already in `~/.zshrc` — open a new terminal or `source ~/.zshrc`). Then:

```bash
bash tool/bootstrap.sh
flutter run                 # Android
flutter run -d ios          # Xcode
```

`local.properties` is gitignored so Mac paths never overwrite Fedora.

| | Fedora | Mac |
|--|--------|-----|
| What you run | `flutter run` as before | bootstrap once, then `flutter run` |
| Android SDK | whatever you already use | `$HOME/Library/Android/sdk` |
| iOS | skip | Xcode + CocoaPods |

## Release / Play Store

See [Project log → Play Store readiness](docs/PROJECT_LOG.md#play-store-readiness).

```bash
# After android/key.properties is filled:
flutter build appbundle --release
```
