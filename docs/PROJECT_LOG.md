# ScanMe — Project Log (living)

**Package:** `app.atl.scanme` · **Brand:** ScanMe / Apptriangle  
**Stack:** Flutter · Riverpod · ML Kit (Android) / VisionKit (iOS) · local storage  
**Version:** `1.0.0+2` (versionCode **2**)  
**Last updated:** 2026-08-16

> **Agent rule:** After every user task, update this file (Current status · Task log · relevant sections).  
> Deep UI screen detail still lives in [`UI_PAGES.md`](UI_PAGES.md) (linked, not duplicated line-by-line).
> CamScan B&W spec: [`PROPOSAL_FORM_BW_CAMSCAN_SPEC.md`](PROPOSAL_FORM_BW_CAMSCAN_SPEC.md) — **every page**.

---

## How agents use this file

1. Read **Current status** + latest **Task log** before coding.
2. Do the task.
3. **Before reply ends:** append **Task log** entry (date · request · done · files · leftover). No skip — even small / “just docs” / “just reminder” tasks.
4. Patch **Current status** / Open-watch / version if they changed.
5. Do **not** commit unless user asks. Never commit `android/key.properties` / `*.jks`.

---

## Current status

| Area | State |
|------|--------|
| Core flows | Scan → Review → Export → Library → Viewer (architecturally complete) |
| Home UI | Shell + customizable tools; **no Folders/Unfiled/Settings** on dashboard |
| Motion | Modern M3-style shared `AppMotion` (routes, lists, press, sheets, nav) |
| CamScan B&W | **Fixed 2026-08-16** — async path no longer full-white; SLI spec on every page |
| Document tags | Colored `TagDef` catalog; Settings CRUD; assign Home ⋯ / Viewer; filter chips |
| Tools / converters | Hub titled **Convert** (PDF / text / slides / images) |
| File viewers | Convert · View PDF · **Open with** tool aliases from file manager |
| Open with OS | Android **activity-aliases** with tool icons/labels (View PDF, PDF to .txt, …); iOS document types |
| Folders | Data model kept; **UI paused** (no chips / move / Unfiled) |
| PDF watermark | Apptriangle corner on **every PDF page** (PDF draw + image bake on exports) |
| Save to device | System **Save as** dialog (user picks folder/name) — not silent Downloads |
| Automated tests | Converter suite green (PNG↔JPG + TXT→PDF); full suite may flake on compiler OOM |
| Device smoke | User self-testing (paused agent device runs until asked) |
| Play release | Ready to build AAB **+2**; Play Console 4 recommendations addressed in code |
| Open device gaps | Full capture→Save PDF; Viewer/print/share E2E; PDF/PPTX convert E2E |
| Audit (2026-08-12) | Historical; verify C1/C2/H* before treating as fixed |

### Next ship

```bash
flutter clean && flutter pub get
flutter build appbundle --release
# Upload AAB versionCode 2
```

### Open / watch

- [ ] Device: Open with shows **tool aliases** (icons + labels) after reinstall
- [ ] User confirm B&W ink survives on device (hot restart / reinstall)
- [ ] Re-check Play Console after AAB+2 (edge-to-edge, orientation, R8 %, bitmap)
- [ ] Device: ML Kit still opens after `screenOrientation=unspecified` override
- [ ] Device: full scan → Review → Save PDF
- [ ] Device: colored tags — Settings CRUD + assign on Home/Viewer + filter chips
- [ ] Device: Save as dialog (file manager) for Tools / Viewer / Export
- [ ] Confirm audit C1 (iOS channel) / C2 (editor autoDispose) still relevant

---

## Task log

### 2026-08-16 — Filter loading copy
- **Request:** Filter loading text bad (“filtering page 2 of 1”).
- **Done:** Progress uses work count, not page index. Single page → “Applying filter…”; multi → “Applying filter · 1 of 3…”.
- **Files:** `editor_controller.dart`, docs
- **Left:** None.

