# ScanMe — Project Log (living)

**Package:** `app.atl.scanme` · **Brand:** ScanMe / Apptriangle  
**Stack:** Flutter · Riverpod · ML Kit (Android) / VisionKit (iOS) · local storage  
**Version:** `1.0.2+9` (versionCode **9**)  
**Last updated:** 2026-08-19

> **Agent rule:** After every user task, update this file (Current status · Task log · relevant sections).  
> Deep UI screen detail: [`UI_PAGES.md`](UI_PAGES.md) (single file — all screens).  
> Capability inventory: [`FEATURES.md`](FEATURES.md) (what the app does).  
> CamScan B&W spec: [`PROPOSAL_FORM_BW_CAMSCAN_SPEC.md`](PROPOSAL_FORM_BW_CAMSCAN_SPEC.md) — **every page**.  
> iOS App Store: [`IOS_APP_STORE.md`](IOS_APP_STORE.md)

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
| Home UI | Premium: warm paper · greeting · pill search · shortcut strip · segmented filters · elevated cards |
| Motion | Modern M3-style shared `AppMotion` (routes, lists, press, sheets, nav) |
| CamScan B&W | **Fixed 2026-08-16** — async path no longer full-white; SLI spec on every page |
| Document tags | Colored `TagDef` catalog; Settings CRUD; assign Home ⋯ / Viewer; filter chips |
| Tools / converters | Hub: Documents · **Edit photo** · **PDF Tools** (merge/split/pages/compress) |
| QR reader | Camera + photo · URL → Open link primary · Copy / Share · Quick tools default |
| UX redesign | Complete transformation pass 2026-08-16 — shared kit + screen polish; prior phases 1–8 retained |
| UI docs | Single [`UI_PAGES.md`](UI_PAGES.md) · features [`FEATURES.md`](FEATURES.md) |
| File viewers | Convert · View PDF · **Open with** tool aliases from file manager |
| Open with OS | Android aliases (ScanMe **launcher icon** + tool labels); iOS PDF/TXT/image/PPTX/DOCX/XLSX/HEIC/WebP/GIF |
| Folders | Data model kept; **UI paused** (no chips / move / Unfiled) |
| PDF watermark | Apptriangle corner on **every PDF page** (PDF draw + image bake on exports) |
| First-run tour | Polished 8-page walkthrough (incl. access asks); prefs `onboarding_done_v1`; replay from Me |
| Save to device | System **Save as** dialog (user picks folder/name) — not silent Downloads |
| Automated tests | Targeted QA suite PASS (`pdf_tools` + UI + library). Full `all_converters` may OOM |
| Device smoke | **Still required** before Play — see [`QA_REPORT.md`](QA_REPORT.md) |
| Play release | **NOT READY** until device Scan→Save + PDF Tools + Open With smoke |
| App Store (iOS) | **iOS 15.5** · VisionKit · privacy manifest · 1024 icon RGB no alpha · Connect checklist [`IOS_APP_STORE.md`](IOS_APP_STORE.md). Simulator **release-path compile PASS**. Device/IPA needs Xcode Team. |
| Open device gaps | Full capture→Save PDF; Viewer/print/share E2E; PDF/PPTX convert E2E |
| Audit (2026-08-12) | Code-rechecked 2026-08-19: C1 UIScene channel **fixed**; C2 no `autoDispose`; H3 PageController in State; H4 retake-all reuses id. H1/H2 still verify on device |
| Docs drift | Log was stale at +7; missing `IOS_APP_STORE.md` / `QA_REPORT.md` / `PLAY_LISTING.md` on disk (`*.md` gitignored) |
| Dual OS (Mac + Fedora) | **Fedora: `flutter run` as before** (no bootstrap, no Gradle edits). Mac: PATH + bootstrap once. `local.properties` gitignored. Foojay/toolchain **not** added (would change Linux Gradle). |

### Next ship

```bash
flutter clean && flutter pub get
flutter build appbundle --release
# Upload AAB versionCode 7
```

### Open / watch

- [ ] **Release:** device Scan → Save PDF → reopen (P0 smoke)
- [ ] **Release:** PDF Tools merge/split/delete/compress → open in external viewer
- [ ] **Release:** Open With from file manager (single destination)
- [ ] Device: back on pushed stacks (Scan · Review · Export · Viewer · Convert · QR · Settings)
- [ ] Device: UI transform — light/dark · large text · Home search · Export progress · QR Open link
- [ ] Device: QR reader — camera permission · torch · copy/share · open URL · scan from photo
- [ ] Device: Open with shows **tool aliases** (ScanMe icon + labels) after reinstall
- [ ] User confirm B&W ink survives on device (hot restart / reinstall)
- [ ] Re-check Play Console after AAB+7 (edge-to-edge enable + deprecated bar stacks)
- [ ] Device: ML Kit still opens after `screenOrientation=unspecified` override
- [ ] Device: full scan → Review → Save PDF
- [ ] Device: colored tags — Settings CRUD + assign on Home/Viewer + filter chips
- [ ] Device: Save as dialog (file manager) for Tools / Viewer / Export
- [ ] Device: iOS scan channel (audit C1 — UIScene / MethodChannel)

Converts still omitted from Deleted. Folders UI paused.

---

## Task log

### 2026-08-19 — Ask camera / photos / files (store)
- **Request:** Ask users which things to access (files, camera, etc.) for App Store.
- **Done:** In-app rationale then OS dialog, **only when the feature is used** (5.1.1 — not at launch). Camera: Scan / Review retake / QR. Photos: import, gallery QR, images→PDF. Files: system picker after a one-time explanation (no blanket storage). Onboarding page 7 Allow camera/photos. `permission_handler` + Android READ_MEDIA_IMAGES.
- **Files:** `access_permission.dart` · home_flows · scan/review/QR · convert/PDF pick · onboarding · Podfile · AndroidManifest · tests · docs
- **Leftover:** Device: deny/allow/Settings path; `pod install` after pub get on Mac.

### 2026-08-19 — Xcode issues (file_picker privacy + recommended settings)
- **Request:** Fix Xcode Issue Navigator: file_picker_darwin missing `PrivacyInfo.xcprivacy`; Runner “Update to recommended settings.”
- **Done:** SPM looks for `Sources/file_picker_darwin/Resources/PrivacyInfo.xcprivacy`; plugin ships it one folder up. Podfile copies the file on `pod install`. LastUpgradeCheck/scheme **2600** (Xcode 26). Signing (APPTRIANGLE LIMITED / `app.atl.scanme`) left as-is.
- **Files:** `ios/Podfile` · `project.pbxproj` · `Runner.xcscheme` · this log
- **Leftover:** Close/reopen Xcode (or Clean) so the two warnings clear. `flutter run --release` was already launching on Ahmed’s iPhone.

### 2026-08-19 — iOS 15.5 + App Store prep + build verify
- **Request:** Fix pod/VisionKit run, verify iOS build, prepare App Store per guidelines.
- **Done:** Min iOS **15.5** (pbxproj + Podfile + post_install) so `google_mlkit_document_scanner` pod resolves; iOS scan remains VisionKit. Photo **Add** purpose string. [`IOS_APP_STORE.md`](IOS_APP_STORE.md) (privacy answers, review notes, 2.1/5.1.x). 1024 icon 1024² no alpha. Fixed `editor_controller` `String?` FileImage (blocked Xcode). **`flutter build ios --simulator` PASS** → `build/ios/iphonesimulator/Runner.app`. Device `--no-codesign` still asks for Development Team.
- **Files:** `ios/Podfile` · `project.pbxproj` · `Info.plist` · `docs/IOS_APP_STORE.md` · `editor_controller.dart` · this log
- **Leftover:** Xcode → Runner → Team; `flutter run` on Ahmed’s iPhone; smoke VisionKit; host privacy URL; screenshots; `bash tool/build_ios_release.sh` + Transporter. Fedora Android unchanged.

