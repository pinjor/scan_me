# ScanMe

Offline CamScanner-style document scanner for Android and iOS.

## Features

- Multi-page scan (ML Kit Document Scanner on Android, VisionKit on iOS)
- Review: zoom/pan, reorder, retake, rotate, delete
- CamScanner-style Black & White filter (SLI proposal-form pipeline)
- Export compressed PDF and/or JPEG images (long edge ≤ 1600, quality 82)
- Local-only storage, light/dark/system theme

## Run

```bash
flutter pub get
flutter run
```

Android emulator/device required for ML Kit scanner. iOS device/simulator for VisionKit.
