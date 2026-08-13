# ScanMe — Full App Flow & Functionality Audit

**Date:** 2026-08-12  
**Project:** `/home/atl-musfiq/Projects/ScanMe`  
**Scope:** End-to-end user flows, Dart/native bridges, persistence, export, UI edge cases  
**Method:** Static code review of all 15 `lib/` Dart files + iOS/Android native wiring + `flutter analyze` + `flutter test`

---

## Executive summary

Core product flow is **architecturally complete** (scan → review → enhance → export → recent list → viewer). Unit/widget tests pass and the analyzer is clean.

However, several **runtime bugs** can break or degrade real use — especially on **iOS** (scanner channel registration) and **editor session lifecycle** (`autoDispose`). Abandoned scans also **leak disk** under `documents/`.

| Severity | Count |
|----------|------:|
| Critical | 2 |
| High | 4 |
| Medium | 11 |
| Low | 7 |
| **Total findings** | **24** |

**Automated checks**

| Check | Result |
|-------|--------|
| `flutter analyze` | No issues found |
| `flutter test` (3 tests) | All passed |
| Scan / export / viewer E2E on device | **Not run** (no device in this audit) |

---

## Intended user flow (reference)

```text
Home
  → New scan (ML Kit Android / VisionKit iOS)
  → Review (zoom, enhance B&W, rotate, retake, reorder, delete page)
  → Continue → Save document (PDF and/or JPEG, compressed)
  → Home Recent list
  → Open viewer (swipe, share, rename, delete)
Settings → theme Light / Dark / System
```

---

## Critical

### C1. iOS document-scanner MethodChannel may never register

| | |
|--|--|
| **Files** | [`ios/Runner/AppDelegate.swift`](ios/Runner/AppDelegate.swift) L28–48; [`ios/Runner/Info.plist`](ios/Runner/Info.plist) (`UIApplicationSceneManifest` + `SceneDelegate`) |
| **Bug** | Channel registration requires `window?.rootViewController as? FlutterViewController`. With UIScene, `AppDelegate.window` is often **nil**, so registration returns early and never sets `scannerChannelRegistered`. |
| **Impact** | iOS **New scan** fails with `MissingPluginException` / permanent scanner failure. App Store path broken. |
| **Fix** | Register via `engineBridge.applicationRegistrar.messenger()` inside `didInitializeImplicitFlutterEngine`. Resolve presenter VC at **scan** time from the key window / scene, not only at register time. |

### C2. `editorSessionProvider.autoDispose` can wipe session mid-scan

| | |
|--|--|
| **Files** | [`lib/features/document_editor/editor_controller.dart`](lib/features/document_editor/editor_controller.dart) L56–59; [`lib/features/home/home_screen.dart`](lib/features/home/home_screen.dart) L143–150 |
| **Bug** | Home only `ref.read`s the session (no `watch`/`listen`). Provider is `autoDispose`. During `await startFromScanPaths(...)` (file I/O across frames), if no widget listens, Riverpod can dispose the notifier and create a fresh one with `state == null` before `ReviewScreen` mounts. |
| **Impact** | Flaky **“No pages to review”** after a successful scan; possible use-after-dispose. |
| **Fix** | Remove `autoDispose`, or `ref.keepAlive()` for the session lifetime, or `listenManual` from a long-lived ancestor until export/cancel. |

---

## High

### H1. Cancel / back leaves orphan document folders

| | |
|--|--|
| **Files** | `editor_controller.dart` `startFromScanPaths`; `document_storage_service.dart` |
| **Bug** | Originals are written under `documents/<newId>/` before any `meta.json`. Back from review or disposed session does not delete the folder. |
| **Impact** | Storage leak on every abandoned scan. |
| **Fix** | Delete `documentDir(id)` on cancel/pop; or mark drafts and GC incomplete docs on launch. |

### H2. `startFromScanPaths` import errors uncaught on Home

| | |
|--|--|
| **Files** | `home_screen.dart` `_startScan`; `document_storage_service.dart` `importOriginal` |
| **Bug** | No try/catch around import after scanner returns. Missing/expired temp paths throw after the loading dialog is dismissed. |
| **Impact** | Red error screen or silent failure; user stuck. |
| **Fix** | try/catch → SnackBar; delete partial `docId` directory. |

