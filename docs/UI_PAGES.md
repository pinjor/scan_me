# ScanMe — UI pages reference

> **Living project status / task log:** [`PROJECT_LOG.md`](PROJECT_LOG.md) (update that after every task). This file = deep UI detail only.

Offline CamScanner-style app (Flutter). Brand: **ScanMe** / Apptriangle. Theme: navy + paper surfaces, **Plus Jakarta Sans**, light / dark / system.

This doc describes every in-app screen, sheet, overlay, and system UI the user hits — including library organization, export options, converters, print, trash, and motion.

---

## Navigation map

```
MainShell (bottom nav)
├── Home dashboard — search · tools grid · Recents
├── Files — full library (filters / trash / sort)
├── Camera FAB — Scan capture → Review → Export
├── Tools — converters hub (PDF↔TXT, PPTX→PDF, PNG↔JPG) → Save / Share
└── Me — Settings (theme · trash · tags · about)

Legacy push routes still: Scan capture · Review · Export · Viewer
```

System UIs (not Flutter screens):

| UI | Platform | When |
|----|----------|------|
| Google ML Kit Document Scanner | Android | Each single-page capture / retake |
| VisionKit document camera | iOS | Each single-page capture / retake |
| System photo / gallery picker | Both | Import Images |
| File picker | Both | Tools converters |
| System share sheet | Both | Share PDF, images, or convert outputs |
| Native print dialog | Both | Viewer → Print (`printing`) |

---

## Motion / transitions (global)

**File:** `lib/shared/widgets/app_transitions.dart`  
**Theme:** `lib/core/theme/app_theme.dart` (`pageTransitionsTheme`)

| Motion | Where |
|--------|--------|
| `AppPageRoute` — fade + rise + soft scale | Push/pop Scan, Review, Export, Viewer, Tools |
| `AppBodySwitch` | Files loading ↔ empty ↔ list |
| `StaggeredListItem` | Document list rows (subtle stagger) |
| `FadeRiseIn` | Empty states, Tools hub, Home tools grid, FAB |
| `PressableScale` | Tool tiles, bottom nav |
| `AppCard` soft press | Tappable cards |
| Bottom sheet settle | `showAppBottomSheet` |
| Hero `doc-thumb-<id>` | Files / Recents thumb → Viewer |
| AnimatedSwitcher | Export progress, Viewer footer, Tools progress, nav icons |
| FAB speed dial | Size/fade expand (legacy Files FAB if shown) |
| Curves | M3 emphasized / decelerate / soft spring via `AppMotion` |
| A11y | Honors `MediaQuery.disableAnimations` |

---

## 1. Main shell + Home dashboard

**Files:** `main_shell_screen.dart`, `home_dashboard_screen.dart`, `home_screen.dart` (Files tab)  
**Entry:** `MaterialApp.home` → `MainShellScreen`

### Shell
Bottom bar: **Home · Files · (camera FAB) · Tools · Me**. Navy FAB opens Smart Scan. Brand colors stay navy (not CamScanner teal).

### Home dashboard
- Search (submits / non-empty → Files tab with query)
- **Tools grid (customizable):** defaults **Smart Scan · Convert · Import Images · Files** + **Add**
  - **Add** → sheet of catalog (Tags, Favorites, Trash, convert shortcuts…) — no Folders / Settings
  - Long-press tile → remove (keeps ≥1). Reset in sheet.
  - Choice persisted (`dashboard_tool_ids_v1`)
- **Recents:** up to 8 docs · View all → Files

### Files tab (`HomeScreen` embedded)
- Header **Files** / **Trash** · trash toggle
- Search · filter chips · sort · document list (same as prior library)
- No local FAB (shell camera covers scan)

---

## 2. Settings (`SettingsScreen`)

**File:** `lib/features/settings/settings_screen.dart`  
**Entry:** Home → settings icon

### Purpose
Theme, trash auto-empty, tag catalog, about.

### Layout
- App bar: `Settings`
- **Appearance** — Match phone setting · Light · Dark (persisted)
- **Trash** — Auto-empty after **7 / 14 / 30 / 60 / 90** days (default 30)
- **Tags** — catalog list (color dot + name); tap → edit name/color; Delete in dialog or long-press; **Add tag**
- **About** — ScanMe by Apptriangle · version · privacy / offline / compression copy

---

## 3. System document scanner (platform)

**Triggered by:** Scan capture **Add page**, Review retake / retake-all, first auto-open on New scan

### Behavior (app-controlled)
- Android ML Kit: **`pageLimit: 1`** for normal add / retake-one (multi-page hub lives in ScanMe).
- Retake-all may use a higher page limit.
- Returns JPEG path(s) → import → **CamScan B&W on new pages by default**.

### Labels
Native shutter / crop / confirm owned by Google / Apple — not customizable.

---

## 4. Scan capture (`ScanCaptureScreen`)

**File:** `lib/features/scanner/scan_capture_screen.dart`  
**Entry:** Home → Scan Document

### Purpose
Multi-page scan hub after each 1-page system capture. Owns **Add page** and **Continue**.

