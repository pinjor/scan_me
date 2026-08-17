# ScanMe — Feature catalog

> What the app **does** (capabilities), not screen layouts.  
> UI detail: [`UI_PAGES.md`](UI_PAGES.md) · Status / history: [`PROJECT_LOG.md`](PROJECT_LOG.md)  
> **Package:** `app.atl.scanme` · **Offline-first** · No account · Data stays on device  
> Aligned: **2026-08-17** · Version `1.0.0+2`

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

---

## 1. Navigation shell

- **Home** — search, shortcut tiles, continue (recents)
- **Files** — full library / recently deleted
- **Scan (center FAB)** — start document capture
- **Convert** — document + image tools hub
- **Me** — appearance, trash retention, tags, about
- **Back** — on every *pushed* screen when the stack can pop (tab roots have no back)

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

## 3. Library (Files)

- List of scanned documents (cards: thumb, name, meta)
- **Search** by name
- Filter chips (e.g. favorites / tags — see UI_PAGES)
- **Sort** (library sort options)
- **Favorites** bookmark
- **Tags** — assign / edit colored tags
- **Rename**
- **Share** (system share sheet)
- **Open** → Document viewer
- **Move to Trash** (recoverable)
- **Recently deleted** view:
  - Restore
  - Delete permanently (cannot undo)
- Trash auto-purge after retention days (Settings)
- Empty states with Scan / Import CTAs when library empty

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
- Dense **search** (library)
- **Shortcuts** — customizable 4-col tile grid  
  Defaults: **Import · QR reader · Favorites · Edit photo** (+ Add)  
  Long-press remove · Customize sheet · Reset  
  *Not* on shortcuts: Scan (FAB) · Convert (Convert tab)
- **Continue** — recent documents → open viewer
- Quick actions on cards (Open · Tags · View all files)

### Shortcut catalog (optional pins)

Import · Files · Tags · Favorites · Trash · QR reader · PDF→txt · PDF→DOCX · txt→PDF · PPTX→PDF · DOCX→PDF · XLSX→CSV · XLSX→PDF · Edit photo

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

---

## 7. Open with (OS integration)

From the device file manager, open a file **with ScanMe** into the matching tool or viewer.

### View

- View PDF · View text · View image · View PPTX (and related types per platform)

### Convert / edit aliases (Android icons + labels)

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

### Storage

- **Trash retention:** 7 / 14 / 30 / 60 / 90 days (default 30)

### Tags

- CRUD colored tags (name + color)
- Seeded: Urgent · Work · Personal · Receipt · ID · Finance
- Used from Files / Viewer / Home quick actions

### About

- ScanMe / Apptriangle · version
- Privacy badge: stored privately on device · no account

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
| Find a scan | Home search / Files / Continue |
| Mark important | Favorite · Tags |
| Share or print | Viewer Share / Print |
| Crop/resize/shrink a photo | Edit photo → Crop / Resize / Compress |
| Convert a photo format | Edit photo → Convert |
| Open file from Files app | Open with ScanMe alias |
| Read a QR / barcode | QR reader shortcut |
| Undo a delete | Files → Recently deleted → Restore |
| Switch dark mode | Home toggle or Me → Appearance |