### 2026-08-16 — Converter file naming
- **Request:** Converter origin/output file names bad; give good format.
- **Done:** Output `Base_KIND_yyyy-MM-dd_HHmm.ext` (e.g. `Contract_TXT_2026-08-16_1445.txt`); incoming `incoming_Name.ext`; strip `open_with_` / `_src_` / prior convert stamps via `cleanBaseName`.
- **Files:** `document_converter_service.dart`, `MainActivity.kt`, `OpenFileIntentHandler.swift`, `converter_test.dart`, docs
- **Left:** None.

### 2026-08-16 — Fix test analyzer errors
- **Request:** Fix LSP errors in `ui_functionality_test`, `widget_test`, `converter_test`.
- **Done:** Fake docs controllers implement `toggleTag`; `path_provider_platform_interface` added as `dev_dependency`.
- **Files:** `test/ui_functionality_test.dart`, `test/widget_test.dart`, `pubspec.yaml`, docs
- **Left:** Run `flutter pub get` if IDE still flags converter import.

### 2026-08-16 — Dashboard / Convert / folders / Open-with tools
- **Request:** Fix Add-sheet hint alignment; PDF Tools misleading; remove Folders/Unfiled + folder UX; remove Settings from dashboard tools; Open-with show tool icons/capabilities.
- **Done:** Hint centered+padded; **Convert** rename (tile + hub + nav); folders/Unfiled/Settings removed from catalog + Files/Viewer UI; Android activity-aliases with drawable tool icons (View / convert per type) + `IntentConvertScreen`.
- **Files:** `dashboard_tools.dart`, `home_dashboard_screen.dart`, `home_screen.dart`, `viewer_screen.dart`, `converters_hub_screen.dart`, `main_shell_screen.dart`, `AndroidManifest.xml`, `MainActivity.kt`, drawables, `open_file_intent_bridge.dart`, `intent_convert_screen.dart`, docs
- **Left:** Reinstall to refresh Open-with list.

### 2026-08-16 — Open with ScanMe (file manager)
- **Request:** Opening files from phone file manager should offer ScanMe; chooser icon = app icon.
- **Done:** Android `VIEW` intent-filters (PDF / text / image / PPTX) + activity `@mipmap/ic_launcher`; copy URI → cache → `FileViewerScreen` via `app.atl.scanme/open_file`. iOS `CFBundleDocumentTypes` + URL handlers. `navigatorKey` + `OpenFileIntentBridge`.
- **Files:** `AndroidManifest.xml`, `MainActivity.kt`, `open_file_intent_bridge.dart`, `main.dart`, iOS `Info.plist` / `OpenFileIntentHandler.swift` / `AppDelegate` / `SceneDelegate` / `project.pbxproj`, docs
- **Left:** Device confirm Open-with list + icon after reinstall.

### 2026-08-16 — Customizable dashboard tools
- **Request:** Dashboard user can add buttons of choice; more buttons in Add; defaults = most important only.
- **Done:** Catalog of 15 tools; default **Smart Scan · PDF Tools · Import Images · Files**; **Add** tile opens sheet (toggle add/remove + Reset); long-press tile removes; prefs `dashboard_tool_ids_v1`.
- **Files:** `dashboard_tools.dart`, `home_dashboard_screen.dart`, docs
- **Left:** Convert shortcuts open Tools tab (same hub).

### 2026-08-16 — Remove Tools “Open file” tile
- **Request:** No separate button to open files of different types; viewers stay in-app for other flows only.
- **Done:** Removed Tools **Open file** picker tile + `_openAnyFile`. `FileViewerScreen` still used after convert (**Open in ScanMe**) and library **View PDF**.
- **Files:** `converters_hub_screen.dart`, docs
- **Left:** None.

