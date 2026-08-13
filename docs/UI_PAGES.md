# ScanMe — UI pages reference

Offline CamScanner-style app (Flutter). Brand: **ScanMe** / Apptriangle. Theme: navy + paper surfaces, **Plus Jakarta Sans**, light / dark / system.

This doc describes every in-app screen, sheet, and system UI the user hits.

---

## Navigation map

```
Home
├── Settings
├── New scan → [System document scanner] → Scan capture → Review → Save document → Home
├── Images to PDF → [System photo picker] → Review → Save document → Home
└── Document row / actions → Viewer
    ├── Share / Rename / Delete
    └── (back to Home)
```

System UIs (not Flutter screens):

| UI | Platform | When |
|----|----------|------|
| Google ML Kit Document Scanner | Android | Each single-page capture |
| VisionKit document camera | iOS | Each single-page capture |
| System photo / gallery picker | Both | Images to PDF |

---

## 1. Home (`HomeScreen`)

**File:** `lib/features/home/home_screen.dart`  
**Entry:** App launch (`MaterialApp.home`)

### Purpose
List saved documents and start new work (scan or gallery → PDF).

### Layout
- **Header:** brand title `ScanMe`, subtitle `Documents on this device`, settings gear (top-right).
- **Section label:** `Recent`
- **Body:**
  - Loading spinner, or error message, or empty state, or document list.
- **FABs (stacked, bottom-end):**
  1. **Images to PDF** — secondary (surface fill, primary text/icon)
  2. **New scan** — primary extended FAB

### Empty state
- Icon block, headline `No documents yet`, short privacy copy.
- Buttons: **Scan a document**, **Images to PDF**.

### Document list row
Each row shows:
- Thumbnail (if present)
- Document name
- Meta line: page count · PDF/Images · size · date
- Overflow **⋯** opens actions sheet

Pull-to-refresh reloads local documents.

### Document actions sheet
Title = document name. Actions:
- **Open** → Viewer
- **Rename** → dialog
- **Share** → system share sheet (PDF and/or export images)
- **Delete** → confirm dialog, then remove from disk

### Flows from Home
| Control | Next |
|---------|------|
| New scan / Scan a document | Scan capture (auto-opens system scanner) |
| Images to PDF | Multi-image picker → import + auto B&W → Review (`discardOnPop: true`) |
| Open row / Open action | Viewer |

---

## 2. Settings (`SettingsScreen`)

**File:** `lib/features/settings/settings_screen.dart`  
**Entry:** Home → settings icon

### Purpose
Theme preference + short about copy.

### Layout
- App bar: `Settings`
- **Appearance**
  - Radio: **Match phone setting**, **Light**, **Dark** (persisted)
- **About**
  - Offline / no-account / compression blurb

---

## 3. System document scanner (platform)

**Triggered by:** Scan capture **Add page**, Review retake / retake-all (and first auto-open on New scan)

### Behavior (app-controlled)
- Android ML Kit called with **`pageLimit: 1`** for normal add/retake-one (multi-page **Add page / Next** live in ScanMe, not in Google UI).
- Retake-all may use a higher page limit.
- Returns JPEG path(s) → import → **CamScan B&W applied to new pages by default**.

### Labels
Native shutter / crop / confirm strings are owned by Google / Apple and are **not** customizable.

---

## 4. Scan capture (`ScanCaptureScreen`)

**File:** `lib/features/scanner/scan_capture_screen.dart`  
**Entry:** Home → New scan

### Purpose
Multi-page scan hub after each 1-page system capture. Owns **Add page** and **Next**.

### Look
Dark background (`#0E1218`), white app-bar title.

### Layout
- **App bar:** `Scan` or `Page X of Y`
- **Main:** large preview of selected page (or “Opening camera…” / “No pages yet”)
- **Thumbnail strip:** horizontal page thumbs; tap to select
- **Bottom actions (side by side):**
  - **Add page** (outlined) → system scanner again → append + auto B&W
  - **Next** (filled) → Review
- Busy overlay while camera open or B&W processing (`Applying black & white…`)

### Back
Pops to Home and **discards unsaved draft** (no `meta.json` yet).

---

## 5. Review / editor (`ReviewScreen`)

**File:** `lib/features/document_editor/review_screen.dart`  
**Entry:**
- Scan capture → **Next**
- Images to PDF → after import (`discardOnPop: true`)

