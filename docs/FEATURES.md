# ScanMe — Feature catalog

> What the app **does** (capabilities), not screen layouts.  
> UI detail: [`UI_PAGES.md`](UI_PAGES.md) · Status / history: [`PROJECT_LOG.md`](PROJECT_LOG.md)  
> **Package:** `app.atl.scanme` · **Offline-first** · No account · Data stays on device  
> Aligned: **2026-08-18** · Version `1.0.2+7`

---

## At a glance

| Area | What you get |
|------|----------------|
| Scan | Native document camera → multi-page draft → enhance → save PDF/images |
| Library | Search, filter, sort, favorites, tags, trash + restore |
| Convert | PDF / Office / text · **Edit photo** (convert/crop/resize/compress) |
| Open with | OS file manager opens ScanMe tools directly |
| QR | Live + photo decode · copy · share · open links |
| Privacy | Local storage · Apptriangle watermark on PDF exports · no cloud account |
| First run | 8-page feature tour (once); access page for camera/photos; replay from Me → About |
| Updates | Soft Play Store reminder (optional · Remind later 3d · Update now) |

---

## 1. Navigation shell

- **Home** — search, shortcut tiles, full library
- **Inner slots** — default **Edit photo** + **Convert** (Me → Navigation; also Favorites, PDF Tools)
- **Scan** — center FAB, docked in a notch on one nav bar
- **Me** — appearance (M3 color presets) · nav slots · trash retention, tags, about
- **Back** — on every *pushed* screen when the stack can pop (tab roots have no back)
- **First launch** — full-screen walkthrough before Home (prefs `onboarding_done_v1`). Access page can Allow camera/photos; Scan/QR/import still ask at use (Guideline 5.1.1).

---

## 2. Document scan & edit

### Capture

- Open system **document scanner**
  - Android: Google ML Kit Document Scanner
  - iOS: VisionKit
- Multi-page draft session
- **Add page** (limit 1 per add on Android)
- Auto-open scanner on new scan flow
- New pages default to **CamScan black & white** look

### Import into a document

- **Import images** from gallery → draft → Review (discard draft on cancel)
- **Images to PDF** style path via import → review → export

### Review / page editor

- Page strip · pinch-zoom preview · page counter
- **Enhance** (this page or all pages):
  - Original · Black & white · Greyscale · Auto enhance · Vivid · Lighten
- **Rotate** page
- **Retake** one page · **Retake all** (confirm)
- **Delete** page (keep ≥1)
- **Add page** / import more
- **Finish** → Save document

### Save document (export)

- Rename document
- Output toggles:
  - **PDF**
  - **Images** (per page)
  - **Also save to device** (system Save-as dialog — user picks folder/name)
- More options:
  - PDF quality: Small / Balanced / High
  - Page size · Orientation
  - Image format JPG/PNG · quality Small / Balanced / High
  - Which pages (all / selection)
- Progress + success / error
- **Apptriangle corner watermark** on every PDF page (and baked into exported images where applicable)

---

## 3. Library (Home)

- Lives on **Home** (no separate Files tab)
- List of scanned documents (cards: thumb, name, meta)
- Convert outputs mixed into **All**, **Favorites**, **Tags**, and search (not Deleted)
- **Search** by name (hidden in Deleted)
- Filter chips: **All · Favorites · Tags · Deleted** + sort
- **Favorites** — bookmark on the thumbnail (scans and converts)
- **Tags** — assign from ⋯ · same catalog as Settings; Tags chip opens wrap immediately
- **Rename**
- **Share** (system share sheet)
- **Open** → Document viewer
- **Move to Trash** (recoverable)
- **Deleted** view:
  - Restore
  - Delete permanently (cannot undo)
- Trash auto-purge after retention days (Settings)
- Empty states per filter (FAB still scans)

> **Folders:** data model exists; **folder UI paused** (no move / Unfiled chips).

---

## 4. Document viewer

- Full-screen page viewer for a saved scan
- **Favorite** toggle
- **Share** pages / PDF
- **Print** (native print dialog)
- **Rename**
- **Tags**
- **Move to Trash**
- Activity / timeline (created · modified · exported) where shown
- Open related PDF in **File viewer** when applicable

---

## 5. Home dashboard

- Brand header + **light/dark theme toggle** (quick)
- Dense **search** — filters the list in place (hidden in Deleted)
- **Shortcuts** — customizable 4-col tile grid  
  Defaults: **Import · PDF Tools · QR reader · Favorites · Edit photo** (+ Add)  
  Long-press remove · Customize sheet · Reset  
  Tags / Favorites / Trash shortcuts apply Home filters (no tab jump)  
  *Not* on shortcuts: Scan (FAB) · Files (removed)
- **Library list** — full un-capped list; scans + converts; bookmark + tags on both
- Card ⋯: Open · Favorite · Tags · Rename · Share · Move to Trash (Deleted: Restore / Delete forever)

### Shortcut catalog (optional pins)

Import · Tags · Favorites · Trash · QR reader · PDF Tools · PDF→txt · PDF→DOCX · txt→PDF · PPTX→PDF · DOCX→PDF · XLSX→CSV · XLSX→PDF · Edit photo

---

## 6. Convert & image tools

All offline. Pick file → convert → **Save** (system Save-as) and/or **Share** · open result in File viewer when useful.

### Documents

| Tool | Does |
|------|------|
| PDF → .txt | Extract text from PDF |
| PDF → DOCX | Editable Word from PDF text (no OCR / layout fidelity) |
| .txt → PDF | Plain text → PDF |
| PPTX → PDF | Slides → PDF |
| DOCX → PDF | Word → PDF |
| XLSX → CSV | First sheet → CSV |
| XLSX → PDF | Spreadsheet → PDF |

### Edit photo (one screen)