### 2026-08-16 — Scan icon → document scanner
- **Request:** Change the scan image.
- **Done:** Center FAB + Smart Scan + scan/retake actions use `document_scanner` (not crop frame).
- **Files:** `main_shell_screen.dart`, `home_dashboard_screen.dart`, `document_card.dart`, `review_screen.dart`, `app_ui.dart`, `docs/PROJECT_LOG.md`
- **Left:** None.

### 2026-08-16 — Less AI-ish icons
- **Request:** App icons look AI-ish; use better icons.
- **Done:** Replaced sparkle/handyman/generic set. Home: crop_free, pdf, collections, inventory_2, topic, local_offer, bookmark. Nav: inventory_2, swap_horiz, manage_accounts; FAB crop_free. Tools: article / present_to_all / crop_original / folder_open / save_alt. Review: tonality not auto_awesome. Favorites → bookmark.
- **Files:** home_dashboard, main_shell, converters_hub, document_card, review_screen, viewer, file_viewer, home_screen, app_ui, docs
- **Left:** None.

### 2026-08-16 — Save via system file manager
- **Request:** Save to device broken; ask permission; save in folder; user creates file in phone file manager.
- **Done:** `DeviceSaveService` now uses `FilePicker.saveFile` (Android `CREATE_DOCUMENT` / system Save as) — user picks folder + filename. Cancel = null + snackbar. Removed silent MediaStore channel from `MainActivity`. Export toggle copy updated.
- **Files:** `device_save_service.dart`, `MainActivity.kt`, converters/file viewer/viewer/export, `library_models.dart`, docs
- **Left:** User confirm Save as dialog on device.

### 2026-08-16 — In-app file viewers
- **Request:** App should have its own .txt, pptx, pdf, image viewer.
- **Done:** `FileViewerScreen` — TXT (selectable scroll), PDF (`PdfPreview`), images (`PhotoView`), PPTX (slide PageView text+images). Tools: **Open file** + result **Open in ScanMe**; library Viewer ⋯ **View PDF** when export exists.
- **Files:** `file_viewer_screen.dart`, `converters_hub_screen.dart`, `viewer_screen.dart`, docs
- **Left:** PPTX is best-effort layout (not full PowerPoint fidelity).

### 2026-08-16 — Search focus stuck after keyboard / tab
- **Request:** After keyboard back, search box still alive after page shift and return.
- **Done:** Unfocus on tab change (`FocusManager` + `isActive` → `FocusNode.unfocus`); Home/Files `onTapOutside` / submit dismiss; KeepAlive no longer keeps caret hot.
- **Files:** `main_shell_screen.dart`, `home_dashboard_screen.dart`, `home_screen.dart`, `docs/PROJECT_LOG.md`
- **Left:** None.

### 2026-08-16 — PDF → .txt functionality
- **Request:** Not just caption — change functionality; PDF to text is PDF to `.txt`.
- **Done:** `pdfToTxt` writes UTF-8 `.txt` always; page-by-page extract with `layoutText: true` + page markers; MIME `text/plain` on share/save; UI “Save .txt to device”; regression test PDF→`.txt`.
- **Files:** `document_converter_service.dart`, `converters_hub_screen.dart`, `test/converter_test.dart`, docs
- **Left:** Scanned PDFs still no OCR (honest notice in file).

### 2026-08-16 — PDF to .txt caption
- **Request:** PDF to text is actually PDF to .txt.
- **Done:** Tools tile **PDF to .txt** (+ matching subtitle); pair tile **.txt to PDF**; result label `.txt file`.
- **Files:** `converters_hub_screen.dart`, `document_converter_service.dart`, `docs/UI_PAGES.md`, `docs/PROJECT_LOG.md`
- **Left:** None.