### 2026-08-19 — VisionKit working?
- **Request:** Confirm VisionKit works.
- **Done:** iOS scan path is VisionKit (`DocumentScannerHandler` + channel `app.atl.scanme/document_scanner`); Dart uses it only when `Platform.isIOS`. ML Kit is Android-only. Not device-proven this session: `flutter run` died at pod install (`google_mlkit_document_scanner` wants iOS ≥ 15.5, app is 13.0).
- **Files:** none
- **Leftover:** Raise iOS min to 15.5 (or stub ML Kit on iOS) so the app can launch, then smoke Scan on iPhone.

### 2026-08-19 — Fedora must run as before (no edits)
- **Request:** Going to Fedora, everything runs as before without editing anything.
- **Done:** Removed Foojay + Java toolchain (Fedora Gradle stays compileOptions 17 as before). Bootstrap **does not rewrite** a valid existing `local.properties` and **exits immediately on Linux** in that case. README: Fedora = `flutter run` only. `local.properties` still gitignored (Mac paths never land on Fedora via git).
- **Files:** `android/settings.gradle.kts` · `android/app/build.gradle.kts` · `android/gradle.properties` · `tool/bootstrap.sh` · `README.md` · this log
- **Leftover:** On Fedora after pull: `flutter run`. Wrapper/Podfile in git are unused extra files on Linux, not a setup change.

### 2026-08-19 — Mac `flutter` not on PATH
- **Request:** `flutter run` → `zsh: command not found: flutter`
- **Done:** SDK already at `~/Projects/flutter` (3.44.8). Added that `bin` + `ANDROID_HOME` to `~/.zshrc` (Mac only; Fedora PATH unchanged).
- **Files:** `~/.zshrc` (machine, not the repo)
- **Leftover:** New terminal or `source ~/.zshrc`, then `bash tool/bootstrap.sh` and `flutter run`. JDK 17 still missing on this Mac if Android Gradle starts.

### 2026-08-19 — Dual Mac + Fedora run setup
- **Request:** Run on Mac and Fedora without changing project setup each switch; Fedora already works.
- **Done:** `tool/bootstrap.sh` resolves Flutter + Android SDK per machine and writes gitignored `android/local.properties`. Foojay + Java 17 toolchain (no `JAVA_HOME` in repo). Stopped ignoring Gradle wrapper; added `gradlew` / `gradlew.bat` / `gradle-wrapper.jar` (9.1.0). Committed-ready `ios/Podfile` (`platform :ios, 13.0`); Pods/Generated.xcconfig stay ignored. README run table. Fedora: re-run bootstrap only after clone/SDK move.
- **Files:** `tool/bootstrap.sh` · `android/settings.gradle.kts` · `android/app/build.gradle.kts` · `android/.gitignore` · `android/gradle.properties` · `android/gradlew*` · `android/gradle/wrapper/` · `android/local.properties.example` · `ios/Podfile` · `README.md` · this log
- **Leftover:** This Mac still needs Flutter on PATH + JDK 17 (`brew install --cask temurin@17`) then `bash tool/bootstrap.sh`. Do not commit `local.properties`.

### 2026-08-19 — Full project analysis + standing log rule
- **Request:** Full project analysis + report; find PROJECT_LOG; after every task append to it; remember without being told.
- **Done:** Read log, FEATURES, UI_PAGES, lib layout, Android/iOS native, pubspec, tests. Workspace alwaysApply rule `.cursor/rules/project-log.mdc` (+ existing `scan_me/.cursor/rules/project-log.mdc`). Synced version here to `1.0.2+9`. Report in chat.
- **Files:** `.cursor/rules/project-log.mdc` · `scan_me/.cursor/rules/project-log.mdc` · this log
- **Leftover:** Device smoke still blocks stores; iOS IPA needs Apple team in Xcode (`DEVELOPMENT_TEAM` unset); recreate missing store/QA md if needed.

### 2026-08-18 — iOS App Store prep
- **Request:** Full iOS build covering everything; keep App Store publishability.
- **Done:** This host is Linux — **no IPA** (Xcode required). Store config: `PrivacyInfo.xcprivacy` (no tracking, UserDefaults CA92.1, file timestamp C617.1); purpose strings (camera/photos on-device); `ITSAppUsesNonExemptEncryption=false`; `UIRequiresFullScreen`; Open In copies (not in-place). 1024 icon RGB no alpha. Play update already Android-only. Mac script `tool/build_ios_release.sh`. Guide [`IOS_APP_STORE.md`](IOS_APP_STORE.md).
- **Files:** `ios/Runner/Info.plist` · `ios/Runner/PrivacyInfo.xcprivacy` · `ios/Runner.xcodeproj/project.pbxproj` · `ios/ExportOptions.plist` · `tool/build_ios_release.sh` · `docs/IOS_APP_STORE.md`
- **Leftover:** Archive on Mac with Apple team; Connect privacy/screenshots; device smoke still blocks submit.

### 2026-08-18 — Theme chrome everywhere
- **Request:** Theme should apply everywhere in the app.
- **Done:** Convert/PDF/edit-photo tiles, crop handles, QR error seed, store-update CTA, shortcut customize avatars, onboarding wash, Edit photo tool rail now use `scheme.primary`. BottomAppBar + checkbox themes follow scheme. Catalog still stores type colors but UI ignores them.
- **Files:** `convert_tool_chrome.dart` · `converters_hub_screen.dart` · `pdf_tools_hub_screen.dart` · `image_formats_hub_screen.dart` · `image_crop_tool_screen.dart` · `store_update_dialog.dart` · `qr_reader_screen.dart` · `home_dashboard_screen.dart` · `onboarding_screen.dart` · `app_theme.dart`
- **Leftover:** Scanner camera black bg stays black on purpose.

### 2026-08-18 — Edit photo title spacing
- **Request:** Space under Edit photo title too tight.
- **Done:** Embedded header padding bottom 0→16; workspace top 8→12.
- **Files:** `image_formats_hub_screen.dart`
- **Leftover:** None.

### 2026-08-18 — Themes actually apply
- **Request:** All themes don’t apply; check thoroughly.
- **Done:** `fromSeed` remapped swatches so Sunset/Ocean looked like ScanMe. Now pin primary/secondary/tertiary to card colors + contrast `on*`. Tint surface. Home filters/shortcuts/convert primary CTA use `scheme.primary`. Hydrate prefs in `main` so async load can’t overwrite a tap. Tests: every builtin pins; widget tap Sunset recolors app.
- **Files:** `theme_spec.dart` · `main.dart` · `library_filter_bar.dart` · `home_dashboard_screen.dart` · `convert_result_panel.dart` · `test/theme_apply_test.dart` · docs
- **Leftover:** None (chrome pass 2026-08-18).

### 2026-08-18 — Theme studio Create CTA
- **Request:** Create button on Themes page very bad.
- **Done:** Dropped extended FAB (covered grid). In-flow `Create theme` card under filters + AppBar add. Empty copy no longer points at +.
- **Files:** `theme_studio_screen.dart` · `test/ui_functionality_test.dart` · `docs/UI_PAGES.md`
- **Leftover:** None.

### 2026-08-18 — Onboarding UI polish
- **Request:** Tour looked basic; better UI/UX.
- **Done:** Paper wash, step+progress, back, per-page product previews (scan FAB, review, library, tools, themes), chips, PrivacyBadge. No looping anim (tests settle).
- **Files:** `onboarding_screen.dart` · `docs/UI_PAGES.md`
- **Leftover:** Device look on first install.

