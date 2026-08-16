# ScanMe

Offline CamScanner-style document scanner by **Apptriangle**.

- **Package ID:** `app.atl.scanme`
- Android: Google ML Kit Document Scanner  
- iOS: VisionKit  
- Local-only storage · folders / tags / favorites / trash · converters · print · Apptriangle watermark on exports  

## Docs

- **[Project log (living)](docs/PROJECT_LOG.md)** — status, task history, Play / test / audit (agents update after every task)
- **[UI pages (deep)](docs/UI_PAGES.md)** — every screen, sheet, flow, motion  

## Run

```bash
flutter pub get
flutter run
```

## Release / Play Store

See [Project log → Play Store readiness](docs/PROJECT_LOG.md#play-store-readiness).

```bash
# After android/key.properties is filled:
flutter build appbundle --release
```
