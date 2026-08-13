# ScanMe — UI pages reference

Offline CamScanner-style app (Flutter). Brand: **ScanMe** / Apptriangle. Theme: navy + paper surfaces, **Plus Jakarta Sans**, light / dark / system.

This doc describes every in-app screen, sheet, overlay, and system UI the user hits — including library organization, export options, converters, print, trash, and motion.

---

## Navigation map

```
Home (library)
├── Settings
│   ├── Appearance (system / light / dark)
│   └── Trash retention (7–90 days)
├── FAB (+) speed dial
│   ├── Scan Document → [System scanner] → Scan capture → Review → Save document → Home
│   ├── Images to PDF → [Gallery picker] → Review → Save document → Home
│   └── Converters → pick file → convert → Share
├── Trash toggle (header) → soft-deleted docs (restore / delete forever)
├── Filters: folders · favorites · tags · search · sort
└── Document row / ⋯ / open → Viewer
    ├── Favorite · Print · Share
    ├── Rename · Move folder · Tags · Activity
    └── Move to Trash → Home
```

System UIs (not Flutter screens):

| UI | Platform | When |
|----|----------|------|
| Google ML Kit Document Scanner | Android | Each single-page capture / retake |
| VisionKit document camera | iOS | Each single-page capture / retake |
| System photo / gallery picker | Both | Images to PDF |
| File picker | Both | Converters (PDF / PPTX / images) |
| System share sheet | Both | Share PDF, images, or convert outputs |
| Native print dialog | Both | Viewer → Print (`printing`) |

---

## Motion / transitions (global)

**File:** `lib/shared/widgets/app_transitions.dart`  
**Theme:** `lib/core/theme/app_theme.dart` (`pageTransitionsTheme`)

| Motion | Where |
|--------|--------|
| `AppPageRoute` — fade + slight rise | Push/pop between Home, Settings, Scan, Review, Export, Viewer, Converters |
| `AppBodySwitch` | Home loading ↔ empty ↔ list |
| `StaggeredListItem` | Document list rows, favorites strip |
| `FadeRiseIn` | Empty states, converters hub, loading overlay |
| `AppCard` press scale | Tappable cards |
| Bottom sheet content fade/slide | `showAppBottomSheet` |
| Hero `doc-thumb-<id>` | Home list thumbnail → Viewer |
| AnimatedSwitcher | Export progress text, Viewer page footer, favorite star |
| FAB speed dial | Size/fade expand of actions |

---

## 1. Home (`HomeScreen`)

**File:** `lib/features/home/home_screen.dart`  
**Entry:** App launch (`MaterialApp.home`)

### Purpose
Local document library: browse, filter, sort, trash, start scan / images-to-PDF / converters.

### Layout
- **Header:** logo + **ScanMe** (or **Trash**) · Trash / Settings icons
- **Search** · hint *Search…*
- **Filter chips + Sort** (one row)
- **Body:** list / empty / skeleton
- **FAB:** speed dial

### Empty states
- Title only + action buttons (no long marketing copy)

### Document card
- Thumb · name · meta line · optional folder/tag badges · **⋯**

### FAB speed dial
1. Scan Document · 2. Images to PDF · 3. Converters

### Flows from Home

| Control | Next |
|---------|------|
| Scan Document | Scan capture (auto-opens system scanner) |
| Images to PDF | Multi-image picker → import + auto B&W → Review (`discardOnPop: true`) |
| Converters | Converters hub |
| Open row / Open | Viewer |
| Trash toggle | Soft-deleted list |
| Sort / folder / tag / search | Filtered `filterAndSortDocuments` list |

---

## 2. Settings (`SettingsScreen`)

**File:** `lib/features/settings/settings_screen.dart`  
**Entry:** Home → settings icon

### Purpose
Theme, trash auto-empty, about.

### Layout
- App bar: `Settings`
- **Appearance** — Match phone setting · Light · Dark (persisted)
- **Trash** — Auto-empty after **7 / 14 / 30 / 60 / 90** days (default 30)
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
- **This page** bar: **B&W** | **Original**
- **Thumbnail strip:** reorderable + **+** add page
- **Toolbar:** Enhance · Rotate · Retake · Delete · More (Retake all)

### Enhance sheet
- Original (this page) · Black & white (this page)  
- Black & white on all pages · Original on all pages

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
- CTA: **Save on this device** (disabled if both formats off or busy)

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
  - **⋯** menu: Rename · Move to folder · Tags · Activity · Move to Trash
- Optional chip row: folder name + tags
- **Gallery:** swipe / zoom (`PhotoViewGallery`) + watermark · Hero from list
- **Footer:** `Page X of Y` (crossfades on page change)

### Sheets / dialogs
- **Tags:** add / remove chips  
- **Activity:** Created · Modified · Exported (dates)  
- **Move to folder:** Unfiled or folder list  
- Rename dialog · Move to Trash confirm → soft-delete → pop Home

### States
Loading · missing doc / no pages · missing page file

---

## 8. Converters (`ConvertersHubScreen`)

**File:** `lib/features/converters/converters_hub_screen.dart`  
**Service:** `lib/features/converters/document_converter_service.dart`  
**Entry:** Home FAB → Converters

### Purpose
On-device file conversion (no upload). Outputs under app `converts/` folder.

### Layout
- App bar: `Converters`
- Intro: *Convert files on this device…*
- Tiles:

| Tile | Input | Output | Notes |
|------|-------|--------|--------|
| PDF → Text | `.pdf` | `.txt` | Text extract; image-only PDFs may be empty |
| PowerPoint → PDF | `.pptx` | `.pdf` | Best-effort text + embedded images |
| PNG → JPG | images | `.jpg` | Flattens transparency |
| JPG → PNG | `.jpg` / `.jpeg` | `.png` | |

- Progress while converting  
- **Share** card when result ready

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
| Tags sheet | Viewer | Add / remove tags |
| Activity sheet | Viewer | Created / modified / exported |
| Sort popup | Home | LibrarySort |
| System share | Home / Viewer / Converters | OS share |
| Native print | Viewer | OS print UI |

---

## Library data model (UI-facing)

Stored in each document `meta.json` (+ `library/folders.json`):

| Field | UI use |
|-------|--------|
| `folderId` | Folder chips / move / Unfiled |
| `tags` | Chips, search, filter |
| `isFavorite` | Star, Favorites filter, strip, sort |
| `deletedAt` | Trash vs library; auto-purge by Settings days |
| `exportedAt` | Activity “Exported” |
| `createdAt` / `updatedAt` | Activity + sort |
| `fileSizeBytes` / pages | Sort + card meta |

Default seeded folders: **Work · Personal · Receipts · IDs · Certificates · Finance**.

---

## Visual / brand notes (global)

| Token | Role |
|-------|------|
| Navy `#1B3A4B` | Primary (light) |
| Accent `#2F6F7E` | Secondary |
| Paper `#F0F2F5` | Light scaffold |
| Scanner bg `#0E1218` | Scan capture |
| Plus Jakarta Sans | Typography |
| Apptriangle watermark | Preview + exports (bottom-right) |
| App icon | Launcher + Home header (`assets/branding/app_icon.png`) |
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