### 2026-08-18 — First-run feature walkthrough
- **Request:** Setup wizard / feature tour for first open only.
- **Done:** Gated `ScanMeApp.home` (`loading` splash / 7-page `OnboardingScreen` / `MainShell`). Prefs `onboarding_done_v1`. Skip + Next + Get started. Replay from Me → About. Tests skip tour via `OnboardingController.completed()`; new tests for first launch, last page, replay.
- **Files:** `lib/core/onboarding.dart` · `lib/features/onboarding/onboarding_screen.dart` · `lib/main.dart` · `lib/features/settings/settings_screen.dart` · `test/widget_test.dart` · `test/ui_functionality_test.dart` · `docs/FEATURES.md` · `docs/UI_PAGES.md`
- **Leftover:** Device confirm first-install tour; Play still NOT READY.

### 2026-08-18 — Theme studio (dual/triple + custom)
- **Request:** Lots of presets, multiple types, combined dual/triple, own page, user-made presets.
- **Done:** `ThemeStudioScreen` — All/Single/Dual/Triple/Mine. 40+ builtins. Create/edit: 1–3 seeds + M3 style. Customs in prefs.
- **Files:** `theme_spec.dart` · `theme_studio_screen.dart` · `app_theme.dart` · `settings_screen.dart` · tests · docs
- **Leftover:** None.

### 2026-08-18 — Nav Photo + M3 theme presets
- **Request:** Replace Favorites with Edit photo; customize nav in Me; M3 theme presets.
- **Done:** Inner slots default Photo + Convert (also Favorites, PDF Tools). Me: Color presets (ScanMe/Ocean/Forest/Sunset/Grape/Slate/Ink) + Left/Right of Scan. `ColorScheme.fromSeed` for non-brand.
- **Files:** `nav_catalog.dart` · `main_shell_screen.dart` · `app_theme.dart` · `settings_screen.dart` · hubs embedded · tests · docs
- **Leftover:** Device check long nav labels.

### 2026-08-18 — xml `namespace` deprecation
- **Request:** Fix `deprecated_member_use` on `XmlNode.namespace` in converter service.
- **Done:** `findAllElements` / `getElement` now pass `namespaceUri: '*'`.
- **Files:** `document_converter_service.dart`
- **Leftover:** None.

### 2026-08-18 — Library card redesign
- **Request:** Favorite + ⋯ too big, don’t match the card. Redesign the whole card.
- **Done:** File tile: 52×70 thumb, bookmark chip on the photo, quiet ⋮ on the title row. Hairline + tighter type. Scan + convert share `LibraryFileCard`.
- **Files:** `document_card.dart` · `home_dashboard_screen.dart` · FEATURES · UI_PAGES
- **Leftover:** None.

### 2026-08-18 — Align Scan FAB
- **Request:** Scan button misaligned.
- **Done:** Dropped side-padded bar (notch used screen X, bar was inset). Full-width `CircularNotchedRectangle` so FAB and cradle share origin.
- **Files:** `main_shell_screen.dart` · UI_PAGES
- **Leftover:** None.

### 2026-08-18 — Unify navbar
- **Request:** Navbar should not be disjoint.
- **Done:** One rounded `BottomAppBar` with circular notch. Scan FAB docks in the cradle. Tabs still Home · Favorites · Convert · Me.
- **Files:** `main_shell_screen.dart` · FEATURES · UI_PAGES
- **Leftover:** Device check that notch lines up with FAB.

### 2026-08-18 — Dashboard spacing
- **Request:** Dashboard spacing looks weird.
- **Done:** Even 12/16 section rhythm. Shortcut tiles equal height. Empty sits under filters (no leftover-viewport cavern). SafeArea bottom off; list pads for nav/FAB only.
- **Files:** `home_dashboard_screen.dart` · `library_filter_bar.dart` · `app_ui.dart` · UI_PAGES
- **Leftover:** None.

### 2026-08-18 — Center Scan FAB + Favorites tab
- **Request:** Scan not in middle; add a nav option; elevated curved FAB detached from bar (like before).
- **Done:** Two pills **[Home · Favorites]** · **Scan** · **[Convert · Me]**. 64px glow FAB floats in the gap. Favorites tab = Home + starred filter.
- **Files:** `main_shell_screen.dart` · FEATURES · UI_PAGES
- **Leftover:** Device check on small widths.

### 2026-08-18 — Kill shortcut grid gap
- **Request:** Weird gap after two-line shortcuts.
- **Done:** Grid aspect leftover height gone. Wrap hugs icon + two-line labels.
- **Files:** `home_dashboard_screen.dart` · `library_filter_bar.dart`
- **Leftover:** None.

### 2026-08-18 — Raised Scan FAB in middle slot
- **Request:** Bring back previous middle Scan button look.
- **Done:** 60px glow circle sits raised in the Home | Scan | Convert | Me slot (not the small in-bar icon).
- **Files:** `main_shell_screen.dart` · UI_PAGES
- **Leftover:** Device check.

### 2026-08-18 — Favorite + tags on convert files
- **Request:** No way to favorite files or give them tags.
- **Done:** Convert ⋯ has Favorite + Tags (sidecar `converts/library.json`). Bookmark button on scan + convert cards. Favorites/Tags filters include converts. Tag chips on convert cards.
- **Files:** `convert_outputs_service.dart` · `providers.dart` · `library_actions.dart` · `tag_sheets.dart` · `document_card.dart` · `home_dashboard_screen.dart` · docs
- **Leftover:** Converts still not in Deleted (they delete immediately).

### 2026-08-18 — Shortcuts two-line wrap
- **Request:** Shortcuts should be double line.
- **Done:** 4-col wrap (two rows). Labels wrap after first space (`PDF Tools` → two lines).
- **Files:** `home_dashboard_screen.dart` · UI_PAGES
- **Leftover:** None.

### 2026-08-18 — Scan nav slot after Files gone
- **Request:** Middle scan button looks off after Files tab dropped.
- **Done:** Dropped 2+gap+1 FAB hole. Bar is four equal slots: **Home · Scan · Convert · Me**. Scan is in-bar circle + label, still **Scan Document** tooltip.
- **Files:** `main_shell_screen.dart` · UI_PAGES · this log
- **Leftover:** Device check on narrow phones.

### 2026-08-18 — Premium visual pass
- **Request:** UI too basic; raise premiumness.
- **Done:** Warm ivory paper + navy-black dark (not grey/OLED crush). Floating nav capsule + glowing Scan. Greeting header, pill search, horizontal squircle shortcuts, segmented filters, elevated cards (bigger thumbs). Convert/Me match display type. Soft layered shadows. UI tests PASS.
- **Files:** `app_theme.dart` · `app_ui.dart` · `document_card.dart` · `main_shell_screen.dart` · `home_dashboard_screen.dart` · `library_filter_bar.dart` · convert hub · settings · tests · docs
- **Leftover:** Device look in light/dark; Review/Export/Viewer not restyled as deeply as Home chrome.

### 2026-08-18 — Home library, drop Files tab
- **Request:** Drop Files tab; Home = shortcuts + friendlier filters; fix retake-all wipe; prune Open/watch.
- **Done:** Nav **Home · Convert · Me**. Library list + All/Favorites/Tags/Deleted on Home (full list, converts on All). Files shortcut + `home_screen.dart` gone. Retake-all imports new pages first; old files deleted only after success. Analyzer clean. UI/library tests PASS.
- **Files:** `main_shell_screen.dart` · `home_dashboard_screen.dart` · `library_filter_bar.dart` · `library_actions.dart` · `dashboard_tools.dart` · `editor_controller.dart` · `providers.dart` · tests · FEATURES · UI_PAGES
- **Leftover:** Device smoke (scan/PDF Tools/Open With); converts not on Favorites/Tags; folders UI paused.