### Look
Dark background (`#0E1218`), light app-bar chrome.

### Layout
- **App bar:** Scan / page count
- **Main:** preview of selected page (or opening / empty copy)
- **Thumbnail strip:** tap to select; animated scale on selection
- **Bottom:**
  - **Add page** (outlined) → system scanner → append + auto B&W  
  - **Continue** (filled) → Review
- Busy overlay while camera open or B&W processing

### Back
Pops to Home and **discards unsaved draft** (no `meta.json` yet).

---

## 5. Review / editor (`ReviewScreen`)

**File:** `lib/features/document_editor/review_screen.dart`  
**Entry:**
- Scan capture → **Continue**
- Images to PDF → after import (`discardOnPop: true`)

### Purpose
Inspect pages, B&W vs Original, enhance / rotate / retake / reorder / delete, then **Finish**.

### Layout
- **App bar:** `Review` + **Finish** → Save document
- **Main:** zoom/pan (`PhotoView`) + Apptriangle watermark
- **This page** chips: B&W · Greyscale · Auto · Vivid · Lighten · Original
- **Thumbnail strip:** reorderable + **+** add page
- **Toolbar:** Enhance · Rotate · Retake · Delete · **Retake all**

### Enhance sheet
- This page / All pages: Original · Black & white · Greyscale · Auto enhance · Vivid color · Lighten

### Processing
Full-screen dim + spinner + label.

### Back
- From scan: returns to Scan capture (draft kept).  
- From Images to PDF (`discardOnPop: true`): discard unsaved draft.

---

## 6. Save document / Export (`ExportScreen`)

**File:** `lib/features/export/export_screen.dart`  
**Entry:** Review → **Finish**

### Purpose
Name document; write PDF and/or images locally (compressed, watermarked) with advanced options.

### Layout
- App bar: `Save document`
- **Document name** field
- **Format**
  - **PDF** toggle (default on)  
    - Quality: Small size · Balanced · High quality  
    - Page size: Original · A4 · Letter  
    - Orientation: Auto · Portrait · Landscape  
  - **Images** toggle  
    - Format: JPG · PNG  
    - Quality: Low · Medium · High  
    - Export pages: Current page · Selected pages · Entire document  
    - Page chips when **Selected pages**
- Progress card (animated) while saving  
- CTA: **Save** (disabled if both formats off or busy)
- Toggle: **Also save to device** (default on) → system **Save as** (user picks folder/name)

### After success
SnackBar → `popUntil` Home → clear editor session. Sets `exportedAt` on meta.

---

## 7. Viewer (`ViewerScreen`)

**File:** `lib/features/viewer/viewer_screen.dart`  
**Entry:** Home → open document

### Purpose
Browse saved pages; favorite, print, share, organize, inspect activity.

### Layout
- **App bar:** document name  
  - Favorite (animated star)  
  - **Print** (PDF if present, else images → print PDF layout)  
  - **Share**  
  - **⋯** menu: Rename · Tags · Activity · Move to Trash
- Optional chip row: **colored** tag chips (from catalog)
- **Gallery:** swipe / zoom (`PhotoViewGallery`) + watermark · Hero from list
- **Footer:** `Page X of Y` (crossfades on page change)

### Sheets / dialogs
- **Tags:** toggle catalog tags (color + name) · create new tag with color picker  
- **Activity:** Created · Modified · Exported (dates)  
- **Move to folder:** hidden for now (folder system paused)  
- Rename dialog · Move to Trash confirm → soft-delete → pop Home

### States
Loading · missing doc / no pages · missing page file

---

## 8. Tools (`ConvertersHubScreen`)

**Files:** `converters_hub_screen.dart`, `document_converter_service.dart`  
**Entry:** Shell **Convert** tab · Home grid **Convert**

Title **Convert** — converters for PDF / text / slides / images (not PDF-only).

### Purpose
On-device file conversion. Outputs under app `converts/`. Result: **Open in ScanMe** · Save · Share.

### In-app viewers (`lib/features/file_viewer/file_viewer_screen.dart`)

Used when needed (convert result, library **View PDF**, **Open with ScanMe** from system file manager) — no standalone Open-file Tools tile.

| Kind | UI |
|------|-----|
| `.txt` | Scrollable selectable text |
| PDF | `PdfPreview` (printing) |
| Images | `PhotoView` zoom |
| `.pptx` | Swipe slides (text + embedded images; best-effort) |

Library document ⋯ **View PDF** when exported PDF exists.

### Tiles

| Tile | Input | Output | Notes |
|------|--------|--------|--------|
| PDF to .txt | `.pdf` | **UTF-8 `.txt`** | Page-by-page Syncfusion extract (`layoutText`); image-only → notice (no OCR) |
| .txt to PDF | `.txt` / `.md` / `.log` | `.pdf` | Multi-page wrap + Apptriangle footer |
| PowerPoint to PDF | `.pptx` | `.pdf` | Text + embedded images best-effort |
| PNG to JPG | images | `.jpg` | Flatten + watermark |
| JPG to PNG | `.jpg` | `.png` | Re-encode + stamp |