### H3. Viewer creates a new `PageController` every build

| | |
|--|--|
| **Files** | [`lib/features/viewer/viewer_screen.dart`](lib/features/viewer/viewer_screen.dart) L81–84 |
| **Bug** | `pageController: PageController(initialPage: _index)` inside `build`, never disposed. |
| **Impact** | Memory leak; gallery may jump/reset on rebuild (rename/share). |
| **Fix** | Create controller once (`initState` / late field); `dispose()` it. |

### H4. Retake-all creates a new `documentId` and abandons previous originals

| | |
|--|--|
| **Files** | `review_screen.dart` `_retakeAll`; `startFromScanPaths` |
| **Bug** | Always allocates a new UUID and imports again; old folder orphaned (same class as H1). |
| **Impact** | Duplicate disk use after repeated retakes. |
| **Fix** | Reuse session `documentId` and replace pages, or delete the old directory first. |

---

## Medium

### M1. Export re-encodes JPEG multiple times

| | |
|--|--|
| **Files** | `editor_controller.dart` `export`; `pdf_export_service.dart` |
| **Bug** | Originals may be compressed into `processed`, then PDF compresses again; image export compresses again (and rotate re-encodes). |
| **Impact** | Softer text, slower export, higher CPU/memory. |
| **Fix** | Compress once; PDF/images consume those bytes without a second encode (rotate only when needed). |

### M2. Export mutates page `processedImagePath` for “Original” filter

| | |
|--|--|
| **Files** | `editor_controller.dart` export loop |
| **Bug** | Compressed export path is stored on the page with `selectedFilter: original`. `displayPath` prefers processed. |
| **Impact** | Viewer shows compressed “original”; confuses non-destructive editing story. |
| **Fix** | Keep export copies only under `export/`; do not attach them as page `processedImagePath` for Original. |

### M3. Thumbnail ignores page rotation

| | |
|--|--|
| **Files** | `editor_controller.dart` thumbnail generation |
| **Bug** | Cover thumb from `displayPath` without applying `rotation`. |
| **Impact** | Home thumbnails wrong orientation after rotate. |
| **Fix** | Apply same rotation as PDF before `makeThumbnail`. |

### M4. Rename updates meta only — export filenames stay old

| | |
|--|--|
| **Files** | `providers.dart` `rename`; storage `writePdf` / `writeExportImage` |
| **Bug** | Share still sends on-disk names from export time (`Scan_….pdf`). |
| **Impact** | Shared filename ≠ UI name. |
| **Fix** | Rename/move export files on rename, or pass a display name to share if supported. |

### M5. Page delete / replace does not delete unused files

| | |
|--|--|
| **Files** | `editor_controller.dart` `deleteSelectedPage`, `replacePageAt` |
| **Bug** | FS originals/processed can remain; `_export` processed stubs may linger. |
| **Impact** | Disk bloat inside the document folder. |
| **Fix** | Delete unused paths when removing/replacing pages. |

### M6. Loading dialog shown during native scanner UI

| | |
|--|--|
| **Files** | `home_screen.dart` `_startScan` |
| **Bug** | Non-dismissible spinner while ML Kit / VisionKit should own the screen. |
| **Impact** | Awkward overlay; stuck-modal risk if `pop` fails. |
| **Fix** | Spinner only while importing paths **after** scanner returns. |

### M7. Review uses `Transform.rotate` around `PhotoView`

| | |
|--|--|
| **Files** | `review_screen.dart` |
| **Bug** | Visual-only rotation; pinch/pan hit-testing vs rotated child often wrong; thumbnail strip unrotated. |
| **Impact** | Confusing preview/gestures (PDF export still uses rotation metadata correctly). |
| **Fix** | Bake rotation into the preview bitmap, or apply rotation inside PhotoView’s transform carefully. |

### M8. Android depends on Google Play services (no in-app check)

| | |
|--|--|
| **Files** | `document_scanner_service.dart` (ML Kit) |
| **Bug** | Devices without GMS fail at scan with opaque errors. |
| **Impact** | Poor error UX on some Android builds/regions. |
| **Fix** | Detect/handle missing Play services; clearer copy. |