### 2026-08-18 — PDF Tools Home shortcut
- **Request:** PDF Tools should appear in Home shortcuts.
- **Done:** Unpinned from “Convert tab only”. Catalog + defaults include **PDF Tools** (opens hub). Prefs `dashboard_tool_ids_v7`; v6 migrate inserts tile after Import. Tap → `PdfToolsHubScreen`.
- **Files:** `dashboard_tools.dart` · `home_dashboard_screen.dart` · docs
- **Leftover:** Hot restart to pick up prefs migrate.

### 2026-08-18 — Full QA pass (code + tests; no device)
- **Request:** End-to-end QA of all features + PDF Tools; fix real bugs; store-ready verdict.
- **Done:** Analyzer 0 errors. Fixed P0 QR loop + compress dropping pages; P1 mounted/empty-name/trash-filters/busy-pop/atomic meta/Open With dedup/iOS dest. About uses live version. PDF tool tests (merge 10p, split 12, extract). Widget tests aligned to Home dashboard. Report [`QA_REPORT.md`](QA_REPORT.md). **NOT READY** for stores.
- **Files:** PDF tools · QR · export · editor · storage · providers · Open With Android/iOS · settings · tests · `docs/QA_REPORT.md`
- **Leftover:** Device smoke Scan/PDF Tools/Open With; retake-all wipe on import fail; `/Rotate` flatten on copy.

### 2026-08-18 — Audit storage / library / nav / privacy
- **Request:** Real bugs in storage, library, trash, tags, favorites, export, editor, nav, permissions, Open With, QR, privacy (network).
- **Done:** Code audit only (no fixes). P0: QR sheet re-opens same code (back trap). P1: Open With double delivery; iOS `let dest` + dual URL handlers; empty export name; Files omits `converts/`; trash keeps favorites filter; back during `applyFilter`/`export`; retake-all deletes files first; corrupt `meta.json` hides docs.
- **Files:** `document_storage_service.dart` · `editor_controller.dart` · `export_screen.dart` · `home_screen.dart` · `home_dashboard_screen.dart` · `open_file_intent_bridge.dart` · `MainActivity.kt` · `OpenFileIntentHandler.swift` · `qr_reader_screen.dart`
- **Leftover:** Most P0/P1 items fixed in the Full QA pass; retake-all wipe and Files-omits-converts remain.

