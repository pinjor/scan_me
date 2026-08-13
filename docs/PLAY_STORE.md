# ScanMe — Google Play readiness

**Application ID:** `app.atl.scanme`  
*(Requested `app.atl.scan-me` — Android IDs cannot contain hyphens, so the Play-valid form is `app.atl.scanme`.)*

**Display name:** ScanMe  
**Publisher:** Apptriangle  

---

## What’s already configured

| Item | Status |
|------|--------|
| App icon (adaptive Android + iOS) | Done — `assets/branding/app_icon.png` |
| `applicationId` / namespace | `app.atl.scanme` |
| iOS bundle ID | `app.atl.scanme` |
| `minSdk` ≥ 21 (ML Kit) | Yes |
| `targetSdk` from Flutter | Yes (current AGP/Flutter defaults) |
| Release minify + ProGuard (ML Kit keep rules) | Yes |
| Upload keystore wiring via `android/key.properties` | Template provided |
| Cleartext HTTP disabled | Yes |
| Cloud/device backup of scans disabled | Yes |
| Camera usage string (iOS) | Yes |
| Offline local storage (no account) | Yes |
| Apptriangle watermark on exports | Yes |

---

## Before first Play upload

### 1. Create upload keystore

```bash
keytool -genkey -v -keystore android/upload-keystore.jks \
  -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

Copy `android/key.properties.example` → `android/key.properties` and fill in passwords / paths.  
**Never commit** `key.properties` or `*.jks`.

### 2. Build App Bundle

```bash
flutter build appbundle --release
```

Output: `build/app/outputs/bundle/release/app-release.aab`

### 3. Play Console listing (manual)

Prepare in Play Console:

- Short description (≤80 chars)
- Full description
- Screenshots: phone (mandatory), 7" / 10" tablet optional
- Feature graphic 1024×500
- Privacy policy URL (required — scans stay on device; state that clearly)
- Data safety form: no data collected / no sharing (if accurate)
- Content rating questionnaire
- Target audience / news apps declarations as applicable

### 4. Privacy policy bullets (suggested)

- ScanMe stores documents only on the device
- No account, no cloud sync by the app
- Camera used only for document scanning (via Google ML Kit Document Scanner on Android)
- Optional share uses the system share sheet (user-initiated)

### 5. Device / GMS note

Android scanning requires **Google Play services**. Call this out in the listing description for devices without GMS.

---

## Versioning

Bump in `pubspec.yaml`:

```yaml
version: 1.0.0+1   # name+code → versionName+versionCode
```

Each Play upload needs a higher `+build` number.

---

## Smoke test checklist

- [ ] Fresh install → launcher icon correct
- [ ] New scan → ML Kit opens
- [ ] B&W + export PDF/JPEG → Apptriangle watermark present
- [ ] Share / rename / delete
- [ ] Theme light/dark/system
- [ ] Release AAB installs via internal testing track