### 2026-08-16 — Visible page transitions
- **Request:** Page transitions static / none; fix.
- **Done:** Cause was ~4% slide (invisible). `AppPageRoute` now clear shared-axis (22% slide + fade, 360ms); theme builder matched; shell tabs use `PageView.animateToPage` (+ keep-alive) instead of instant `IndexedStack`.
- **Files:** `app_transitions.dart`, `app_theme.dart`, `main_shell_screen.dart`, `docs/PROJECT_LOG.md`
- **Left:** User confirm push (Viewer/Scan) + tab switches feel right.

### 2026-08-16 — FAB ignore keyboard inset
- **Request:** Camera icon rises with keyboard; should not.
- **Done:** `MainShellScreen` `resizeToAvoidBottomInset: false` — FAB + bottom nav stay put; keyboard overlays body.
- **Files:** `main_shell_screen.dart`, `docs/PROJECT_LOG.md`
- **Left:** None.

### 2026-08-16 — Fix Home search switching to Files
- **Request:** Search bar key press toggles Files page; fix.
- **Done:** Removed `onOpenFiles()` from `onChanged`. Typing stays on Home and filters Recents; keyboard Search / submit opens Files. Clear (×) added.
- **Files:** `home_dashboard_screen.dart`, `docs/PROJECT_LOG.md`
- **Left:** None.

### 2026-08-16 — Modern friendly motion
- **Request:** Animations everywhere should feel modern / user-friendly.
- **Done:** Shared `AppMotion` M3 curves (emphasized / decelerate / soft spring); page routes fade+rise+scale; softer list stagger; card press spring; bottom sheets settle; Home tool tiles + bottom nav `PressableScale` / icon morph; reduce-motion honored; theme builder matched.
- **Files:** `app_transitions.dart`, `app_theme.dart`, `app_ui.dart`, `document_card.dart`, `main_shell_screen.dart`, `home_dashboard_screen.dart`, `home_screen.dart`, `converters_hub_screen.dart`, docs
- **Left:** User feel on device.

### 2026-08-16 — Tools tile captions
- **Request:** Tools page captions look odd — change them.
- **Done:** Plain titles (PDF to Text, Text to PDF, PowerPoint to PDF, PNG to JPG, JPG to PNG) + short plain subtitles; page blurb cleaned.
- **Files:** `converters_hub_screen.dart`, `docs/UI_PAGES.md`, `docs/PROJECT_LOG.md`
- **Left:** None.

### 2026-08-16 — Standing order: always update PROJECT_LOG
- **Request:** After every finished user task, write to `docs/PROJECT_LOG.md`; keep in memory; do it.
- **Done:** Reaffirmed. How-agents step 3 now says **before reply ends** / no skip. `.cursor/rules/project-log.mdc` already alwaysApply — left in place, wording synced.
- **Files:** `docs/PROJECT_LOG.md`, `.cursor/rules/project-log.mdc`
- **Left:** None — mandatory every task hereafter.

### 2026-08-16 — Home shell layout + Tools converters
- **Request:** CamScanner-like Home layout (not clone); converters = Tools; fix broken outputs; save to device; add TXT→PDF.
- **Done:** `MainShellScreen` bottom nav (Home · Files · camera FAB · Tools · Me); Home dashboard = search + 8-tool grid + Recents; Files = prior library; Tools hub with PDF↔TXT, PPTX→PDF, PNG↔JPG; fixed `_stamp()` Closure filenames; SAF `readAsBytes` fallback; TXT→PDF via `package:pdf` MultiPage + watermark footer; Save to device on result.
- **Files:** `main_shell_screen.dart`, `home_dashboard_screen.dart`, `home_flows.dart`, `home_screen.dart`, `converters_hub_screen.dart`, `document_converter_service.dart`, `settings_screen.dart`, `main.dart`, tests, docs
- **Left:** User try Tools on device; Folders/Tags tiles jump to Files (chip expand still manual).