### Purpose
Inspect pages, toggle B&W vs Original per page, enhance / rotate / retake / reorder / delete, then finish to save.

### Layout
- **App bar:** `Page X of Y` + **Finish** → Save document
- **Main:** zoom/pan page preview (`PhotoView`) + Apptriangle watermark overlay
- **This page** bar — segmented control:
  - **B&W** (default after import)
  - **Original** (disable B&W for this page only)
- **Thumbnail strip:** reorderable thumbs + **+** add page (opens system scanner, append + B&W)
- **Toolbar:**
  - **Enhance** → filter sheet
  - **Rotate**
  - **Retake** (one page, scanner)
  - **Delete** (blocked if only one page)
  - **More** → **Retake all**

### Enhance sheet
- Original (this page)
- Black & white (this page)
- Black & white on all pages
- Original on all pages

### Processing
Full-screen dim + spinner + label (e.g. filter progress).

### Back
- From scan flow: returns to Scan capture (draft kept).
- From Images to PDF (`discardOnPop: true`): discard unsaved draft.

---

## 6. Save document / Export (`ExportScreen`)

**File:** `lib/features/export/export_screen.dart`  
**Entry:** Review → **Finish**

### Purpose
Name the document and write PDF and/or JPEGs to local storage (compressed, watermarked).

### Layout
- App bar: `Save document`
- **Name** text field (hint: e.g. Lease agreement)
- **Format** section + page count / compression note
  - Toggle tile **PDF** (default on)
  - Toggle tile **JPEG images**
- Progress label + linear bar while saving
- Primary CTA: **Save on this device** (disabled if both formats off or busy)

### After success
SnackBar `Saved on this device` → `popUntil` Home → clear editor session. Document appears under Recent.

---

## 7. Viewer (`ViewerScreen`)

**File:** `lib/features/viewer/viewer_screen.dart`  
**Entry:** Home → open document

### Purpose
Browse a saved multi-page document; share / rename / delete.

### Layout
- App bar: document name  
  Actions: **Share**, **Rename**, **Delete**
- **Gallery:** swipeable zoomable pages (`PhotoViewGallery`) + watermark overlay
- **Footer:** `Page X of Y`

### States
- Loading spinner
- Error: missing doc / no pages / missing page file

### Dialogs
- Rename (text field)
- Delete confirm → remove from storage → pop Home

---

## 8. Transient / overlay UIs

| UI | Where | What |
|----|-------|------|
| Preparing images… dialog | Home → Images to PDF | Spinner while import + B&W |
| Busy overlay | Scan capture / Review | Camera or filter in progress |
| SnackBars | Various | Errors, cancel notes, save success |
| Rename dialog | Home actions / Viewer | Edit document name |
| Delete confirm | Home actions / Viewer / Review page | Destructive confirm |
| Retake all confirm | Review → More | Warn pages discarded, scanner restarts |
| Document actions sheet | Home row ⋯ | Open / Rename / Share / Delete |
| Enhance sheet | Review | Per-page and all-pages filters |
| System share sheet | Home / Viewer | OS share for PDF/images |

---

## Visual / brand notes (global)

| Token | Role |
|-------|------|
| Navy `#1B3A4B` | Primary (light) |
| Accent `#2F6F7E` | Secondary |
| Paper `#F0F2F5` | Light scaffold |
| Plus Jakarta Sans | All typography |
| Apptriangle logo | Small bottom-right watermark on preview + exports |
| App icon | Launcher (`assets/branding/app_icon.png`) |

---

## Default page processing

1. New page imported (scan or gallery) → **B&W applied automatically**.
2. User can set **Original** per page on Review (or all pages via Enhance).
3. Export uses each page’s current display (B&W processed file or original), then compresses / watermarks.

---

## Screen ↔ source map

| Screen | Dart file |
|--------|-----------|
| Home | `lib/features/home/home_screen.dart` |
| Settings | `lib/features/settings/settings_screen.dart` |
| Scan capture | `lib/features/scanner/scan_capture_screen.dart` |
| Review | `lib/features/document_editor/review_screen.dart` |
| Save document | `lib/features/export/export_screen.dart` |
| Viewer | `lib/features/viewer/viewer_screen.dart` |
| Theme | `lib/core/theme/app_theme.dart` |
| Watermark widget | `lib/shared/widgets/apptriangle_watermark_overlay.dart` |