### M9. `permission_handler` unused; CAMERA permission may be unnecessary on Android

| | |
|--|--|
| **Files** | `pubspec.yaml`; `AndroidManifest.xml` |
| **Bug** | Dependency never called from Dart; ML Kit Doc Scanner typically owns camera via Play services. |
| **Impact** | Noise / possible Play policy confusion. iOS `NSCameraUsageDescription` remains correct for VisionKit. |
| **Fix** | Remove unused plugin; revisit CAMERA if Android path is ML-Kit-only. |

### M10. Google Fonts may fetch over network vs “offline” claim

| | |
|--|--|
| **Files** | `app_theme.dart`; Settings about copy |
| **Bug** | `google_fonts` can hit the network on first run. |
| **Impact** | Theme flash or failure fully offline. |
| **Fix** | Bundle fonts as assets; `GoogleFonts.config.allowRuntimeFetching = false`. |

### M11. Viewer empty / missing page files not guarded

| | |
|--|--|
| **Files** | `viewer_screen.dart` |
| **Bug** | `itemCount: 0` and missing `FileImage` paths not handled. |
| **Impact** | Blank viewer or crash for corrupt meta. |
| **Fix** | Guard empty list; `errorBuilder` / exists check. |

---

## Low

| ID | Issue | Impact | Fix hint |
|----|-------|--------|----------|
| L1 | Export `clear()` then `popUntil` can flash empty review | Brief “No pages” flash | Pop first, then clear |
| L2 | Viewer share with no files is silent | Dead tap | SnackBar like Home |
| L3 | Rename dialog `TextEditingController` not disposed | Tiny leak | Dispose after dialog |
| L4 | B&W skip only checks processed path exists | Rare stale skip | Invalidate on original change |
| L5 | FAB theme hardcodes navy/white in dark mode | Visual inconsistency | Use `ColorScheme` |
| L6 | `_safeFileName` can collapse Unicode names to `Scan` | Rare collisions | Stronger sanitization + uniqueness |
| L7 | Tests cover home + filter/compression only | Regressions in scan/export uncaught | Add session/export widget tests |

---

## What works (acceptance checklist)

| Area | Status |
|------|--------|
| App boots with `ProviderScope` + light/dark/system theme persistence | Pass |
| Millennial theme (navy, Source Serif/Sans, paper surfaces) | Pass |
| Android scan via ML Kit JPEG + cancel handling | Pass *(needs GMS; not device-tested here)* |
| iOS VisionKit handler logic (cancel / fail / JPEG / orientation) | Pass **if** channel registered (see C1) |
| `NSCameraUsageDescription` present | Pass |
| Android `minSdk ≥ 21` for ML Kit | Pass |
| Import originals into `documents/<id>/originals/` | Pass |
| Review: select page, B&W / reset color, apply-all | Pass |
| Rotate stored as metadata; PDF applies rotation | Pass |
| Reorder via `onReorderItem` | Pass |
| Block delete of last page | Pass |
| Export requires ≥1 format; progress labels | Pass |
| Compression policy (long edge ≤ 1600, JPEG q=82) | Pass (unit-tested) |
| CamScan B&W constants / pipeline present | Pass (unit-tested ink darkness) |
| Persist `meta.json` + Recent sorted by `updatedAt` | Pass |
| Home list / empty state / pull-to-refresh | Pass |
| Rename / delete with confirm (home + viewer) | Pass |
| Home share prefers PDF, else images | Pass |
| Settings theme radios (`RadioGroup`) | Pass |
| `flutter analyze` clean | Pass |
| `flutter test` (3) pass | Pass |

---

## Flow-by-flow results

### 1. Home → New scan → Review

| Step | Expected | Audit result |
|------|----------|--------------|
| Tap New scan | Open platform scanner | Android OK; **iOS at risk (C1)** |
| Loading UI | Reasonable feedback | Spinner during native UI (**M6**) |
| Import pages | Session with pages | **Race with autoDispose (C2)**; orphans on cancel (**H1**) |
| Open Review | Pages visible | Can show empty if C2 hits |

### 2. Review editing