Picker: path if present, else `PlatformFile.readAsBytes()` → temp file (SAF-safe). Output names use `${base}_${stamp}.ext` (fixed Closure bug).

---

## 9. Transient / overlay UIs

| UI | Where | What |
|----|-------|------|
| Preparing images… | Home → Images to PDF | Import + B&W |
| Busy overlay | Scan capture / Review | Camera or filter |
| Loading overlay | Shared | Dim + spinner + message |
| SnackBars | Various | Success / errors |
| Rename dialog | Home / Viewer | Edit name |
| New / rename folder dialogs | Home | Folder CRUD |
| Confirm sheets | Trash / delete forever / folder delete / retake all | Destructive confirms |
| Document actions sheet | Home ⋯ | Library actions |
| Trash actions sheet | Trash ⋯ | Restore / permanent delete |
| Move to folder sheet | Home / Viewer | Pick folder |
| Enhance sheet | Review | Filters |
| Tags sheet | Home ⋯ / Viewer | Toggle colored catalog tags · create tag |
| Tag edit dialog | Settings / Tags sheet | Name + color palette · Delete |
| Activity sheet | Viewer | Created / modified / exported |
| Sort popup | Home | LibrarySort |
| System share | Home / Viewer / Converters | OS share |
| Native print | Viewer | OS print UI |

---

## Library data model (UI-facing)

Stored in each document `meta.json` (+ `library/folders.json` + `library/tags.json`):

| Field | UI use |
|-------|--------|
| `folderId` | Stored but **UI hidden** for now |
| `tags` | List of **tag ids** → colored chips, search (by name), Home filter |
| `isFavorite` | Star, Favorites filter, strip, sort |
| `deletedAt` | Trash vs library; auto-purge by Settings days |
| `exportedAt` | Activity “Exported” |
| `createdAt` / `updatedAt` | Activity + sort |
| `fileSizeBytes` / pages | Sort + card meta |

Default seeded folders: kept in storage; **not shown in UI**.

Default seeded tags (name + color): **Urgent · Work · Personal · Receipt · ID · Finance**. Catalog edited in **Settings → Tags** (tap = edit name/color; Delete in dialog or long-press).

---

## Visual / brand notes (global)

| Token | Role |
|-------|------|
| Navy `#1B3A4B` | Primary (light) |
| Accent `#2F6F7E` | Secondary |
| Paper `#F0F2F5` | Light scaffold |
| Scanner bg `#0E1218` | Scan capture |
| Plus Jakarta Sans | Typography |
| Apptriangle watermark | Preview overlay · **baked into export images** · **drawn on every PDF page** (any viewer) |
| Save to device | System Save as (file manager) · Viewer · Tools · Export toggle |
| App icon | Launcher · Open-with **tool aliases** · Home header (`assets/branding/app_icon.png`) |
| Radii | Sm 12 · Md 16 · Lg 20 · Xl 24 |

Shared widgets: `lib/shared/widgets/app_ui.dart` (buttons, cards, empty, chips, sheets, loading).

---

## Default page processing

1. New page imported (scan or gallery) → **B&W applied automatically**.  
2. User can set **Original** per page on Review (or all via Enhance).  
3. Export uses each page’s display path, then compresses / watermarks per quality presets.

---

## Future-ready (not shipped as widgets)

**Files:** `lib/shared/models/library_models.dart` (`ScanMeWidgetBridge`), `lib/shared/widgets/scanme_widget_bridge.dart`

Architecture stubs for home-screen widgets:

- Android action: `app.atl.scanme.action.SCAN_NOW`  
- iOS URL: `scanme://new-scan`

No Android Glance / iOS WidgetKit UI yet — deep-link router only.

---

## Screen ↔ source map

| Screen / area | Dart file |
|---------------|-----------|
| Home | `lib/features/home/home_screen.dart` |
| Settings | `lib/features/settings/settings_screen.dart` |
| Scan capture | `lib/features/scanner/scan_capture_screen.dart` |
| Review | `lib/features/document_editor/review_screen.dart` |
| Save document | `lib/features/export/export_screen.dart` |
| Viewer | `lib/features/viewer/viewer_screen.dart` |
| Converters hub | `lib/features/converters/converters_hub_screen.dart` |
| Converter logic | `lib/features/converters/document_converter_service.dart` |
| PDF build / prepare | `lib/features/export/pdf_export_service.dart` |
| Library providers | `lib/core/providers.dart` |
| Storage | `lib/core/storage/document_storage_service.dart` |
| Theme + page transitions | `lib/core/theme/app_theme.dart` |
| Motion helpers | `lib/shared/widgets/app_transitions.dart` |
| Cards / FAB / UI kit | `lib/shared/widgets/document_card.dart`, `app_ui.dart` |
| Watermark overlay | `lib/shared/widgets/apptriangle_watermark_overlay.dart` |
| Models | `lib/shared/models/scanned_document.dart`, `library_models.dart` |
