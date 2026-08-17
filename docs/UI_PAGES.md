# ScanMe — UI pages reference

> Living status / task log: [`PROJECT_LOG.md`](PROJECT_LOG.md)  
> **Single file** for every in-app page’s UI detail (no per-screen splits).  
> Last aligned: **2026-08-16** Home dashboard redesign (Start · Shortcuts · Continue).

**Brand:** ScanMe / Apptriangle · Plus Jakarta Sans · navy `#1B3A4B` · accent `#2F6F7E` · paper `#F0F2F5` · light / dark / system

## Navigation map

```
MainShell (bottom nav)
├── Home — brand · search · Shortcuts tiles · Continue
├── Files — library / Recently deleted · search · filters · sort
├── Camera FAB — Scan capture → Review → Save document
├── Convert — Documents · Images · Edit images (stacked) → tools
└── Me — Appearance · Storage · Tags · About

Open-with (OS) → Intent convert | Crop / Resize / Compress | File viewer
Home Shortcuts → Import · QR · Favorites · Edit images
```

## Contents

1. [Main shell](#main-shell)
2. [Home dashboard](#home-dashboard)
3. [Files library](#files-library)
4. [Settings / Me](#settings-me)
5. [System document scanner](#system-document-scanner)
6. [Scan capture](#scan-capture)
7. [Review / editor](#review-editor)
8. [Save document (Export)](#save-document-export)
9. [Document viewer](#document-viewer)
10. [Convert hub](#convert-hub)
11. [Convert tool](#convert-tool)
12. [Intent convert (Open with)](#intent-convert-open-with)
13. [Image formats (stacked)](#image-formats-stacked)
14. [Edit images (stacked)](#edit-images-stacked)
15. [Crop image](#crop-image)
16. [Resize pixels](#resize-pixels)
17. [Reduce file size](#reduce-file-size)
18. [File viewer](#file-viewer)
19. [QR reader](#qr-reader)
20. [Sheets, dialogs, overlays](#sheets-dialogs-overlays)
21. [Global brand, motion, data model](#global-brand-motion-data-model)

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
| Main shell | `lib/features/home/main_shell_screen.dart` |
| Home dashboard | `lib/features/home/home_dashboard_screen.dart` |
| Files | `lib/features/home/home_screen.dart` |
| Settings | `lib/features/settings/settings_screen.dart` |
| Scan capture | `lib/features/scanner/scan_capture_screen.dart` |
| Review | `lib/features/document_editor/review_screen.dart` |
| Export | `lib/features/export/export_screen.dart` |
| Viewer | `lib/features/viewer/viewer_screen.dart` |
| Convert hub | `lib/features/converters/converters_hub_screen.dart` |
| Convert tool | `lib/features/converters/convert_tool_screen.dart` |
| Intent convert | `lib/features/converters/intent_convert_screen.dart` |
| Crop / Resize / Compress | `lib/features/converters/image_*_tool_screen.dart` |
| Edit images hub | `lib/features/converters/image_edit_hub_screen.dart` |
| Image formats hub | `lib/features/converters/image_formats_hub_screen.dart` |
| File viewer | `lib/features/file_viewer/file_viewer_screen.dart` |
| QR reader | `lib/features/qr/qr_reader_screen.dart` |
| Shared UI | `lib/shared/widgets/app_ui.dart`, `document_card.dart`, `app_transitions.dart` |
| Theme | `lib/core/theme/app_theme.dart` |

---

## Main shell

**Class:** `MainShellScreen`  
**File:** `lib/features/home/main_shell_screen.dart`  
**Entry:** `MaterialApp.home`

### Purpose

App chrome: tabs + center Scan FAB. Hosts Home, Files, Convert, Me.

### Layout

- **AppBar:** none (tabs own headers)
- **Body:** non-swipeable `PageView` (keep-alive):
  1. Home dashboard  
  2. Files (`HomeScreen` embedded)  
  3. Convert hub (`ConvertersHubScreen` embedded)  
  4. Me (`SettingsScreen` embedded)
- **FAB (center-docked):** circle · document-scanner icon · elevation 6  
  - Tooltip / semantics: **Scan Document**  
  - Color: navy (light) / navyOnDark (dark)  
  - Strongest nav action — opens Scan capture
- **BottomAppBar:** notched · height 64  
  **Home · Files · [gap] · Convert · Me**  
  - Outlined vs filled icons when selected  
  - Selected: primary color + scale  
  - Hit area ~56h · Plus Jakarta Sans 11 · Semantics labels

### Interactions

- Tab switch unfocuses keyboard
- Reduce-motion: jump page (no anim)
- `resizeToAvoidBottomInset: false`

---

## Home dashboard

**Class:** `HomeDashboardScreen`  
**File:** `lib/features/home/home_dashboard_screen.dart`  
**Entry:** Shell tab 0

### Purpose

Compact home: find docs fast · shortcuts · continue where you left off. Scan = FAB · Convert = Convert tab.

### Layout (top → bottom)

1. **Header** — **ScanMe** · tagline · **light/dark toggle** (Me tab still has full Appearance)
2. **Search** — dense · submit → Files with query
3. **Shortcuts** — non-scrollable **4-col tile grid**. Defaults: Import · QR · Favorites · Edit images · Add. Scan / Convert not listed (FAB + Convert tab). Long-press removes.
4. **Continue** — “View all” → Files · up to 8 `DocumentCard`s

Prefs key `dashboard_tool_ids_v5`.

### Empty / load / error

| State | UI |
|-------|-----|
| Loading | `AppListSkeleton` |
| No documents | “Nothing here yet” · calm copy (no Scan CTAs) |
| Search miss | “No documents found” · Search all files |
| Load error | Try again |

### Sheets

- Customize Shortcuts (Reset · tap add/remove)
- Card ⋯: Open · Tags · View all files

### Persistence

Shortcut ids: `dashboard_tool_ids_v5`. Defaults: Import · QR reader · Favorites · Edit images. Migrate from older keys adds Import if missing.

---

## Files library

**Class:** `HomeScreen`  
**File:** `lib/features/home/home_screen.dart`  
**Entry:** Shell tab 1 (`embedded: true`); optional standalone push

### Purpose

Document management — Apple Files / Drive simplicity + ScanMe identity.

### Chrome

| Mode | Title |
|------|--------|
| Library | **Files** (embedded) or **ScanMe** (standalone) |
| Trash | **Recently deleted** + blurb: kept until auto-removed |

Trash toggle (48px) · Settings only if standalone.

### Layout

1. Search — “Search documents and tags” (hidden in Trash)
2. Filters: All · Favorites · Tags · Sort popup  
   Selected chips: navy fill + white label
3. Tag chips row when Tags filter on
4. List — `DocumentCard` · pull-to-refresh · `AppListSkeleton` · empty · error

### Document card

- Thumb (Hero) · favorite badge · name (2 lines)  
- Meta: `N pages · PDF|Images · Updated today`  
- Up to 2 tag chips · **More** (48px)

### Empty

| Mode | Copy / CTAs |
|------|-------------|
| Library | No documents yet · Scan Document · Import Images |
| Trash | Nothing in Trash · restore blurb · Back to library |

### FAB

Standalone + not trash only: Scan / Images to PDF / Converters.

### Actions sheets

See [sheets-overlays.md](sheets-overlays.md) — Open first · Trash last · permanent delete confirms “cannot be undone.”

---

## Settings / Me

**Class:** `SettingsScreen`  
**File:** `lib/features/settings/settings_screen.dart`  
**Entry:** Shell **Me** tab · Settings from Home / Files

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

#### Storage

**Trash retention** — “Recently deleted documents are kept for N days…”  
Dialog: 7 / 14 / 30 / 60 / 90 days (default 30)

#### Tags

Color dot + name · tap edit · long-press delete · **Add tag**  
Seeded: Urgent · Work · Personal · Receipt · ID · Finance

#### About

ScanMe · Apptriangle · v1.0.0  
**PrivacyBadge:** “Stored privately on this device · No account required”

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

SnackBar “Document saved · PDF · …” → pop Home · clear session.  
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
| Images | Convert image formats | **One tile → stacked hub** |
| Edit images | Crop, resize, or reduce file size | **One tile → stacked hub** |

### Stacked hubs

| Tile | Opens |
|------|--------|
| Image formats | [image-formats-hub.md](image-formats-hub.md) |
| Edit images | [image-edit-hub.md](image-edit-hub.md) |

### Opens

| Tool | Screen |
|------|--------|
| Format / office (Documents) | [convert-tool.md](convert-tool.md) |
| Image formats | [image-formats-hub.md](image-formats-hub.md) |
| Edit images | [image-edit-hub.md](image-edit-hub.md) |

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
6. **`ConvertResultPanel`** — success check · Ready · type · size · Open / Save / Share  

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

Activity-aliases + per-tool icons (incl. **PDF to DOCX**). Reinstall to refresh Open-with list.

---

## Image formats (stacked)

**Class:** `ImageFormatsHubScreen`  
**File:** `lib/features/converters/image_formats_hub_screen.dart`  
**Entry:** Convert hub **Image formats** · Dashboard **Image formats**

### Purpose

One place for format conversions — JPG, PNG, WebP, GIF, HEIC stacked (not five hub tiles).

### Layout

1. AppBar **Image formats**
2. Compact hero
3. **Choose a format**
4. Stacked cards → each opens [convert-tool.md](convert-tool.md):
   - Image to JPG
   - Image to PNG
   - Image to WebP
   - Image to GIF
   - HEIC to JPG

### Open-with

Android aliases still open the matching convert screen directly with path.

---

## Edit images (stacked)

**Class:** `ImageEditHubScreen`  
**File:** `lib/features/converters/image_edit_hub_screen.dart`  
**Entry:** Convert hub **Edit images** · Dashboard **Edit images**

### Purpose

One place for all image edits — Crop, Resize, and Reduce file size stacked as a clear list (not three separate hub tiles).

### Layout

1. AppBar **Edit images**
2. Compact hero — “Crop, resize, or reduce file size”
3. **Choose what to do**
4. Stacked cards (full width):
   - **Crop image** → [crop.md](crop.md)
   - **Resize pixels** → [resize.md](resize.md)
   - **Reduce file size** → [compress.md](compress.md)

### Open-with

Android aliases still open Crop / Resize / Compress screens directly with `initialPath` (skip this hub).

---

## Crop image

**Class:** `ImageCropToolScreen`  
**File:** `lib/features/converters/image_crop_tool_screen.dart`  
**Entry:** Edit images hub · Open-with crop alias (`initialPath`)

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
**Entry:** Edit images hub · Open-with resize (`initialPath`)

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
**Entry:** Edit images hub · Open-with compress (`initialPath`)

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
| Document actions | Files ⋯ | Open · Favorite · Tags · Rename · Share · **Move to Trash** (last, error color) |
| Quick actions | Home card ⋯ | Open · Tags · View all files |
| Trash actions | Recently deleted ⋯ | Restore · Delete permanently |
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
| Accent | `#2F6F7E` |
| Navy on dark | `#4A7A92` |
| Paper | `#F0F2F5` |
| Dark scaffold | `#0A0A0A` |
| Scanner bg | `#0A0A0A` |
| Success / warning / info | Semantic greens / amber / blue |
| Radii | Sm **12** · Md **16** · Lg **20** · Xl **24** |
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