### 2026-08-16 — Colored document tags
- **Request:** Tags with name + color; configure in Settings; assign where docs get tagged.
- **Done:** `TagDef` catalog (`library/tags.json`) with palette + seed tags; docs store tag **ids** (legacy free-text migrated); Settings list (tap edit name/color, Delete in dialog / long-press); assign sheet from Home ⋯ **Tags** + Viewer Tags; Home filter chips colored; search matches tag **names**; `MetaChip` color on cards.
- **Files:** `library_models.dart`, `document_storage_service.dart`, `providers.dart`, `tag_sheets.dart`, `settings_screen.dart`, `home_screen.dart`, `viewer_screen.dart`, `document_card.dart`, `app_ui.dart`, `test/library_query_test.dart`, docs
- **Left:** User try on device.

### 2026-08-16 — Enhance filters + Retake all toolbar
- **Request:** More Enhance filters; replace More with Retake all.
- **Done:** Filters: Original, B&W, Greyscale, Auto, Vivid, Lighten (sheet + chips). Toolbar **Retake all** (confirm dialog). Removed More sheet.
- **Files:** `page_filter.dart`, `cam_scan_bw_filter.dart` (PageLookFilters), `review_screen.dart`, `editor_controller.dart`, tests
- **Left:** User try filters on device.

### 2026-08-16 — Save to device + PDF Apptriangle watermark
- **Request:** Save all generated files to device; Apptriangle watermark on every PDF page visible in any viewer.
- **Done:** PDF corner logo via `package:pdf` Stack on each page; JPEG/PNG still pixel-stamped; Export “Also save to device” (Downloads/ScanMe via MediaStore); Viewer download; Converters Save to device; PPTX→PDF + image converts watermarked.
- **Files:** `watermark_service.dart`, `pdf_export_service.dart`, `device_save_service.dart`, `MainActivity.kt`, export/editor/viewer/converters, `test/watermark_pdf_test.dart`
- **Left:** User confirm PDF opens with logo in external viewer; Downloads/ScanMe appears.

### 2026-08-16 — Fix CamScan B&W full-white (SLI spec)
- **Request:** Filter full white; follow `PROPOSAL_FORM_BW_CAMSCAN_SPEC.md`; apply every page. User self-tests later.
- **Cause:** `processBytesAsync` used Flutter `decodeDownsampled(targetWidth:1600)` → upscale + **RGBA** into wash/Bradley → **100% white**. Sync/`img.decodeImage` path was fine (tests lied).
- **Done:** B&W back to SLI path (`decodeImage` + resize ≤1600 + isolate); opaque RGB only; codec downsample never upscales + RGB out; spec copied to `docs/`; regression tests for async not-white.
- **Files:** `cam_scan_bw_filter.dart`, `scan_compression.dart`, `test/filter_compression_test.dart`, `docs/PROPOSAL_FORM_BW_CAMSCAN_SPEC.md`
- **Left:** User device confirm.

### 2026-08-16 — Emulator E2E (background, aborted)
- Images→PDF → Review → Export **reached**. Save step hung then `adb: closed` (emulator dropped). ML Kit on that AVD earlier: GMS “Something went wrong”. Not re-run — user self-testing.

### 2026-08-16 — Living project log + combine docs
- **Request:** Create MD updated every task; combine existing MDs.
- **Done:** Added this file; Cursor rule `.cursor/rules/project-log.mdc`; folded Play/Test/Audit/Store into sections below; old short docs → stubs pointing here; README points here.
- **Files:** `docs/PROJECT_LOG.md`, `.cursor/rules/project-log.mdc`, `README.md`, stubs under `docs/`
- **Left:** User continues giving tasks → agent appends here.