Stage any combo on one photo → chips show staged edits → single **Apply** (order: crop → resize → convert → compress).

| Section | Options |
|---------|---------|
| Convert | File type · quality (JPEG/WebP) |
| Crop | Aspect · Free · Exact px · pinch |
| Resize | Long edge / exact pixels |
| Compress | Target KB (output JPEG) |

Changing a section stages it; chip × removes it. No per-tool action buttons.

Open-with lands on matching section.

### PDF Tools (Convert → PDF Tools)

Offline. Original files never overwritten.

| Tool | Does |
|------|------|
| Merge PDFs | Combine 2+ PDFs, reorder first |
| Split PDF | Ranges, selected pages, or every page |
| Reorder pages | Drag order → new PDF |
| Delete pages | Confirm → new PDF of remaining pages |
| Rotate pages | 90° / 180° / counter-clockwise |
| Extract pages | Selected pages → new PDF |
| PDF → images | JPG/PNG · small/balanced/high |
| Images → PDF | Multi image, reorder (same export writer) |
| Compress PDF | Small / balanced / high · reports real size |

---

## 7. Open with (OS integration)

From the device file manager, open a file **with ScanMe** into the matching tool or viewer.

### View

- View PDF · View text · View image · View PPTX (and related types per platform)

### Convert / edit aliases (Android · ScanMe app icon + labels)

PDF→txt · PDF→DOCX · txt→PDF · PPTX→PDF · DOCX→PDF · XLSX→CSV · XLSX→PDF · to JPG/PNG/WebP/GIF · HEIC→JPG · Crop · Resize · Compress · legacy PNG↔JPG aliases

### iOS

Document types / UTIs for PDF, TXT, images, PPTX, DOCX, XLSX, HEIC, WebP, GIF (see Info.plist / PROJECT_LOG).

Intent flow: file arrives → **Intent convert** or edit tool or **File viewer**.

---

## 8. File viewer

Preview converted / opened files with Save + Share:

| Kind | Preview |
|------|---------|
| txt / csv / md / log | Selectable text |
| PDF | PDF preview |
| Image | Pinch-zoom photo |
| PPTX | Slide pager + disclaimer |
| DOCX | Text preview (+ “open in Word for full editing”) |
| Unknown | Cannot preview empty state |

---

## 9. QR / barcode reader

- Live camera scan + **scan from photo**
- Torch toggle
- Formats: QR · Aztec · Data Matrix · PDF417 · Code 128/39 · EAN-8/13 · UPC-A/E
- Result sheet:
  - **URL** → Open link (primary, never auto-open) · Copy · Share · Scan again
  - **Other** → Copy · Share · Scan again
- Stays on device; open link uses system browser

---

## 10. Settings / Me

### Appearance

- Theme: **System · Light · Dark**
- **Themes studio:** 40+ presets. Tap applies app-wide (`ColorScheme.primary` on FAB, nav, filters, convert/PDF/edit-photo tiles, crop handles, update dialog). ScanMe brand stays hand-tuned.
- **Custom themes:** pick 1–3 colors, name, save on device (max 30)

### Navigation

- Home / Scan / Me fixed
- Inner slots: Edit photo · Convert · Favorites · PDF Tools (defaults: Photo + Convert)

### Storage

- **Trash retention:** 7 / 14 / 30 / 60 / 90 days (default 30)

### Tags

- CRUD colored tags (name + color)
- Seeded: Urgent · Work · Personal · Receipt · ID · Finance
- Used from Files / Viewer / Home quick actions

### About

- ScanMe / Apptriangle · version
- Privacy badge: stored privately on device · no account
- **Replay tutorial** — same first-run walkthrough (does not reset other prefs)

### Store updates (Android)

- Optional reminder when Play has a newer build (not blocking)
- **Update now** → Play Store app page · **Remind later** → snooze 3 days

---

## 11. Sharing, print, save-to-device

| Action | Where | Behavior |
|--------|--------|----------|
| Share | Viewer · File viewer · Convert result · QR · Library | System share sheet |
| Print | Viewer | Native print dialog |
| Save to device | Export · Convert · File viewer · Viewer batch | System **Save as** (not silent Downloads) |

---

## 12. Privacy & product principles

- **Offline-first** processing (scan, enhance, convert, QR decode)
- **No account** required
- Documents / tags / prefs in **local app storage**
- PDF exports include **Apptriangle** corner watermark
- Camera / photos only for scan, import, QR, convert picks

---

## 13. Platform notes

| Capability | Android | iOS |
|------------|---------|-----|
| Document scan | ML Kit | VisionKit |
| Open-with tool aliases | Activity aliases + icons | Document types / UTIs |
| HEIC / WebP / GIF tools | Supported via codecs / bridges | Supported |
| Edge-to-edge / Play policies | Addressed for Play ship | — |

---

## 14. Explicitly not in UI (yet)

| Item | State |
|------|--------|
| Folder browse / move / Unfiled | Model kept · **UI paused** |
| Cloud sync / accounts | Not offered |
| OCR for PDF→DOCX/txt | Text extract only · not full OCR layout |

---

## Quick map: user goals → features

| I want to… | Use |
|------------|-----|
| Digitize paper | FAB Scan → Review → Save |
| Photos → PDF | Import images → Review → Save PDF |
| Find a scan | Home search / All · Favorites · Tags |
| Mark important | Favorite · Tags |
| Share or print | Viewer Share / Print |
| Crop/resize/shrink a photo | Edit photo → Crop / Resize / Compress |
| Convert a photo format | Edit photo → Convert |
| Open file from Files app | Open with ScanMe alias |
| Read a QR / barcode | QR reader shortcut |
| Undo a delete | Home → Deleted → Restore |
| Switch dark mode | Home toggle or Me → Appearance |
