# ScanMe — UI pages reference

> Living status / task log: [`PROJECT_LOG.md`](PROJECT_LOG.md)  
> Capability list (what app does): [`FEATURES.md`](FEATURES.md)  
> **Single file** for every in-app page’s UI detail (no per-screen splits).  
> Last aligned: **2026-08-18** Premium visual pass (warm paper · floating nav · elevated cards).

**Brand:** ScanMe / Apptriangle · Plus Jakarta Sans · navy `#1B3A4B` · accent `#2A7A86` · warm paper `#F4F0EA` · light / dark / system

## Navigation map

```
First launch → Onboarding (7 pages) → MainShell
Replay: Me → About → Replay tutorial

MainShell (bottom nav)
├── Home — brand · search · Shortcuts · library
├── Photo (default inner) — Edit photo; slot customizable
├── Scan FAB — elevated in the bar’s center notch → capture
├── Convert (default inner) — Documents · Photo → Edit photo · PDF Tools
└── Me — Appearance · Navigation · Storage · Tags · About (Replay tutorial)

Open-with (OS) → Intent convert | Crop / Resize / Compress | File viewer
Home Shortcuts → Import · QR · Favorites · Edit photo · PDF Tools
```

## Contents

0. [First-run walkthrough](#first-run-walkthrough)
1. [Main shell](#main-shell)
2. [Home dashboard](#home-dashboard)
3. [Library on Home](#library-on-home)
4. [Settings / Me](#settings-me)
5. [System document scanner](#system-document-scanner)
6. [Scan capture](#scan-capture)
7. [Review / editor](#review-editor)
8. [Save document (Export)](#save-document-export)
9. [Document viewer](#document-viewer)
10. [Convert hub](#convert-hub)
11. [Convert tool](#convert-tool)
12. [Intent convert (Open with)](#intent-convert-open-with)
13. [Edit photo (convert · crop · resize · compress)](#edit-photo-convert--crop--resize--compress)
14. [Crop image](#crop-image)
15. [Resize pixels](#resize-pixels)
16. [Reduce file size](#reduce-file-size)
17. [File viewer](#file-viewer)
18. [QR reader](#qr-reader)
19. [Sheets, dialogs, overlays](#sheets-dialogs-overlays)
20. [Global brand, motion, data model](#global-brand-motion-data-model)

## System UIs (not Flutter screens)

| UI | Platform | When |
|----|----------|------|
| Google ML Kit Document Scanner | Android | Capture / retake |
| VisionKit document camera | iOS | Capture / retake |
| System photo / gallery picker | Both | Import Images |
| File picker | Both | Convert tools |
| System share sheet | Both | Share |
| Native print dialog | Both | Viewer → More → Print |
| System Save as | Both | Save to device |

## Screen ↔ source

| Screen | Dart |
|--------|------|
| Onboarding | `lib/features/onboarding/onboarding_screen.dart` |
| Main shell | `lib/features/home/main_shell_screen.dart` |
| Home dashboard | `lib/features/home/home_dashboard_screen.dart` |
| Library actions | `lib/features/home/library_actions.dart` · `library_filter_bar.dart` |
| Settings | `lib/features/settings/settings_screen.dart` |
| Scan capture | `lib/features/scanner/scan_capture_screen.dart` |
| Review | `lib/features/document_editor/review_screen.dart` |
| Export | `lib/features/export/export_screen.dart` |
| Viewer | `lib/features/viewer/viewer_screen.dart` |
| Convert hub | `lib/features/converters/converters_hub_screen.dart` |
| Convert tool | `lib/features/converters/convert_tool_screen.dart` |
| Intent convert | `lib/features/converters/intent_convert_screen.dart` |
| Crop / Resize / Compress | `lib/features/converters/image_*_tool_screen.dart` |
| Images tool | `lib/features/converters/image_formats_hub_screen.dart` | → **Edit photo** |
| File viewer | `lib/features/file_viewer/file_viewer_screen.dart` |
| QR reader | `lib/features/qr/qr_reader_screen.dart` |
| Shared UI | `lib/shared/widgets/app_ui.dart`, `document_card.dart`, `app_transitions.dart` |
| Theme | `lib/core/theme/app_theme.dart` |

---

## First-run walkthrough

**Class:** `OnboardingScreen`  
**File:** `lib/features/onboarding/onboarding_screen.dart`  
**Entry:** `ScanMeApp.home` when prefs `onboarding_done_v1` is unset; **Me → Replay tutorial** (`replay: true`)

### Purpose

One-time feature tour before the shell. Skip or finish writes the prefs flag. Does not start Scan.

### Chrome

Warm paper wash · step `n of 7` + back · Skip/Close · thin progress bar · per-page UI preview (nav FAB, library, tools, themes) · chips · **Next** / **Get started**

### Pages

1. Welcome / privacy (offline, no account)
2. Scan FAB
3. Review & save (enhance, PDF/images, watermark)
4. Home library (search, shortcuts, filters)
5. Convert · Edit photo · PDF Tools · QR · Open with
6. Me (themes, nav slots)
7. Ready

Replay pushes over Me; Close / Get started pops.

---

## Main shell

**Class:** `MainShellScreen`  
**File:** `lib/features/home/main_shell_screen.dart`  
**Entry:** `ScanMeApp.home` after onboarding done

### Purpose

App chrome: one notched bar + Scan FAB. Hosts Home, inner slots, Convert, Me, Edit photo, PDF Tools.

### Layout

- **AppBar:** none (tabs own headers)
- **Body:** `IndexedStack` (tabs stay mounted):
  1. Home dashboard (also used if a slot is Favorites)
  2. Convert hub (`ConvertersHubScreen` embedded)
  3. Me (`SettingsScreen` embedded)
  4. Edit photo (`ImageFormatsHubScreen` embedded)
  5. PDF Tools (`PdfToolsHubScreen` embedded)
- **Nav:** one full-width `BottomAppBar` with a circular notch  
  **Home · [inner] · [Scan FAB] · [inner] · Me**
  - Defaults: **Home · Photo · Scan · Convert · Me**
  - Inner slots: Edit photo · Convert · Favorites · PDF Tools (Me → Navigation)
  - Scan is a 64px elevated circle docked in the notch
  - Tooltip / semantics: **Scan Document**
  - Color: `ColorScheme.primary` (follows theme preset)

### Interactions

- Tab switch unfocuses keyboard
- Tabs stay in memory (`IndexedStack`) — no page-slide
- `resizeToAvoidBottomInset: false`
- **Soft update reminder (Android):** after first frame, if Play reports an update and snooze expired → dialog **Update available** · **Remind later** (3 days) · **Update now** (opens Play Store listing). Not forced. Silent if sideload / no Play update.

---

## Home dashboard

**Class:** `HomeDashboardScreen`  
**File:** `lib/features/home/home_dashboard_screen.dart`  
**Entry:** Shell tab 0

### Purpose

Compact home: find docs fast · shortcuts · full library. Scan = FAB · Convert = Convert tab.

### Layout (top → bottom)

1. **Header** — greeting · **ScanMe** (display) · **light/dark toggle**
2. **Search** — pill · soft shadow · filters list in place (hidden in Deleted)
3. **Shortcuts** — 4-col wrap, equal-height tiles (two-line labels). Defaults: Import · PDF Tools · QR · Favorites · Edit photo · Add.
4. **Filter bar** — segmented All · Favorites · Tags · Deleted + sort. Tags wrap opens immediately.
5. **Library list** — file tiles: thumb · title · meta. Bookmark on thumb. Quiet ⋮. Converts included.

Prefs key `dashboard_tool_ids_v7`.

### Empty / load / error

| State | UI |
|-------|-----|
| Loading | `AppListSkeleton` |
| No documents | “Nothing here yet” |
| Favorites empty | “No favorites yet” |
| Tag miss | “No documents with this tag” |
| Deleted empty | “Nothing in Trash” · Back to library |
| Search miss | “No documents found” |
| Load error | Try again |

### Sheets

- Customize Shortcuts (Reset · tap add/remove)
- Card ⋯: Open · Favorite · Tags · Rename · Share · Move to Trash
- Convert ⋯: Open · Favorite · Tags · Remove
- Bookmark on each card thumbnail (not Deleted)
- Deleted ⋯: Restore · Delete permanently

### Persistence

Shortcut ids: `dashboard_tool_ids_v7`. Defaults: Import · PDF Tools · QR reader · Favorites · Edit photo. Sanitize drops leftover Files tiles.

---

## Library on Home

Library UI is the Home list + `LibraryFilterBar` + `library_actions.dart`. Former `HomeScreen` (Files tab) removed.

### Document card

- Thumb (Hero) · bookmark on the photo · name (2 lines)  
- Meta: `N pages · PDF|Images · Updated today`  
- Up to 2 tag chips · quiet **⋮** on the title row

### Actions sheets

Open first · Trash last · permanent delete confirms “cannot be undone.”

---

## Settings / Me

**Class:** `SettingsScreen`  
**File:** `lib/features/settings/settings_screen.dart`  
**Entry:** Shell **Me** tab

### Purpose

Calm product settings — not a developer dump.

### Chrome

| Mode | Header |
|------|--------|
| Embedded | In-body **Me** |
| Push | AppBar **Settings** |

### Sections

#### Appearance

System · Light · Dark (radio rows in card)

**Themes** — opens Theme studio. Current preset name on the tile.

### Theme studio

**Class:** `ThemeStudioScreen`  
**File:** `lib/features/settings/theme_studio_screen.dart`

Filter: All · Single · Dual · Triple · Mine. **Create theme** row under filters (AppBar + as well). Grid of swatch cards.

- Single / Dual / Triple seeds + M3 style (Tonal · Vibrant · Expressive · Neutral · Mono · Rainbow)
- Tap applies live: `ColorScheme.primary/secondary/tertiary` pinned to card swatches. ScanMe brand scheme is hand-tuned.
- Custom: name, 1–3 colors, style, live preview. Long-press custom card → Edit / Delete. Max 30. Local prefs.

#### Navigation

Home / Scan / Me are fixed. Inner slots:

- **Left of Scan** (default Edit photo)
- **Right of Scan** (default Convert)

Choices: Edit photo · Convert · Favorites · PDF Tools. Duplicate dest blocked.

#### Storage

**Trash retention** — “Recently deleted documents are kept for N days…”  
Dialog: 7 / 14 / 30 / 60 / 90 days (default 30)

#### Tags

Color dot + name · tap edit · long-press delete · **Add tag**  
Seeded: Urgent · Work · Personal · Receipt · ID · Finance

#### About

ScanMe · Apptriangle · live version  
**PrivacyBadge:** “Stored privately on this device · No account required”  
**Replay tutorial** — pushes `OnboardingScreen(replay: true)`

---

## System document scanner

**Not a Flutter screen** — Google / Apple UI.

**Triggered by:** Scan **Add page** · Review retake / retake-all · auto-open on new scan

### App-controlled behavior

| Case | Limit |
|------|--------|
| Add / retake one | Android ML Kit `pageLimit: 1` |
| Retake all | Higher limit allowed |

Returns JPEG path(s) → draft · **CamScan B&W on new pages by default**.

### Platforms

| OS | API |
|----|-----|
| Android | ML Kit Document Scanner |
| iOS | VisionKit |

Native shutter / crop strings are platform-owned.

---

## Scan capture

**Class:** `ScanCaptureScreen`  
**File:** `lib/features/scanner/scan_capture_screen.dart`  
**Entry:** FAB · Home Scan hero · Smart Scan tool

### Purpose

Multi-page hub after each 1-page system capture. Feel like a professional camera tool.

### Look

Full dark `AppTheme.scannerBg` (`#0A0A0A`). White app-bar chrome.

### Layout

- **AppBar:** Scanning · Page X of Y
- **Preview:** large rounded image (or “Opening scanner…” / “No pages yet”)
- **Thumbs:** horizontal · page number badge · selection scale/glow · Semantics “Page N”
- **Bottom bar** (`#141A22`, rounded top):
  - **Add page** (outlined)
  - **Continue** (filled + arrow) → Review

### Busy

`LoadingOverlay` — “Opening scanner…” / enhancing label · privacy note “This stays on your device”

### Errors

Friendly SnackBar — no raw exceptions.

### Back

Pop discards unsaved draft (no `meta.json` yet).

---

## Review / editor

**Class:** `ReviewScreen`  
**File:** `lib/features/document_editor/review_screen.dart`  
**Entry:** Scan **Continue** · Import Images (`discardOnPop: true`)

### Purpose

Check document before saving. Hierarchy: preview → filters → thumbs → tools → Finish.

### Layout

- **AppBar:** Review · Page X of Y · **Finish** → Save document
- Large `PhotoView` + Apptriangle watermark
- **This page** filter chips: B&W · Greyscale · Auto · Vivid · Lighten · Original
- Reorderable thumbs + add page
- **Toolbar:** Enhance · Rotate · Retake · Delete · **More**
  - Delete **disabled** when only 1 page
  - More sheet → **Retake all pages**

### Enhance sheet

Option cards: preview · name · short description  
Examples: Black & white “Best for documents” · Auto “Balanced everyday scan” · Original “Keep original colors”

### Busy / empty / errors

- Overlay: contextual processing label  
- Empty: `AppEmptyState`  
- Filter fail: friendly SnackBar

### Back

From scan: keep draft. From import (`discardOnPop`): discard.

---

## Save document (Export)

**Class:** `ExportScreen`  
**File:** `lib/features/export/export_screen.dart`  
**Entry:** Review → **Finish**

### Purpose

Simple save by default; advanced options behind progressive disclosure.

### Default layout

- **AppBar:** Save document
- **Document name** (default suggestion e.g. “Scanned document”)
- **Save as**
  - **PDF** — “Best for sharing and printing” (on by default)
  - **Images** — “JPG or PNG files for each page”
  - **Also save to device** — system Save as
- **More options** (expand) — quality / page size / orientation / image format / which pages
- Sticky **Save** CTA (icon + label)

### PDF quality hints (More options)

| Preset | Hint |
|--------|------|
| Small size | Best for sharing |
| Balanced | Recommended |
| High quality | Best for printing |

### Progress

Card: “Saving document” + contextual line + linear bar.

### Success / error

SnackBar “Document saved · PDF · …” (+ “saved to device” / “device copy skipped” if Also save was on) → pop Home · clear session.  
Errors: friendly copy, no stack traces.

---

## Document viewer

**Class:** `ViewerScreen`  
**File:** `lib/features/viewer/viewer_screen.dart`  
**Entry:** DocumentCard open (Home / Files / Recents)

### Purpose

Calm reading — document fills the screen; chrome stays secondary.

### Layout

- **AppBar:** document name
  - **Favorite** (animated)
  - **Share**
  - **More** — Print · Save to device · View PDF · Rename · Tags · Activity · Move to Trash
- Optional colored tag chips
- **Gallery:** swipe / zoom / double-tap · watermark · Hero `doc-thumb-<id>`
- **Footer card:** Previous · **Page X of Y** · Next

### States

| State | UI |
|-------|-----|
| Loading | AppBar + `AppListSkeleton` |
| Unavailable | `AppEmptyState` · Go back |

### Errors

Friendly SnackBars for print / save failures.

---

## Convert hub

**Class:** `ConvertersHubScreen`  
**File:** `lib/features/converters/converters_hub_screen.dart`  
**Entry:** Shell Convert tab · Home Convert · Files FAB

### Purpose

Intuitive groups — not a wall of technical tools.

### Chrome

| Mode | Header |
|------|--------|
| Embedded | **Convert** + “Documents, images, and edits — all on this phone.” |
| Push | AppBar **Convert** |

### Sections

| Section | Blurb | Tiles |
|---------|-------|--------|
| Documents | Turn PDFs, Word, Excel, and slides into the format you need | PDF→txt · **PDF→DOCX** · TXT/PPTX/DOCX/XLSX tools |
| Edit photo | Convert, crop, resize, or compress — one place | **Edit photo** (one screen) |
| PDF Tools | Merge, split, compress, and edit pages on this phone | **PDF Tools** hub |

### Opens

| Tool | Screen |
|------|--------|
| Format / office (Documents) | [Convert tool](#convert-tool) |
| Edit photo | [Edit photo](#edit-photo-convert--crop--resize--compress) |
| PDF Tools | [PDF Tools](#pdf-tools) |

---

## PDF Tools

**Class:** `PdfToolsHubScreen`  
**File:** `lib/features/pdf_tools/`  
**Entry:** Convert tab **PDF Tools**

Organize: Merge · Split · Reorder · Delete · Rotate · Extract  
Convert: PDF → images · Images → PDF  
Optimize: Compress  

Always **save as new file**. Open / Save / Share via `ConvertResultPanel` / `PdfToolsResultPanel`. Shared `PdfPageSelector`.

---

## Convert tool

**Class:** `ConvertToolScreen`  
**File:** `lib/features/converters/convert_tool_screen.dart`  
**Chrome:** `convert_tool_chrome.dart` · `convert_result_panel.dart`  
**Entry:** Hub / dashboard · optional `initialPath`

### Mental model (all converters)

1. Choose file  
2. Convert  
3. Preview result  
4. Open / Save / Share  

### Layout

1. AppBar = tool title  
2. **Compact hero** — icon · title · subtitle · steps as “1. … · 2. … · 3. …”  
3. Primary CTA — Choose file / Convert another  
4. Busy card — progress label  
5. Error — `AppEmptyState` Try again  
6. **`ConvertResultPanel`** — success check · Ready to use · type · size · file chip · equal **Open / Save / Share** tiles (Open primary navy)  

### Catalog tools on this screen

PDF↔txt · **PDF→DOCX** · PPTX/DOCX/XLSX → PDF/CSV · Image → JPG/PNG/WebP/GIF · HEIC → JPG  

Crop / Resize / Compress use dedicated screens.

### Output

`Base_KIND_yyyy-MM-dd_HHmm.ext` under `converts/`. Processed on device.

---

## Intent convert (Open with)

**Class:** `IntentConvertScreen`  
**File:** `lib/features/converters/intent_convert_screen.dart`  
**Bridge:** `lib/core/open_file_intent_bridge.dart`

### Purpose

OS hands ScanMe a file for a specific convert tool — no pick UI.

### Layout

Same as convert tool: compact hero → auto-run progress → error (Retry / View original) or result panel.

### Edit tools

`crop` / `resize` / `compress` → dedicated screens with `initialPath` (not this screen).

### Android

Activity-aliases · **ScanMe launcher icon** + per-tool labels (incl. **PDF to DOCX**). Reinstall/update to refresh Open-with icons.

---

## Edit photo (convert · crop · resize · compress)

**Class:** `ImageFormatsHubScreen`  
**File:** `lib/features/converters/image_formats_hub_screen.dart`  
**Entry:** Convert hub **Edit photo** · Dashboard **Edit photo**

### Purpose

One photo tool — convert + edit in the same screen (no separate Edit hub).

### Layout

**Empty (no photo):** same shell — hero · rail · blurb on top · **No photo yet** fills Expanded image area · **Choose image** CTA bottom

**With photo — same shell for every tool:**
1. AppBar **Edit photo** · **Change**
2. Top: meta (format · WxH · size) · icon tool rail · blurb · tool options
3. **Expanded image area** (bottom of chrome, fills remaining height):
   - Convert / Resize / Compress → large contained preview
   - Crop → interactive crop viewport (pinch / pan / ratios)
4. Bottom SafeArea: staged edit chips (× to drop) · **one Apply** · or result / Edit again / Choose image

**Tool options (settings only — no per-tool buttons or Include switches):**
- Changing settings auto-stages that edit
- **Convert** — format + quality
- **Crop** — aspect chips · Free · Exact px
- **Resize** — long edge / exact px
- **Compress** — target KB (final step → JPEG)

**One bottom CTA:** **Apply** runs staged edits: crop → resize → convert → compress.

HEIC/HEIF allowed as input.

### Open-with

Format + crop / resize / compress aliases open this screen with path + tab (and format when converting).

---

## Crop image

**Class:** `ImageCropToolScreen`  
**File:** `lib/features/converters/image_crop_tool_screen.dart`  
**Entry:** Standalone / legacy · Open-with now prefers Images tab

### Layout

- AppBar: Crop image · **Apply** when loaded  
- Empty: compact hero + `AppEmptyState` Choose image  
- Loaded: full `Crop` UI · navy corner dots · busy dim  
- Bottom: Apply crop · Choose another · or `ConvertResultPanel`

Same design language as Resize / Compress.

---

## Resize pixels

**Class:** `ImageResizeToolScreen`  
**File:** `lib/features/converters/image_resize_tool_screen.dart`  
**Entry:** Standalone / legacy · Open-with prefers Images **Resize** tab

### Layout

1. Compact hero  
2. Pick card (+ dims / size when loaded)  
3. Long edge / Exact segmented control  
4. Slider or W×H fields  
5. Output format chips: JPG · PNG · WebP  
6. **Resize** CTA · result panel  

Friendly values; sensible defaults from source image.

---

## Reduce file size

**Class:** `ImageCompressToolScreen`  
**File:** `lib/features/converters/image_compress_tool_screen.dart`  
**Entry:** Standalone / legacy · Open-with prefers Images **Compress** tab

### Layout

1. Compact hero — “Make an image smaller for sharing”  
2. Pick card  
3. **Target size** · ≈ N KB (slider) + preset chips  
4. **Reduce size** CTA · result panel  

Language: “Target size” first; KB as supporting detail.

---

## File viewer

**Class:** `FileViewerScreen`  
**File:** `lib/features/file_viewer/file_viewer_screen.dart`  
**Entry:** Convert result · Viewer View PDF · Open-with view

### Purpose

Same ScanMe header / spacing / Save / Share as the rest of the app.

### Chrome

AppBar: filename · **Save** · **Share**

### Body by kind

| Kind | UI |
|------|-----|
| txt / csv / md / log | Selectable scroll text |
| PDF | `PdfPreview` |
| Image | `PhotoView` |
| PPTX | Slide PageView + disclaimer · footer “Slide X of Y” card |
| DOCX | Selectable text preview + “Open in Word for full editing” |
| Unknown | `AppEmptyState` Cannot preview |

### Errors

Friendly empty states (read fail · missing image · bad PPTX) — no raw exceptions in UI.

---

## QR reader

**Class:** `QrReaderScreen`  
**File:** `lib/features/qr/qr_reader_screen.dart`  
**Entry:** Home → Quick tools → **QR reader** (default pin) · Customize sheet

### Purpose

Scan QR codes / common barcodes on-device. Copy, share, or open http(s) links.

### Layout

1. **AppBar** — dark scanner chrome · Torch · Scan from photo
2. **Camera preview** — `mobile_scanner` live feed
3. **Frame overlay** — dimmed outside · rounded hole · white corner brackets
4. **Hint** — “Point at a QR code or barcode” · “Stays on this device”

### Result sheet

- Title **Code found** · selectable payload
- **URL:** **Open link** (primary) · **Copy** · **Share** · **Scan again** — never auto-open
- **Non-URL:** **Copy** (primary) · **Share** · **Scan again**
- Offline decode; Open link uses system browser (`url_launcher`)

### Empty / error

| State | UI |
|-------|-----|
| Camera denied / fail | Empty state · Go back |
| Photo has no code | Snackbar |
| Photo read fail | Snackbar |

### Formats

QR · Aztec · Data Matrix · PDF417 · Code 128/39 · EAN-8/13 · UPC-A/E

### Permissions

- Android: `CAMERA` (+ gallery via image_picker)
- iOS: camera + photo library usage strings mention QR

---

## Sheets, dialogs, overlays

Consistent sheet language: large top radius · clear title · optional description · large targets · destructive last / separated.

### Catalog

| UI | Where | What |
|----|-------|------|
| Customize tools | Home | Add/remove · Reset |
| Document actions | Home ⋯ | Open · Favorite · Tags · Rename · Share · **Move to Trash** (last, error color) |
| Convert actions | Home convert ⋯ | Open · Favorite · Tags · Remove |
| Quick favorite | Card bookmark | Toggle favorite |
| Trash actions | Deleted ⋯ | Restore · Delete permanently |
| Confirm Move to Trash | Files / Viewer | “Move to Trash?” · can restore |
| Confirm permanent delete | Trash | “Delete permanently?” · **This cannot be undone.** |
| Tags sheet | Files / Viewer | Toggle · New · Done |
| Tag edit | Settings | Name + color · Delete |
| Activity | Viewer | Created / Modified / Exported timeline |
| Enhance | Review | Preview cards + descriptions |
| Review More | Review toolbar | Retake all pages |
| Rename dialog | Files / Viewer | Cancel / Save |
| Sort popup | Files | LibrarySort |
| Loading overlay | Scan / Review | Contextual message + privacy line |
| `AppListSkeleton` | Home / Files / Viewer load | List placeholders |
| SnackBars | Various | Success / friendly errors |
| System share / print / Save as | OS | |

### Rules

- Primary action first; destructive last  
- Never “Are you sure?” alone — say what happens  
- No raw `Exception:` strings for users  
- Folders UI paused (model only)

---

## Global brand, motion, data model

Cross-cutting tokens after UI/UX upgrade. Not a screen.

### Brand / theme (`app_theme.dart`)

| Token | Value / role |
|-------|----------------|
| Primary navy | `#1B3A4B` |
| Accent | `#2A7A86` |
| Navy on dark | `#7AADC0` |
| Paper | `#F4F0EA` (warm ivory) |
| Dark scaffold | `#0C1216` |
| Dark surface | `#151C22` |
| Scanner bg | `#0A0A0A` |
| Success / warning / info | Semantic greens / amber / blue |
| Radii | Sm **14** · Md **18** · Lg **22** · Xl **28** · pill **999** |
| Shadows | `cardShadow` · `floatShadow` |
| Spacing | Xs 4 · Sm 8 · Md 12 · Lg 16 · Xl 20 · 2xl 24 · 3xl 32 |
| Tap min | **48** |
| Font | Plus Jakarta Sans |
| Watermark | Apptriangle on preview + every PDF page + export images |
| App icon | Launcher · Open-with aliases |

Light / dark / system via `themeModeProvider`. Prefer `ColorScheme` over hardcodes.

### Typography hierarchy

Display / Headline / Title / Body / Label — readable sizes for older users; respect text scale.

### Shared components (`app_ui.dart` + friends)

`AppButton` (filled · secondary/outlined · text) · `AppCard` · `AppSearchBar` · `AppEmptyState` · `AppErrorState` · `AppLoadingState` · `AppListSkeleton` · `AppProgressCard` · `LoadingOverlay` · `AppBarBackButton` / `scanMeAppBarLeading` · `AppCircleIconButton` / `AppIconButton` · `SectionHeader` / `AppSectionHeader` · `PrivacyBadge` · `MetaChip` · `showAppBottomSheet` · `showConfirmSheet` · `DocumentCard` · `ConvertToolHero` · `ConvertResultPanel`

**Back navigation:** Pushed screens use `AppBar(leading: scanMeAppBarLeading(context))` (null on root/tab so no empty slot). `AppPageRoute` is `MaterialPageRoute` + custom slide/fade so Material back works. Tab roots (Home · Files · Convert · Me) have no back.

### Motion (`app_transitions.dart`)

| Motion | Where |
|--------|--------|
| `AppPageRoute` | Push Scan / Review / Export / Viewer / Tools (`MaterialPageRoute` + slide/fade; AppBar back works) |
| `FadeRiseIn` / `PressableScale` | Hub, Home, FAB, tiles |
| `AppBodySwitch` / stagger | Files list |
| Hero `doc-thumb-<id>` | List → Viewer |
| Sheet settle | Bottom sheets |
| A11y | Honors `MediaQuery.disableAnimations` |

Typical duration ~150–300ms. Don’t animate everything.

### Library fields (UI-facing)

| Field | Use |
|-------|-----|
| `tags` | Chips, search, filter |
| `isFavorite` | Star, Favorites filter |
| `deletedAt` | Recently deleted · auto-purge |
| `exportedAt` | Activity |
| `createdAt` / `updatedAt` | Sort · “Updated today” |
| `folderId` | Stored; **UI hidden** |

### Default processing

New pages → B&W by default · user can change on Review · Export uses display paths + quality presets.

### Privacy

Offline-first. Subtle badges / overlay lines — not spam on every screen.

---