### 2026-08-13 — Play Console 4 recommendations
- **Request:** Fix edge-to-edge, orientation, bitmap downsample, R8.
- **Done:** `enableEdgeToEdge` + Flutter SystemUI; ML Kit activity override; decode/`cacheWidth` downsample; slim ProGuard; version `1.0.0+2`; release APK builds; tests 38 pass.
- **Files:** `MainActivity.kt`, `AndroidManifest.xml`, `styles.xml`, `main.dart`, `proguard-rules.pro`, `scan_compression.dart`, `cam_scan_bw_filter.dart`, cards/capture, `docs/PLAY_CONSOLE_FIXES.md` (now stub)
- **Left:** Upload AAB; Play re-scan; device confirm ML Kit + insets.

### 2026-08-13 — UI declutter / navy / device smoke
- Home denser, logo removed, filter chips white-on-navy, true navy `#0A2F5C`, dark `#0A0A0A`.
- Device smoke + `docs/device_shots/` + test expansion to 38.

---

## Product snapshot

Offline CamScanner-style scanner. No account / no cloud by app. Apptriangle watermark on exports.

| | |
|--|--|
| Android scan | Google ML Kit Document Scanner (needs GMS) |
| iOS scan | VisionKit |
| Library | Folders · tags · favorites · trash · search · sort |
| Export | PDF / JPEG(/PNG) compressed + watermark |
| Extra | Converters hub · print · share sheet |

---

## Navigation map

```
Home (library)
├── Settings (theme · trash retention · About)
├── FAB (+)
│   ├── Scan Document → [system scanner] → Scan capture → Review → Save → Home
│   ├── Images to PDF → [gallery] → Review → Save → Home
│   └── Converters → pick file → convert → Share
├── Trash toggle
├── Filters: folders · favorites · tags · search · sort
└── Document → Viewer (favorite · print · share · rename · folder · tags · trash)
```

**Screens (files):** Home · Settings · Scan capture · Review · Export · Viewer · Converters  
**System UIs:** ML Kit / VisionKit · gallery · file picker · share · print  

Full per-screen layout/copy/motion → [`UI_PAGES.md`](UI_PAGES.md).

---

## Play Store readiness

**Application ID:** `app.atl.scanme` (hyphen form `app.atl.scan-me` invalid on Android)  
**Publisher:** Apptriangle

| Item | Status |
|------|--------|
| Adaptive icons | Done |
| `minSdk` ≥ 21 | Yes |
| Release minify + ProGuard | Yes (slimmed 2026-08-13) |
| Keystore via `android/key.properties` | Wired (never commit secrets) |
| Cleartext HTTP off · backup of scans off | Yes |
| Offline storage · watermark | Yes |

### Before / each upload

1. Keystore: `keytool …` → fill `key.properties` from example  
2. Bump `pubspec.yaml` `version: x.y.z+N` (N = versionCode)  
3. `flutter build appbundle --release` → `build/app/outputs/bundle/release/app-release.aab`  
4. Play listing: short/full desc · screenshots · feature graphic · privacy URL · Data safety · content rating  
5. Note: Android scan needs **Google Play services**

### Privacy bullets (listing)

- Docs only on device  
- No account / no app cloud sync  
- Camera for scanning only (ML Kit on Android)  
- Share = system sheet, user-initiated  

### Smoke before promote

- [ ] Fresh install · icon  
- [ ] New scan · ML Kit  
- [ ] B&W + export · watermark  
- [ ] Share / rename / delete  
- [ ] Theme light/dark/system  
- [ ] Internal-testing AAB install  

---

## Play Console recommendations (code response · 1.0.0+2)

| # | Flag | Status | What we did |
|---|------|--------|-------------|
| 1 | Edge-to-edge (SDK 35) | Done in code | `FlutterFragmentActivity` + `enableEdgeToEdge()`; Flutter `SystemUiMode.edgeToEdge`; transparent system bars; cutout `shortEdges`; SafeArea on key UI |
| 2 | Large-screen orientation | Done in code | `resizeableActivity=true`; ML Kit `GmsDocumentScanningDelegateActivity` → `screenOrientation=unspecified` (`tools:replace`) |
| 3 | BitmapFactory downsample | Mitigated | `decodeDownsampled` / `instantiateImageCodec`; `cacheWidth` on thumbs. Play hit `f2.h.b` may be dependency — may linger |
| 4 | R8 low shrink/obfuscation | Done in rules | Dropped blanket Flutter/GMS `-keep`; keep ML Kit document-scanner only. Rates refresh after new AAB |