### 2026-08-18 — Dashboard Continue persists across tabs
- **Request:** Scanned/converted files vanish or get overwritten when leaving Home; should stay.
- **Done:** Shell `IndexedStack` keeps tabs mounted. Convert refresh no longer flashes empty. Home Continue uses local search (Files filters don't hide it). Recents cap 40. Convert outputs unique per-second (+ collision). Draft purge skips dirs <2h without meta.
- **Files:** `main_shell_screen.dart` · `home_dashboard_screen.dart` · `home_screen.dart` · `convert_outputs_service.dart` · `document_converter_service.dart` · `document_storage_service.dart` · tests · docs
- **Leftover:** Converts still not listed on Files tab (Continue + `converts/` folder).

### 2026-08-18 — PDF Tools hub
- **Request:** Offline PDF Tools (merge/split/reorder/delete/rotate/extract/PDF↔images/compress) inside Convert.
- **Done:** `PdfToolsService` (Syncfusion copy/rotate/compress + Printing raster for images). Hub Convert → PDF Tools. Shared page selector + result panel. Always new file. Tests in `pdf_tools_test.dart`. Dashboard convert shortcuts now open matching tool (not Edit photo).
- **Files:** `lib/features/pdf_tools/*` · `convert_catalog.dart` · `converters_hub_screen.dart` · `home_dashboard_screen.dart` · tests · docs
- **Leftover:** Device smoke each tool; PDF→images needs Printing.raster on device.

### 2026-08-18 — Ignore markdown in git
- **Request:** Add md files in gitignore.
- **Done:** `*.md` in `.gitignore`.
- **Files:** `.gitignore` · `PROJECT_LOG.md`
- **Leftover:** Already-tracked `.md` still in git until `git rm --cached '*.md'` (not run).

### 2026-08-18 — Fix EdgeToEdge Kotlin compile
- **Request:** `flutter run` fail — Unresolved reference `EdgeToEdge`.
- **Done:** Kotlin cannot import Java file-facade `EdgeToEdge`. Added `PlayEdgeToEdge.java` → `EdgeToEdge.enable()`. Explicit `androidx.activity:activity:1.10.1`.
- **Files:** `PlayEdgeToEdge.java` · `MainActivity.kt` · `build.gradle.kts` · `proguard-rules.pro` · `PROJECT_LOG.md`
- **Leftover:** Re-run `flutter run`.

### 2026-08-18 — Play edge-to-edge still flagged on +6
- **Request:** Do the 3 Play-visible edge-to-edge steps (enable name, keep R8, cutout ALWAYS).
- **Done:** `EdgeToEdge.enable(this)` (Java name Play looks for); re-apply cutout `ALWAYS` after Flutter `onCreate`/`onPostResume`; R8 `-keep` `androidx.activity.EdgeToEdge` + `MainActivity`; version `1.0.2+7`.
- **Files:** `MainActivity.kt` · `proguard-rules.pro` · `pubspec.yaml` · `PROJECT_LOG.md`
- **Leftover:** Flutter engine still contains guarded `setStatusBarColor` — Play may still list it. Rebuild AAB+7.

### 2026-08-17 — Play Console 3 recommendations
- **Request:** Fix edge-to-edge, deprecated bar/cutout APIs, BitmapFactory downsample (release 1.0.2).
- **Done:** Dropped theme `statusBarColor`/`navigationBarColor`; cutout `always`; Flutter bar colors removed (icons only); HEIC `BitmapFactory` uses `inSampleSize`; `compileSdk`/`targetSdk` ≥ 35; activity-ktx 1.10.1; version `1.0.2+6`.
- **Files:** `styles.xml` (+night) · `main.dart` · `MainActivity.kt` · `build.gradle.kts` · `pubspec.yaml` · `PROJECT_LOG.md`
- **Leftover:** Rebuild AAB+6 · upload · re-check Play (engine may still show some deprecated stacks).

### 2026-08-17 — Continue shows converter outputs
- **Request:** Dashboard Continue should list converter outputs with scanned PDFs.
- **Done:** List `converts/` via `ConvertOutputsService` + provider; merge with library docs by date (cap 8). Tap → FileViewer. More → Open / delete. Refresh after ConvertResultPanel + when Home tab active.
- **Files:** `convert_outputs_service.dart` · `home_dashboard_screen.dart` · `convert_result_panel.dart` · docs
- **Leftover:** Converts not yet in Files tab “View all”.

### 2026-08-17 — Open-with icons = app icon
- **Request:** File-manager Open-with picker icons don’t match ScanMe app icon.
- **Done:** All `activity-alias` icons → `@mipmap/ic_launcher` / round. Removed custom `ic_alias_*.xml`. Labels still name each tool.
- **Files:** `AndroidManifest.xml` · deleted `res/drawable/ic_alias_*.xml` · docs
- **Leftover:** Reinstall/update APK so launcher cache refreshes Open-with icons.

### 2026-08-17 — Fix misleading post-save popup
- **Request:** After PDF saved via file manager, popup still misleading.
- **Done:** Export SnackBar no longer says “pick a folder” after Save as already ran. Tracks `deviceSavedCount` → “saved to device” / “device copy skipped”. Viewer no longer shows raw `content://` URI.
- **Files:** `editor_controller.dart` · `export_screen.dart` · `viewer_screen.dart` · `UI_PAGES.md` · `PROJECT_LOG.md`
- **Leftover:** Device confirm export + viewer Save.

### 2026-08-17 — Play versionCode bump
- **Request:** Play Console: “Version code 1 has already been used.”
- **Done:** `pubspec` was `1.0.2` (no `+N` → Android versionCode **1**). Set `1.0.2+2` so versionCode = **2**.
- **Files:** `pubspec.yaml` · `PROJECT_LOG.md`
- **Leftover:** Rebuild AAB + re-upload.

### 2026-08-17 — Convert result Open/Save/Share UI
- **Request:** After successful conversion, Open/Save/Share look basic — use different UI for all converters.
- **Done:** Redesigned shared `ConvertResultPanel`: file chip + 3 equal action tiles (Open primary navy / Save / Share). Hits every convert + image tool path.
- **Files:** `convert_result_panel.dart` · `UI_PAGES.md` · `PROJECT_LOG.md`
- **Leftover:** Device glance light/dark.

### 2026-08-17 — Play Store listing copy
- **Request:** Play Store description with updated features.
- **Done:** Short (78) + full + What’s new in `docs/PLAY_LISTING.md`.
- **Files:** `docs/PLAY_LISTING.md` · `PROJECT_LOG.md`
- **Leftover:** Paste into Play Console; screenshots.

### 2026-08-17 — Soft Play Store update reminder
- **Request:** Caution when Play has update; Update now → store; Remind later → snooze.
- **Done:** `StoreUpdateReminder` + dialog on MainShell; Play Core check; snooze 3d prefs; open market/https. Not forced. Sideload silent.
- **Files:** `store_update_reminder.dart` · `store_update_dialog.dart` · `main_shell_screen.dart` · `store_update_reminder_test.dart` · pubspec · docs
- **Leftover:** Device smoke with Play-installed build when update exists.

### 2026-08-17 — All converters (docs + images) via dispatch
- **Request:** Not only images — all converters.
- **Done:** `test/all_converters_test.dart` — every document `ConvertToolId` + image tools via `runSimpleConvert`; every `IntentConvertKind.run`; catalog/meta/hints. Combined with prior matrices: **135 PASS · 1 SKIP**.
- **Files:** `test/all_converters_test.dart` · `PROJECT_LOG.md`
- **Leftover:** Real HEIC on device.

### 2026-08-17 — Converter matrix: test all variations
- **Request:** Test all converters / all variations (not sparse sample).
- **Done:** Full PNG/JPG/WebP/GIF × JPG/PNG/WebP/GIF (16); ImageTools source×format (16) + qualities + resize/compress/crop matrices; docs edge cases; materializePath; heicToJpeg by content. **79 PASS · 1 SKIP** (real HEIC).
- **Files:** `test/converter_test.dart` · `test/image_tools_test.dart` · `PROJECT_LOG.md`
- **Leftover:** Device real-HEIC smoke.

### 2026-08-17 — Full converter test matrix
- **Request:** Create/fetch fixtures; test all converters + variations.
- **Done:** Offline fixtures (`test/support/converter_fixtures.dart`); expanded `converter_test.dart` (docs + image formats); new `image_tools_test.dart`. HEIC skipped (platform codec). **30 PASS · 1 SKIP**.
- **Files:** `test/support/converter_fixtures.dart` · `test/converter_test.dart` · `test/image_tools_test.dart` · `PROJECT_LOG.md`
- **Leftover:** Device HEIC smoke.

### 2026-08-17 — Crop no default cover zoom
- **Request:** Why default zoom on crop photo viewer?
- **Done:** `interactive` auto `scaleToCover` blocked via `willUpdateScale` until ready; pinch still works.
- **Files:** `image_formats_hub_screen.dart` · `image_crop_tool_screen.dart` · `PROJECT_LOG.md`
- **Leftover:** —

### 2026-08-17 — Rename Images tile → Edit photo
- **Request:** Icon/name shouldn’t be “Images”.
- **Done:** Dashboard + Convert tool **Edit photo** (`photo_outlined`); section **Photo**.
- **Files:** `dashboard_tools.dart` · `convert_catalog.dart` · docs
- **Leftover:** Prefer different label? say so.

### 2026-08-17 — Images UI matches single-Apply model
- **Request:** UI should match one-action flow (not per-tool Include/buttons).
- **Done:** Removed Include switches; staged edit chips above one **Apply**; sections are settings only.
- **Files:** `image_formats_hub_screen.dart` · `UI_PAGES.md` · `FEATURES.md` · `PROJECT_LOG.md`
- **Leftover:** —

### 2026-08-17 — Single Apply for all Images ops
- **Request:** No per-tool Convert/Crop/Resize/Compress buttons — one action after staging ops on one photo.
- **Done:** Include switches · Will apply summary · one **Apply** CTA · pipeline crop→resize→convert→compress · Crop kept Offstage for bake from any tab.
- **Files:** `image_formats_hub_screen.dart` · `UI_PAGES.md` · `PROJECT_LOG.md`
- **Leftover:** Device smoke multi-op Apply.

### 2026-08-17 — Hide crop canvas after Apply
- **Request:** After crop, image/crop viewer still visible behind Ready.
- **Done:** Result ready → Expanded shows output preview (not Crop); hide Apply; **Edit again** clears result.
- **Files:** `image_formats_hub_screen.dart` · `PROJECT_LOG.md`
- **Leftover:** —

### 2026-08-17 — Empty “No photo yet” in image slot
- **Request:** No-photo placeholder also at bottom (same as preview).
- **Done:** One workspace empty+loaded; Expanded = empty preview or image; Choose image CTA bottom.
- **Files:** `image_formats_hub_screen.dart` · `UI_PAGES.md` · `PROJECT_LOG.md`
- **Leftover:** —

### 2026-08-17 — Images preview matches crop layout
- **Request:** Image preview at end of page like Crop — same for Convert/Resize/Compress (consistency).
- **Done:** One `_buildToolWorkspace` for all tools with photo: top controls · Expanded image · bottom CTA; empty state separate.
- **Files:** `image_formats_hub_screen.dart` · `UI_PAGES.md` · `PROJECT_LOG.md`
- **Leftover:** Device smoke all four tabs layout + crop pinch.

### 2026-08-17 — Fix crop pinch vs page scroll
- **Request:** Pinch flaky; scroll sometimes moves page.
- **Done:** Crop tab = full-height workspace (no ListView parent). `interactive` + `fixCropRect` for locked ratios (pinch/pan photo). Free keeps corner resize. Pointer lock + NeverScrollableScrollPhysics fallback.
- **Files:** `image_formats_hub_screen.dart`, `PROJECT_LOG.md`
- **Left:** Device smoke pinch on Crop.

### 2026-08-17 — Split Images options by tool
- **Request:** Resize no output format (Convert owns it); analyze actions as a whole.
- **Done:** **Convert** = format + quality. **Resize** = pixels only (preserve source format). **Crop** = frame/aspect. **Compress** = target KB. Removed Convert long-edge size (Resize job). Hint under Resize.
- **Files:** `image_formats_hub_screen.dart`, `image_resize_tool_screen.dart`, docs
- **Left:** Hot restart smoke each tab.

### 2026-08-17 — Crop pinch zoom
- **Request:** Finger zoom in/out on crop.
- **Done:** `Crop(interactive: true)` on Images crop panel + standalone crop screen (pinch zoom + pan).
- **Files:** `image_formats_hub_screen.dart`, `image_crop_tool_screen.dart`, `PROJECT_LOG.md`
- **Left:** Device smoke pinch on Crop tab.

### 2026-08-17 — Crop aspect + exact px
- **Request:** Crop options — different ratios or pixel by pixel.
- **Done:** Aspect chips: Free (pixel-by-pixel) · Original · 1:1 · 4:3 · 3:4 · 16:9 · 9:16 · Exact px (W×H lock + export resize). `CropController.aspectRatio` / `Crop.aspectRatio`.
- **Files:** `image_formats_hub_screen.dart`, `UI_PAGES.md`, `PROJECT_LOG.md`
- **Left:** Hot restart · try Free vs 1:1 vs Exact px.

### 2026-08-17 — Fix format showing as Image
- **Request:** In place of format saying Image.
- **Done:** Detect format from extension **or** file header bytes (JPEG/PNG/GIF/WebP/HEIC). Meta uses `_sourceFormat` always.
- **Files:** `image_formats_hub_screen.dart`, `PROJECT_LOG.md`
- **Left:** Hot restart · re-pick photo.

### 2026-08-17 — Show chosen image format
- **Request:** Also show chosen image’s format.
- **Done:** Meta line = `JPEG · W×H · size` (from path ext; jpeg→JPEG, etc.).
- **Files:** `image_formats_hub_screen.dart`, `UI_PAGES.md`, `PROJECT_LOG.md`
- **Left:** None.

### 2026-08-17 — Images icon tool rail
- **Request:** Choose different UI than segmented tabs — more user friendly.
- **Done:** Replaced SegmentedButton with **Edit with** icon rail (circle icon + label per tool). Preview-first empty state. Short blurb under selection. Same-screen panels unchanged.
- **Files:** `image_formats_hub_screen.dart`, `UI_PAGES.md`, `FEATURES.md`, `PROJECT_LOG.md`
- **Left:** Hot restart visual check.

### 2026-08-17 — Same-screen Images tools
- **Request:** Implement same-screen Images plan (switch tools without leaving).
- **Done:** Persistent Convert/Crop/Resize/Compress segmented tabs; all panels inline (crop embedded ~300px). Shared preview + result. Open-with crop/resize/compress → Images + `initialAction`. No All tools / job tiles / push for in-app flow.
- **Files:** `image_formats_hub_screen.dart`, `open_file_intent_bridge.dart`, `UI_PAGES.md`, `FEATURES.md`, `PROJECT_LOG.md`
- **Left:** Device smoke tabs + Open-with.

### 2026-08-17 — Images chosen-photo preview
- **Request:** Chosen image should have a preview.
- **Done:** Preview above meta (16:10, cover). HEIC/HEIF via `ImageCodecBridge` → JPEG bytes.
- **Files:** `image_formats_hub_screen.dart`, `UI_PAGES.md`, `PROJECT_LOG.md`
- **Left:** None.

### 2026-08-17 — Friendlier Images job tiles
- **Request:** Action dropdown less user friendly — use other way.
- **Done:** Replaced Action dropdown with **What do you want to do?** job tiles (Convert · Crop · Resize · Compress). Convert opens format/size/quality; others open dedicated tools. AppBar **All tools** to go back.
- **Files:** `image_formats_hub_screen.dart`, `UI_PAGES.md`, `FEATURES.md`, `PROJECT_LOG.md`
- **Left:** Hot restart visual check.

### 2026-08-17 — Combine convert + edit images
- **Request:** Combine convert and edit images.
- **Done:** One **Images** hub tile/screen. Action dropdown: Convert format · Crop · Exact resize · Compress. Removed Edit hub + section. Prefs `v6`; defaults Images; migrate editImages → imageFormats. Deleted `image_edit_hub_screen.dart`.
- **Files:** `image_formats_hub_screen.dart`, `convert_catalog.dart`, `converters_hub_screen.dart`, `dashboard_tools.dart`, `home_dashboard_screen.dart`, docs
- **Left:** Hot restart Convert · Images.

### 2026-08-17 — Tighten convert-image dropdown gaps
- **Request:** Odd gaps between dropdown options.
- **Done:** Replaced FormField floating-label stack with compact 48px label+dropdown rows + hairline dividers.
- **Files:** `image_formats_hub_screen.dart`, `PROJECT_LOG.md`
- **Left:** Hot restart visual check.

### 2026-08-17 — Image convert dropdowns
- **Request:** Image conversions — one dropdown UI for format/size/etc instead of many options.
- **Done:** Replaced stacked format list with single **Convert image** screen: Convert to · Size · Quality dropdowns. `ImageToolsService.convertImage` (+ GIF encode). Open-with format aliases open same screen prefilled. Edit hub (crop/resize/compress) unchanged.
- **Files:** `image_formats_hub_screen.dart`, `image_tools_service.dart`, `convert_catalog.dart`, `open_file_intent_bridge.dart`, `dashboard_tools.dart`, `UI_PAGES.md`, `FEATURES.md`, `PROJECT_LOG.md`
- **Left:** Device smoke Convert image + Open-with to JPG.

### 2026-08-17 — Feature catalog MD
- **Request:** Give every functionality of app in a md file.
- **Done:** New [`FEATURES.md`](FEATURES.md) — full capability inventory (scan/edit/library/convert/open-with/QR/settings/privacy + paused items). Linked from PROJECT_LOG.
- **Files:** `docs/FEATURES.md`, `PROJECT_LOG.md`, `UI_PAGES.md`
- **Left:** None.

### 2026-08-17 — Fix file_picker 12 Uri break
- **Request:** Build fail (`device_save_service` · `Uri.isEmpty` / return type).
- **Done:** Adapt `FilePicker.saveFile` → `Uri?` (v12): null cancel; `file` → path else `toString()`; pass `mimeType`.
- **Files:** `device_save_service.dart`, `PROJECT_LOG.md`
- **Left:** Re-run `flutter run`.

### 2026-08-16 — Back buttons on pushed pages
- **Request:** Add back buttons everywhere needed.
- **Done:** `AppPageRoute` → `MaterialPageRoute` + transitions; `scanMeAppBarLeading` / `AppBarBackButton` on Scan, QR, Review, Export, Viewer, File viewer, Convert/image tools+hubs, Settings (non-embedded), Files header when pushed. Tab roots omit leading. Review empty → “Go back” CTA.
- **Files:** `app_transitions.dart`, `app_ui.dart`, scan/review/export/viewer/file_viewer/qr/converters/settings/`home_screen.dart`, `UI_PAGES.md`, `PROJECT_LOG.md`
- **Left:** Device smoke — push each stack, confirm back visible + pops.

### 2026-08-16 — Home theme toggle
- **Request:** Replace settings button with dark/light mode toggle.
- **Done:** Home header `AppCircleIconButton` toggles light↔dark via `themeModeProvider`. Settings remains on Me tab.
- **Files:** `home_dashboard_screen.dart`, `main_shell_screen.dart`, `UI_PAGES.md`, `PROJECT_LOG.md`
- **Left:** None.

### 2026-08-16 — Compact Home (drop Start card)
- **Request:** Remove Scan Document big card + children; make dashboard more compact.
- **Done:** Removed Start card. Tighter header/search/spacing. Import moved to shortcut defaults. Prefs `v5`. Scan = FAB · Convert = tab.
- **Files:** `home_dashboard_screen.dart`, `dashboard_tools.dart`, `UI_PAGES.md`, `PROJECT_LOG.md`
- **Left:** None.

### 2026-08-16 — Shortcuts as tiles
- **Request:** Shortcuts should be tiles, not scrollable bar.
- **Done:** Replaced horizontal chip strip with non-scrollable 4-col tile grid (circle icon + label · Add dashed).
- **Files:** `home_dashboard_screen.dart`, `UI_PAGES.md`, `PROJECT_LOG.md`
- **Left:** None.

### 2026-08-16 — Home dashboard redesign
- **Request:** Rethink / redesign dashboard (plan).
- **Done:** Single **Start** card (Scan primary · Import/Convert secondary). **Shortcuts** horizontal strip (defaults QR · Favorites · Edit images). **Continue** replaces Recents. Prefs `dashboard_tool_ids_v4`; migrate drops Files once. Customize copy updated.
- **Files:** `home_dashboard_screen.dart`, `dashboard_tools.dart`, `UI_PAGES.md`, `PROJECT_LOG.md`
- **Left:** Device smoke light/dark + shortcut customize.

### 2026-08-16 — Align PDF→DOCX UI
- **Request:** Align the UI as well (for PDF to DOCX).
- **Done:** File viewer DOCX text preview (same chrome as TXT/PPTX) · result label `.docx` · distinct hub/dashboard colors/icons vs DOCX→PDF · docs.
- **Files:** `file_viewer_screen.dart`, `document_converter_service.dart`, `convert_catalog.dart`, `dashboard_tools.dart`, `converter_test.dart`, `UI_PAGES.md`, `PROJECT_LOG.md`
- **Left:** None.

### 2026-08-16 — Add PDF to DOCX
- **Request:** Also add PDF to DOCX.
- **Done:** Offline `pdfToDocx` (Syncfusion text extract → minimal OOXML). Convert hub + dashboard shortcut + Android Open-with alias. No OCR / layout fidelity (same limits as PDF→txt).
- **Files:** `document_converter_service.dart`, `convert_catalog.dart`, `dashboard_tools.dart`, `home_dashboard_screen.dart`, `intent_convert_screen.dart`, `open_file_intent_bridge.dart`, AndroidManifest + `ic_alias_pdf_to_docx.xml`, `MainActivity.kt`, `converter_test.dart`, docs
- **Left:** Device smoke Open-with + open result in Word.

### 2026-08-16 — Remove dashboard Scan CTA redundancy
- **Request:** Still redundancy about scan on dashboard.
- **Done:** Empty Recents no longer repeats **Scan Document** / **Import Images** CTAs (hero + secondary row already cover those). Empty copy only points to recents area.
- **Files:** `home_dashboard_screen.dart`, `UI_PAGES.md`, `PROJECT_LOG.md`
- **Left:** None.

### 2026-08-16 — Complete UI/UX transformation pass
- **Request:** Full ScanMe UI/UX transformation (design system · progressive disclosure · a11y · consistency).
- **Done:** Closed audit gaps — `AppSearchBar` / `AppErrorState` / `AppLoadingState` / `AppProgressCard` / `AppButton.secondary` / icon Semantics; Home+Files search unified; QR Open-link primary for URLs; image export Small/Balanced/High + hints; convert benefit blurbs; Settings `SectionHeader`; Recents/Quick tools headers; FAB `onPrimary`; Favorite label; trash copy; spacing tokens; `UI_PAGES` synced. Business logic / scanners / storage untouched.
- **Files:** `app_ui.dart`, `app_theme.dart`, `home_*`, `main_shell`, `export_screen`, `qr_reader`, `settings`, `document_card`, `library_models`, `convert_catalog`, `UI_PAGES.md`, `PROJECT_LOG.md`
- **Left:** Device smoke light/dark + large text.

### 2026-08-16 — UX checklist audit (gaps only)
- **Request:** Audit Flutter UX checklist; gaps with file:line; prioritize P0–P2; max 40.
- **Done:** Gaps-only report (then implemented in transformation pass above).
- **Files:** audit only + this log
- **Left:** None.

### 2026-08-16 — UI docs: one file
- **Request:** Don’t use separate md in `ui/` — put UI in one md.
- **Done:** Merged all `docs/ui/*.md` into [`UI_PAGES.md`](UI_PAGES.md); deleted `docs/ui/`. PROJECT_LOG links point only to `UI_PAGES.md`.
- **Files:** `docs/UI_PAGES.md`, `docs/PROJECT_LOG.md` (removed `docs/ui/`)
- **Left:** None.

### 2026-08-16 — Add QR reader
- **Request:** Also add a QR reader.
- **Done:** `QrReaderScreen` via `mobile_scanner` + gallery analyze. Result sheet Copy / Open link / Share. Dashboard tool `qrReader` in defaults (Files · Favorites · QR). Android CAMERA + http(s) queries; iOS camera/photo strings + `LSApplicationQueriesSchemes`.
- **Files:** `qr_reader_screen.dart`, `dashboard_tools.dart`, `home_dashboard_screen.dart`, `pubspec.yaml`, AndroidManifest, Info.plist, `docs/ui/qr-reader.md`, PROJECT_LOG / UI_PAGES / README
- **Left:** Device smoke (permission · torch · URL open · photo scan).

### 2026-08-16 — Fix dashboard tool redundancy
- **Request:** Dashboard showed same actions multiple times.
- **Done:** Scan / Import / Convert stay only in hero + secondary row. Quick tools defaults = Files · Favorites · Tags. Pinned ids stripped from grid + customize catalog. Prefs `v3` + sanitize migration.
- **Files:** `dashboard_tools.dart`, `home_dashboard_screen.dart`, docs
- **Left:** None.

### 2026-08-16 — Stack image format converters
- **Request:** Image type conversions also stacked into one.
- **Done:** One Convert hub + dashboard tile **Image formats** → `ImageFormatsHubScreen` lists JPG/PNG/WebP/GIF/HEIC. Legacy dashboard format tiles migrate. Open-with still deep-links each convert.
- **Files:** `image_formats_hub_screen.dart`, `convert_catalog.dart`, `converters_hub_screen.dart`, `dashboard_tools.dart`, `home_dashboard_screen.dart`, docs
- **Left:** None.

### 2026-08-16 — Stack Edit images tools
- **Request:** Edit images tools stacked into one.
- **Done:** One Convert hub + dashboard tile **Edit images** → `ImageEditHubScreen` lists Crop / Resize / Compress. Legacy dashboard Crop/Resize/Compress prefs migrate to Edit images. Open-with still deep-links each tool.
- **Files:** `image_edit_hub_screen.dart`, `convert_catalog.dart`, `converters_hub_screen.dart`, `dashboard_tools.dart`, `home_dashboard_screen.dart`, docs
- **Left:** None.

### 2026-08-16 — Refresh all UI page docs
- **Request:** Update every page doc accordingly (post UX upgrade).
- **Done:** Rewrote all `docs/ui/*.md` + `UI_PAGES.md` index to match current Home hero, Export disclosure, Viewer calm chrome, Review More, Trash copy, convert sections, brand tokens, skeletons, sheets rules.
- **Files:** `docs/ui/*`, `docs/UI_PAGES.md`, `docs/PROJECT_LOG.md`
- **Left:** None (docs).

### 2026-08-16 — UI/UX upgrade remaining (phases 6–8)
- **Request:** Do all remaining UX upgrade work.
- **Done:** Viewer: Favorite+Share primary, Print/Save in More, page prev/next, skeleton load. Review: More menu for Retake all; Delete disabled on 1 page. Scan: page # on thumbs, friendlier busy/errors. Document cards: compact meta, 48px More. `AppListSkeleton`. File viewer empty/error states. Nav semantics + 56h. Trash permanent copy “cannot be undone.” Docs updated.
- **Files:** `viewer_screen.dart`, `review_screen.dart`, `scan_capture_screen.dart`, `document_card.dart`, `app_ui.dart`, `file_viewer_screen.dart`, `main_shell_screen.dart`, `home_*.dart`, `docs/ui/*`, PROJECT_LOG
- **Left:** Device smoke full journeys A–E.

### 2026-08-16 — Complete UI/UX upgrade (phase 1–5 core)
- **Request:** Run ScanMe Complete UI-UX Upgrade Prompt (preserve features; redesign UX).
- **Done:** Brand tokens navy `#1B3A4B` + accent `#2F6F7E`, radii 12–24, readable type. Home: brand header, Scan Document hero, Import/Convert secondary, Quick tools. FAB semantic label. Export: simple Save as + More options + quality hints. Convert: compact hero, friendlier catalog, result panel success. Settings Storage + privacy badge. Files Trash “Recently deleted”. Enhance filter descriptions. Friendly errors.
- **Files:** `app_theme.dart`, `home_dashboard_screen.dart`, `main_shell_screen.dart`, `export_screen.dart`, convert chrome/catalog/result, `settings_screen.dart`, `home_screen.dart`, `page_filter.dart`, `review_screen.dart`, docs
- **Left:** Phase 6–8 polish (viewer chrome, skeleton loaders, a11y audit, full consistency pass); device smoke.

### 2026-08-16 — Per-page UI docs
- **Request:** Every page UI details in separate md files.
- **Done:** Split into `docs/ui/` — one md per screen + sheets + brand/motion; `UI_PAGES.md` now index; PROJECT_LOG link updated.
- **Files:** `docs/ui/*.md`, `docs/UI_PAGES.md`, `docs/PROJECT_LOG.md`
- **Left:** None.

### 2026-08-16 — New converter UI/icon parity
- **Request:** New converters match old ones — UI, icons, open-with, dashboard treatment.
- **Done:** Shared `ConvertToolHero` + CTA styles on convert / intent / crop / resize / compress. Catalog steps + progress labels. Dashboard + hub deep links. Android open-with aliases + drawables for DOCX/XLSX/WebP/GIF/HEIC/crop/resize/compress. iOS Info.plist Word/Excel/HEIC/WebP/GIF types. Intent bridge routes edit tools with `initialPath`.
- **Files:** `convert_tool_chrome.dart`, tool screens, `convert_catalog.dart`, `open_file_intent_bridge.dart`, `AndroidManifest.xml`, `ic_alias_*.xml`, `MainActivity.kt`, `Info.plist`, `dashboard_tools.dart`, docs
- **Left:** Device reinstall to refresh Open-with list; smoke HEIC/DOCX/crop.

### 2026-08-16 — Filter tap shows old look
- **Request:** Filters don’t change after tap; stay on previous filter.
- **Done:** Processed JPEGs now written per-filter (`pageId_filter.jpg`); evict `FileImage` cache; Review PhotoView/thumb keys include filter wire. Choice chips always fire apply.
- **Files:** `document_storage_service.dart`, `editor_controller.dart`, `review_screen.dart`, docs
- **Left:** None.

### 2026-08-16 — More converters + image tools
- **Request:** Add JPG/PNG/WebP/HEIC/GIF, DOCX, XLSX, crop, pixel resize, size reducer; good UI; research offline options.
- **Done:** Sectioned Convert hub (Documents · Image formats · Resize & edit). New tools: Any→JPG/PNG/WebP/GIF, HEIC→JPG (native), DOCX→PDF, XLSX→CSV/PDF, Crop (`crop_your_image`), Resize, Compress. Dedicated tool screens + result panel. HEIC via `app.atl.scanme/image_codec`.
- **Files:** `convert_catalog.dart`, `converters_hub_screen.dart`, tool screens, `document_converter_service.dart`, `image_tools_service.dart`, Android/iOS codec, `dashboard_tools.dart`, docs
- **Left:** Device smoke HEIC / DOCX / crop; DOCX/XLSX are text/table fidelity (not full layout).

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

## Play Console recommendations (code response · 1.0.2+7)

| # | Flag | Status | What we did |
|---|------|--------|-------------|
| 1 | Edge-to-edge (SDK 35) | Done | Java `EdgeToEdge.enable(this)` before `super.onCreate`; R8 keep so Play sees the name; `WindowCompat.setDecorFitsSystemWindows(false)` |
| 2 | Deprecated bar/cutout APIs | App path done | Theme has no bar colors; cutout **ALWAYS** re-applied after Flutter `onCreate`/`onPostResume`. Flutter engine still has guarded `setStatusBarColor` in dex |
| 3 | BitmapFactory downsample | Done (+6) | HEIC `inSampleSize` |

> Play may still list Flutter-engine stacks. That is engine bytecode, not ScanMe theme.

## Play Console recommendations (code response · 1.0.2+6)

| # | Flag | Status | What we did |
|---|------|--------|-------------|
| 1 | Edge-to-edge (SDK 35) | Done | `enableEdgeToEdge()`; `SystemUiMode.edgeToEdge`; `targetSdk`/`compileSdk` ≥ 35; SafeArea on Home/Files; Scaffold nav inset |
| 2 | Deprecated bar/cutout APIs | Done | Removed theme `statusBarColor` / `navigationBarColor`; cutout `always` (not `shortEdges`); Flutter no longer sets bar colors (icons only) |
| 3 | BitmapFactory downsample | Done | HEIC path: `inJustDecodeBounds` + `inSampleSize` (max long edge 4096). Dart thumbs still use `cacheWidth` / `decodeDownsampled` |
| — | activity-ktx | Bumped | `1.10.1` |

> Play may still mention obfuscated stacks inside Flutter engine / GMS until those libs stop calling deprecated APIs; our app code no longer sets them.

---

## Play Console recommendations (historical · 1.0.0+2)

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
| C1 | iOS scanner MethodChannel may not register (UIScene / nil window) | iOS scan broken | **Code-fixed** (`FlutterImplicitEngineDelegate` + Scene-safe `topViewController`) — device smoke still due |
| C2 | `editorSessionProvider.autoDispose` mid-scan wipe | Flaky empty Review | **Code-fixed** (plain `StateNotifierProvider`, no autoDispose) |
| H1 | Cancel leaves orphan `documents/<id>/` | Disk leak | **Verify** (draft delete exists; cancel path on device) |
| H2 | Import errors uncaught after scan | Crash / stuck | **Verify** |
| H3 | Viewer `PageController` recreated in `build` | Leak / jump | **Code-fixed** (created in `_load`, disposed) |
| H4 | Retake-all new id abandons old files | Disk leak | **Code-fixed** (`replaceAllFromScanPaths` reuses id) |

Medium/Low (export re-encode, rename vs filenames, Google Fonts network, GMS check, etc.) — re-open from git history / prior audit if needed.

---

## Key paths (quick)

| Concern | Path |
|---------|------|
| Home | `lib/features/home/home_dashboard_screen.dart` |
| Theme | `lib/core/theme/app_theme.dart` |
| Compression | `lib/core/services/scan_compression.dart` |
| MainActivity | `android/app/src/main/kotlin/app/atl/scanme/MainActivity.kt` |
| Manifest | `android/app/src/main/AndroidManifest.xml` |
| ProGuard | `android/app/proguard-rules.pro` |
| Privacy HTML | `privacy_policy.html` |
| Dual-OS bootstrap | `tool/bootstrap.sh` |

---

## Doc index

| File | Role |
|------|------|
| **`PROJECT_LOG.md`** | **Canonical living log** (this file) |
| [`PROPOSAL_FORM_BW_CAMSCAN_SPEC.md`](PROPOSAL_FORM_BW_CAMSCAN_SPEC.md) | CamScan B&W constants/pipeline (every page) |
| [`UI_PAGES.md`](UI_PAGES.md) | All screens UI detail (single file) |
| [`PLAY_LISTING.md`](PLAY_LISTING.md) | Short/full Play Store description + What’s new |
| [`PLAY_STORE.md`](PLAY_STORE.md) | Stub → Play section above |
| [`PLAY_CONSOLE_FIXES.md`](PLAY_CONSOLE_FIXES.md) | Stub → Play Console section above |
| [`TEST_REPORT.md`](TEST_REPORT.md) | Stub → Test section above |
| [`AUDIT_REPORT.md`](AUDIT_REPORT.md) | Stub → Audit snapshot above |