| Step | Expected | Audit result |
|------|----------|--------------|
| Zoom/pan | Smooth preview | OK; rotate+PhotoView awkward (**M7**) |
| Enhance B&W | Spec filter + cache | OK |
| Rotate | Visual + export | Metadata OK; thumb wrong (**M3**); preview quirky (**M7**) |
| Retake page | Same index replaced | OK; leftover files (**M5**) |
| Retake all | Fresh capture | Works; orphans old dir (**H4**) |
| Reorder | PDF order matches | OK |
| Delete page | Confirm; keep ≥1 | OK |

### 3. Export → Recent

| Step | Expected | Audit result |
|------|----------|--------------|
| Name + PDF/JPEG | Compressed files on disk | Works; quality loss from re-encode (**M1**); Original path pollution (**M2**) |
| Appear in Recent | After save | OK |
| Survive restart | meta.json reload | OK |

### 4. Viewer / share / settings

| Step | Expected | Audit result |
|------|----------|--------------|
| Open / swipe / zoom | OK | **PageController leak (H3)** |
| Share / rename / delete | OK | Rename doesn’t rename files (**M4**); empty share silent (**L2**) |
| Theme | Persisted | OK; fonts may need network (**M10**) |

---

## Priority fix order (recommended)

1. **C1** — iOS channel registration via engine bridge + runtime presenter  
2. **C2** — Editor session lifecycle (`keepAlive` / drop premature `autoDispose`)  
3. **H1 / H4** — Orphan directory cleanup on cancel / retake-all  
4. **H3** — Viewer `PageController` lifecycle  
5. **H2** — try/catch around scan import  
6. **M1 / M2** — Single-compress export; don’t pollute Original `processedImagePath`  
7. Remaining Medium/Low UX and hygiene items  

---

## Test coverage gap

Current tests:

- Widget: home empty state loads (faked documents provider)
- Unit: compression long-edge resize
- Unit: B&W filter keeps dark ink

**Missing (high value):**

- Editor session survives async import (guards C2)
- Export PDF page count / file existence
- Orphan cleanup / cancel path
- Viewer `PageController` dispose
- Mocked scanner success → review navigation

---

## Conclusion

ScanMe is a **coherent offline scanner MVP** with the right feature set and clean static analysis. It is **not yet store-ready** until **C1 (iOS scanner)** and **C2 (session autoDispose)** are fixed, plus orphan storage cleanup and the Viewer controller leak.

**Overall readiness:** ~70% functionally designed; **blocking issues on iOS + flaky post-scan review**.

---

## Fixes applied (2026-08-12 follow-up)

| ID | Status | Change |
|----|--------|--------|
| C1 | Fixed | iOS channel via `engineBridge.applicationRegistrar.messenger()`; presenter resolved at scan time |
| C2 | Fixed | Removed `autoDispose` from `editorSessionProvider` |
| H1 | Fixed | `discardUnsaved` + `deleteDraftIfUnsaved`; Review `PopScope`; `purgeOrphanDrafts` on refresh |
| H2 | Fixed | try/catch around import; spinner only after scanner returns |
| H3 | Fixed | Viewer owns a single `PageController` + `dispose` |
| H4 | Fixed | `replaceAllFromScanPaths` reuses document id |
| M1/M2 | Fixed | Single compress+rotate prepare; PDF/images use those bytes; Original not written to `processed/` |
| M3 | Fixed | Thumbnail from rotated export-ready bytes |
| M4 | Fixed | `renameExports` renames PDF/JPEG on disk |
| M5 | Fixed | Delete page files on delete/replace |
| M6 | Fixed | (with H2) spinner after scanner only |
| M7 | Fixed | `RotatedBox` for preview + thumbs (hit-test safe) |
| M8 | Fixed | Clearer Play services error copy |
| M9 | Fixed | Removed `permission_handler`; dropped unused Android CAMERA perm |
| M10 | Fixed | Bundled Liberation Sans/Serif assets; removed `google_fonts` |
| M11 | Fixed | Viewer empty/missing page guards |
| L1–L3,L5,L6 | Fixed | Pop-then-clear; share SnackBar; dispose controllers; FAB uses scheme; safer filenames |
| L7 | Partial | Added `safe_filename_test`; full scan E2E still manual |

---

*Generated by code audit on 2026-08-12. Device/emulator E2E not executed in this pass.*