---

## Test report (last: 2026-08-13)

**Device:** Xiaomi 24069RA21C (`11ab4ce6`) · Android 16  
**Host:** `flutter test` → **38 PASS** · coverage ~**46%**

### Device smoke

| Check | Result |
|-------|--------|
| Install / Home / Settings / theme | PASS |
| FAB · Converters · Trash · Folders · Favorites | PASS |
| Images to PDF picker open/cancel | PASS |
| ML Kit scan open + cancel → Home | PASS |
| FATAL in logcat | None |

**Not fully walked:** capture→Review→Save PDF; Viewer/print/share; PDF→TXT / PPTX E2E.

### Automated suites

| File | Tests |
|------|------:|
| `widget_test.dart` | 1 |
| `filter_compression_test.dart` | 2 |
| `safe_filename_test.dart` | 2 |
| `converter_test.dart` | 2 |
| `library_query_test.dart` | 8 |
| `ui_functionality_test.dart` | 23 |

Screenshots: [`device_shots/`](device_shots/).

```bash
flutter test --reporter expanded
flutter run -d 11ab4ce6
```

---

## Audit snapshot (2026-08-12 · verify before acting)

Original audit: 24 findings (2 Critical · 4 High · 11 Medium · 7 Low). Full narrative was in `AUDIT_REPORT.md` (stub now).

| ID | Issue | Impact | Status |
|----|-------|--------|--------|
| C1 | iOS scanner MethodChannel may not register (UIScene / nil window) | iOS scan broken | **Verify** |
| C2 | `editorSessionProvider.autoDispose` mid-scan wipe | Flaky empty Review | **Verify** |
| H1 | Cancel leaves orphan `documents/<id>/` | Disk leak | **Verify** |
| H2 | Import errors uncaught after scan | Crash / stuck | **Verify** |
| H3 | Viewer `PageController` recreated in `build` | Leak / jump | **Verify** |
| H4 | Retake-all new id abandons old files | Disk leak | **Verify** |

Medium/Low (export re-encode, rename vs filenames, Google Fonts network, GMS check, etc.) — re-open from git history / prior audit if needed.

---

## Key paths (quick)

| Concern | Path |
|---------|------|
| Home | `lib/features/home/home_screen.dart` |
| Theme | `lib/core/theme/app_theme.dart` |
| Compression | `lib/core/services/scan_compression.dart` |
| MainActivity | `android/app/src/main/kotlin/app/atl/scanme/MainActivity.kt` |
| Manifest | `android/app/src/main/AndroidManifest.xml` |
| ProGuard | `android/app/proguard-rules.pro` |
| Privacy HTML | `privacy_policy.html` |

---

## Doc index

| File | Role |
|------|------|
| **`PROJECT_LOG.md`** | **Canonical living log** (this file) |
| [`PROPOSAL_FORM_BW_CAMSCAN_SPEC.md`](PROPOSAL_FORM_BW_CAMSCAN_SPEC.md) | CamScan B&W constants/pipeline (every page) |
| [`UI_PAGES.md`](UI_PAGES.md) | Deep UI page reference |
| [`PLAY_STORE.md`](PLAY_STORE.md) | Stub → Play section above |
| [`PLAY_CONSOLE_FIXES.md`](PLAY_CONSOLE_FIXES.md) | Stub → Play Console section above |
| [`TEST_REPORT.md`](TEST_REPORT.md) | Stub → Test section above |
| [`AUDIT_REPORT.md`](AUDIT_REPORT.md) | Stub → Audit snapshot above |
