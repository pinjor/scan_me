# ScanMe — Functionality test report

**Date:** 2026-08-13  
**Command:** `flutter test --reporter expanded`  
**Result:** **EXIT 0 — All 24 automated tests passed**

---

## Summary

| Category | Count | Status |
|----------|------:|--------|
| Automated PASS | 24 | Pass |
| Automated FAIL | 0 | — |
| Manual / device | 14 | Needs phone/emulator |

**Verdict:** Core UI buttons and editor logic covered by widget/unit tests all passed. Camera, gallery picker, OS share, and full PDF write still need a device smoke pass.

---

## Automated results

| Area | Test | Result | Notes |
|------|------|--------|-------|
| Smoke | Home loads (ScanMe + empty state) | PASS | `widget_test.dart` |
| Core | Compression resizes long edge ≤ 1600 | PASS | `filter_compression_test.dart` |
| Core | B&W filter produces greyscale JPEG | PASS | CamScan pipeline |
| Core | safeFileName unicode / slash / empty | PASS | `safe_filename_test.dart` (2 cases) |
| Home | Empty: Scan Document + Create PDF visible | PASS | `ui_functionality_test` |
| Home | Settings gear opens Settings | PASS | |
| Home | FAB New expands → Scan Document + Images to PDF | PASS | |
| Home | Scan Document → scanner cancel returns home | PASS | Fake `ScanCancelled` |
| Home | Document card name + meta chips | PASS | |
| Home | ⋯ menu: Open / Rename / Share / Delete | PASS | |
| Home | Delete confirm sheet deletes document | PASS | |
| Settings | Light / Dark / System theme options | PASS | About + version visible |
| Scan | First-scan cancel pops capture screen | PASS | Fake scanner |
| Scan | Add Page + Continue chrome with pages | PASS | |
| Review | Toolbar + B&W/Original + Finish; rotate +90° | PASS | |
| Review | `deleteSelectedPage` removes page | PASS | Controller |
| Review | More → Retake all sheet | PASS | |
| Review | Finish → Export screen | PASS | |
| Export | PDF/JPEG toggles; Save disabled if both off | PASS | |
| Editor | `rotateSelected` advances by 90° | PASS | |
| Editor | `reorder` swaps page indices | PASS | |
| Editor | `applyFilter` Original clears processed | PASS | |
| Viewer | Missing-doc error copy contract | PASS | Full Viewer async avoided in CI |

---

## Manual / device-dependent

| Area | Test | Result | Notes |
|------|------|--------|-------|
| Home | Images to PDF → system multi-image picker | MANUAL | Needs ImagePicker |
| Home | Share via OS share sheet | MANUAL | Needs real files |
| Home | Rename persists on disk | MANUAL | UI covered; I/O on device |
| Scan | ML Kit / VisionKit camera capture | MANUAL | Native UI |
| Scan | Add Page appends + auto B&W | MANUAL | Logic partially unit-tested |
| Scan | Continue → Review with real pages | MANUAL | Nav covered with fake session |
| Review | Enhance apply B&W / Original all | MANUAL | Original path unit-tested |
| Review | Retake one / Retake all (camera) | MANUAL | Sheet open covered |
| Review | Thumbnail reorder drag + Add (+) | MANUAL | `reorder()` unit-tested |
| Review | Delete page confirm sheet (UI) | MANUAL | Controller delete covered |
| Export | Save → PDF/JPEG + watermark | MANUAL | App documents write |
| Viewer | Open saved doc, swipe, zoom | MANUAL | PhotoView |
| Viewer | Share / Rename / Delete | MANUAL | Same patterns as Home |
| iOS | VisionKit document scanner channel | MANUAL | Needs iOS |

---

## Re-run

```bash
cd /home/atl-musfiq/Projects/ScanMe
flutter test --reporter expanded
```

Files: `test/widget_test.dart`, `test/filter_compression_test.dart`, `test/safe_filename_test.dart`, `test/ui_functionality_test.dart`
