# ScanMe — Functionality test report

**Date:** 2026-08-13  
**Device:** Xiaomi **24069RA21C** (`11ab4ce6`) · Android 16 (API 36) · USB  
**Host commands:** `flutter test` · `flutter run -d 11ab4ce6` · `adb` UI dump / screencap  
**Automated result:** **38/38 PASS**  
**Device smoke result:** **PASS** (no crash; key flows opened; scanner + gallery launched)

Screenshots: [`docs/device_shots/`](device_shots/)

---

## Summary

| Layer | Count / status |
|-------|----------------|
| Automated PASS | **38** |
| Automated FAIL | **0** |
| Line coverage | **46.2%** (`flutter test --coverage`) |
| Device smoke | **PASS** on `24069RA21C` |
| Not fully exercised on device | Full save PDF, Viewer with real doc, Print/Share, PDF→TXT / PPTX |

**Verdict:** App installs and runs on the connected phone. Home, Settings, FAB, Converters, Trash, folder chips, system gallery (Images to PDF), and **Google ML Kit Document Scanner** all opened successfully. Cancel paths return to Home. No Flutter FATAL in logcat during smoke.

---

## Device smoke (2026-08-13)

| # | Check | Result | Evidence |
|---|-------|--------|----------|
| 1 | Debug install + launch (`flutter run -d 11ab4ce6`) | **PASS** | App foreground; empty Home |
| 2 | Home chrome (Search, chips, empty CTAs, FAB) | **PASS** | `01_home.png` |
| 3 | Settings · Appearance System/Light/Dark · Trash auto-delete · About | **PASS** | `02_settings.png`, `03_settings_light.png` |
| 4 | Theme Light tap returns stable Home | **PASS** | `04_home_again.png` |
| 5 | FAB opens Scan / Images to PDF / Converters | **PASS** | `05_fab_open.png` |
| 6 | Converters hub tiles | **PASS** | `06_converters.png` — PDF→Text, PowerPoint→PDF, PNG→JPG, JPG→PNG |
| 7 | Trash empty + Back to library | **PASS** | `07_trash.png` |
| 8 | Folders chip expands seed folders | **PASS** | `08_folders.png` — Work, Personal, Receipts, IDs, Certificates, Finance |
| 9 | Favorites filter (empty library) | **PASS** | `09_favorites.png` |
| 10 | Images to PDF → system photo picker | **PASS** | `10_images_picker.png` — Cancel closes |
| 11 | Scan Document → ML Kit scanner UI | **PASS** | `11_scan.png` — Capture / Manual / Auto / Flash / gallery import |
| 12 | Cancel scanner → Home | **PASS** | `12_after_scan_cancel.png` |
| 13 | Crash / FATAL for `app.atl.scanme` | **PASS** | None observed in filtered logcat |

### Device not fully walked (needs real capture / files)

| Check | Status | Why |
|-------|--------|-----|
| Capture page → Review → Enhance → Export → Save PDF | **NOT RUN** | Would need live document capture |
| Viewer open / Print / Share / Tags / Activity | **NOT RUN** | No saved docs on device library |
| Converters pick PDF/PPTX + Share | **NOT RUN** | File picker not driven end-to-end |
| Images→PDF full import + Review | **PARTIAL** | Picker opened; no image selected |
| Trash restore / delete forever | **NOT RUN** | Trash empty |

---

## Automated results (CI / host)

**Command:** `flutter test --reporter expanded` → **38 passed**

### Suites

| File | Tests | Status |
|------|------:|--------|
| `test/widget_test.dart` | 1 | PASS |
| `test/filter_compression_test.dart` | 2 | PASS |
| `test/safe_filename_test.dart` | 2 | PASS |
| `test/converter_test.dart` | 2 | PASS |
| `test/library_query_test.dart` | 8 | PASS |
| `test/ui_functionality_test.dart` | 23 | PASS |

### Feature matrix (combined)

| Feature | Automated | Device | Notes |
|---------|-----------|--------|-------|
| Home empty / CTAs / FAB | PASS | PASS | |
| Settings theme + About | PASS | PASS | Light applied on device |
| Favorites / Search / Trash filters | PASS | PASS | Search unit+widget; Trash UI on device |
| Folders seed list | Unit query | PASS | Chips show on device |
| Scan capture cancel / chrome | PASS (fake) | PASS (ML Kit) | Real GmsDocumentScanningDelegateActivity |
| Images to PDF picker | — | PASS open/cancel | |
| Review / Export UI | PASS | NOT RUN | Needs pages |
| PNG↔JPG convert | PASS | Hub UI PASS | File pick not run |
| PDF/PPTX convert | — | Hub UI PASS | Convert I/O not run |
| Viewer / Print / Share | Thin | NOT RUN | |

---

## Re-run

```bash
# Host
cd /home/atl-musfiq/Projects/ScanMe
flutter test --reporter expanded

# Device (phone connected)
flutter devices
flutter run -d 11ab4ce6   # or: flutter run -d $(adb get-serialno)
```

**Related:** [UI_PAGES.md](UI_PAGES.md) · screenshots in [device_shots/](device_shots/)
