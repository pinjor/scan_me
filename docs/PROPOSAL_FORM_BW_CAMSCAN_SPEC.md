# Proposal Form B&W Pipeline — CamScanner-Style Spec

> **ScanMe usage:** This pipeline runs on **every page** after scan/import (default B&W).
> Implementation: `lib/features/filters/cam_scan_bw_filter.dart` (`CamScanBwFilter`).
> Copied from SLI_APP; keep constants/math identical.


**Source of truth in this repo**

| Platform | File | Entry |
|----------|------|--------|
| Android (production) | `android/app/src/main/kotlin/app/sli/sli_app/MainActivity.kt` | `toCamScanBw` |
| iOS (production) | `ios/Runner/DocumentScannerHandler.swift` | `toCamScanBw` |
| Dart (tests / fallback) | `lib/services/document_scan_enhancer.dart` | `processBlackAndWhiteBytes` |

All three implementations use **identical constants and integer math**. Copy any one; results should match within JPEG noise.

**Purpose:** make Sonali Life **proposal form** scans look like a CamScanner “B&W document” page: kill soft pastel / grey watermarks (especially under DOB boxes) without outlining logo edges; keep handwriting and printed ink dark.

**Not used for:** applicant photo, signature (color), or identity docs (plain greyscale only).

---

## 1. When this filter runs

1. User opens native document scanner (ML Kit on Android / VisionKit on iOS).
2. App requests filter wire value `"blackAndWhite"` for `application_form` only.
3. Each page JPEG is cropped/perspective-corrected by the OS scanner first.
4. **Then** this pipeline runs on the page bitmap before save.
5. Output: JPEG quality **82**, long edge capped at **1600**.

Do **not** run this twice (Dart compressor skips re-B&W).

---

## 2. Pipeline overview (order is mandatory)

```
color RGB page
    │
    ▼
[0] Resize long edge ≤ 1600
    │
    ▼
[1] Chroma-aware midtone wash  →  grey buffer (0–255 per pixel)
    │
    ▼
[2] Background flatten (large window)  →  grey buffer
    │
    ▼
[3] Local contrast  →  SKIPPED (pct = 0)
    │
    ▼
[4] Soft Bradley adaptive threshold + paper white floor  →  grey 0/…/255
    │
    ▼
[5] Encode JPEG q=82
```

---

## 3. Constants (must match exactly)

Use **integer** arithmetic as written (`/` = truncating toward zero in Kotlin/Swift/Dart for these ops).

| Name | Value | Role |
|------|------:|------|
| `MAX_BW_LONG_EDGE` | **1600** | Form B&W resize cap (identity grey uses 1280) |
| `JPEG_QUALITY` | **82** | Output JPEG |
| `COLOR_DESAT` | **78** | % pull RGB toward luma |
| `WHITE_WASH` | **90** | Midtone → white strength |
| `INK_FLOOR` | **70** | Below ≈ ink; wash soft above |
| `WASH_CEIL` | **215** | Upper end of wash ramp |
| `MID_LIFT` | **80** | Extra midtone lift after wash |
| `CHROMA_WASH_START` | **8** | Chroma below → no chroma boost |
| `CHROMA_WASH_FULL` | **42** | Chroma at/above → full chroma boost |
| `CHROMA_WASH_BOOST` | **95** | Extra % white for pastel midtones |
| `BG_NORM_HALF` | **48** | ± window for background mean |
| `BG_NEAR_MEAN_SLACK` | **36** | \|g − mean\| ≤ this → paper white |
| `BG_NEAR_MEAN_LIFT` | **88** | Lift toward white if near-mean |
| `LOCAL_CONTRAST_PCT` | **0** | Unsharp off (do not enable) |
| `HALF_WINDOW` | **26** | Bradley window half-size |
| `SUBTRACT` | **12** | Bradley: compare to `mean − 12` |
| `SOFT_BAND` | **30** | Soft ramp instead of hard threshold |
| `WATERMARK_CLEAR` | **115** | Soft result ≥ this may force white |
| `PAPER_MEAN_FLOOR` | **128** | Local mean must be ≥ this to force white |

Derived:

```text
washSpan   = max(WASH_CEIL - INK_FLOOR, 1)     // 145
chromaSpan = max(CHROMA_WASH_FULL - CHROMA_WASH_START, 1)  // 34
denomSoft  = max(2 * SOFT_BAND, 1)             // 60
```

Luma (Rec.601 integer):

```text
Y = (R * 299 + G * 587 + B * 114) / 1000
chroma = max(R,G,B) - min(R,G,B)
```

---

## 4. Step details

### [0] Resize

If `max(width, height) > 1600`, scale proportionally so long edge = 1600 (bilinear / average). Work in `ARGB_8888` / 8-bit RGB.

### [1] Chroma-aware midtone wash → grey

For each pixel `(R,G,B)`:

```text
chroma = max(R,G,B) - min(R,G,B)
y0 = luma(R,G,B)

# desaturate toward grey
R = R + (y0 - R) * COLOR_DESAT / 100
G = G + (y0 - G) * COLOR_DESAT / 100
B = B + (y0 - B) * COLOR_DESAT / 100
y1 = luma(R,G,B)

# quadratic wash amount in midtones
t = clamp((y1 - INK_FLOOR) * 100 / washSpan, 0, 100)
amount = WHITE_WASH * t * t / 10000

# pastel / watermark chroma boost
if chroma > CHROMA_WASH_START and y1 > INK_FLOOR:
    cT = clamp((chroma - CHROMA_WASH_START) * 100 / chromaSpan, 0, 100)
    amount = clamp(amount + CHROMA_WASH_BOOST * cT * t / 10000, 0, 100)

# pull toward white
R = R + (255 - R) * amount / 100
G = G + (255 - G) * amount / 100
B = B + (255 - B) * amount / 100
y2 = luma(R,G,B)

# mid lift
if y2 > INK_FLOOR:
    lift = MID_LIFT * clamp((y2 - INK_FLOOR) * 100 / washSpan, 0, 100) / 100
    y2 = y2 + (255 - y2) * lift / 100

gray[i] = y2   # 0..255
```

**Why:** soft colored watermarks have chroma + midtone luminance → washed toward paper. Dark ink (`y` near/below `INK_FLOOR`) barely moves.

### [2] Background flatten

Build an **integral image** (summed-area table) of `gray`. For each pixel:

```text
mean = local_mean(x, y, half=BG_NORM_HALF)   # clamp window to image
mean = clamp(mean, 1, 255)
g = gray[x,y]
n = clamp(g * 255 / mean, 0, 255)            # divide by local paper

if g >= INK_FLOOR and abs(mean - g) <= BG_NEAR_MEAN_SLACK:
    n = 255                                  # soft logo ≈ paper → white
elif g >= INK_FLOOR and g >= mean - (BG_NEAR_MEAN_SLACK * 2 / 3):
    n = clamp(n + (255 - n) * BG_NEAR_MEAN_LIFT / 100, 0, 255)

gray[x,y] = n
```

**Why:** large window treats watermark texture as local background; thin ink is much darker than mean and stays dark.

### [3] Local contrast — disabled

`LOCAL_CONTRAST_PCT = 0`. Historically unsharp made watermark **edges** under DOB boxes worse. Leave off for exact parity.

### [4] Soft Bradley + paper white floor

Integral image again. Window half = `HALF_WINDOW` (26).

```text
mean = local_mean(x, y, half=26)             # float or int; Android uses float mean = sum/area
diff = gray[x,y] - (mean - SUBTRACT)

if diff >= SOFT_BAND:     v0 = 255
elif diff <= -SOFT_BAND:  v0 = 0
else:                     v0 = clamp((diff + SOFT_BAND) * 255 / denomSoft, 0, 255)

# leftover haze on bright paper → white
if v0 >= WATERMARK_CLEAR and mean >= PAPER_MEAN_FLOOR:
    v = 255
else:
    v = v0

output RGB = (v, v, v)
```

This is a **soft** adaptive threshold (CamScanner-like), not hard binary only.

### [5] JPEG

Compress quality **82**. Prefer software bitmaps (avoid Android `HARDWARE` config without copy).

---

## 5. Integral image (local mean)

```text
sat[0][*] = sat[*][0] = 0
sat[y+1][x+1] = gray[y][x] + sat[y][x+1] + sat[y+1][x] - sat[y][x]

# inclusive rectangle [xa..xb] × [ya..yb] (0-based pixel coords)
sum = sat[yb+1][xb+1] - sat[ya][xb+1] - sat[yb+1][xa] + sat[ya][xa]
area = (xb - xa + 1) * (yb - ya + 1)
mean = sum / area
```

Clamp `xa,xb,ya,yb` to image bounds before summing.

---

## 6. Portable Python reference (exact integer logic)

Drop-in reference for a CamScanner-like app / offline tool. Depends on Pillow + NumPy.

```python
"""SLI proposal-form CamScan B&W — matches MainActivity.toCamScanBw / DocumentScanEnhancer."""

from __future__ import annotations

import numpy as np
from PIL import Image

MAX_BW_LONG_EDGE = 1600
JPEG_QUALITY = 82

COLOR_DESAT = 78
WHITE_WASH = 90
INK_FLOOR = 70
WASH_CEIL = 215
MID_LIFT = 80
CHROMA_WASH_START = 8
CHROMA_WASH_FULL = 42
CHROMA_WASH_BOOST = 95
BG_NORM_HALF = 48
BG_NEAR_MEAN_SLACK = 36
BG_NEAR_MEAN_LIFT = 88
HALF_WINDOW = 26
SUBTRACT = 12
SOFT_BAND = 30
WATERMARK_CLEAR = 115
PAPER_MEAN_FLOOR = 128


def _luma(r: np.ndarray, g: np.ndarray, b: np.ndarray) -> np.ndarray:
    return (r * 299 + g * 587 + b * 114) // 1000


def _resize_long_edge(rgb: np.ndarray, max_edge: int) -> np.ndarray:
    h, w = rgb.shape[:2]
    long_edge = max(w, h)
    if long_edge <= max_edge:
        return rgb
    scale = max_edge / long_edge
    nw, nh = max(1, int(round(w * scale))), max(1, int(round(h * scale)))
    img = Image.fromarray(rgb, mode="RGB")
    img = img.resize((nw, nh), Image.Resampling.BILINEAR)
    return np.asarray(img, dtype=np.uint8)


def _integral(gray: np.ndarray) -> np.ndarray:
    """sat shape (h+1, w+1), int64."""
    return np.pad(gray.astype(np.int64), ((1, 0), (1, 0)), mode="constant").cumsum(0).cumsum(1)


def _local_mean(sat: np.ndarray, x: int, y: int, half: int, w: int, h: int) -> float:
    xa = max(x - half, 0)
    xb = min(x + half, w - 1)
    ya = max(y - half, 0)
    yb = min(y + half, h - 1)
    area = (xb - xa + 1) * (yb - ya + 1)
    s = (
        sat[yb + 1, xb + 1]
        - sat[ya, xb + 1]
        - sat[yb + 1, xa]
        + sat[ya, xa]
    )
    return s / area


def _local_mean_map(gray: np.ndarray, half: int) -> np.ndarray:
    """Vectorized local mean via integral image (same math as pixel loop)."""
    h, w = gray.shape
    sat = _integral(gray)
    # For exact parity with mobile pixel loops, use the loop below for small images
    # or this separable approximation only if you verify bit-match.
    out = np.empty_like(gray, dtype=np.float64)
    for y in range(h):
        for x in range(w):
            out[y, x] = _local_mean(sat, x, y, half, w, h)
    return out


def fade_colors_for_form_watermark(rgb: np.ndarray) -> np.ndarray:
    """Step [1] → uint8 grey (H, W)."""
    r = rgb[:, :, 0].astype(np.int32)
    g = rgb[:, :, 1].astype(np.int32)
    b = rgb[:, :, 2].astype(np.int32)
    chroma = np.maximum(np.maximum(r, g), b) - np.minimum(np.minimum(r, g), b)
    y0 = _luma(r, g, b)
    r = r + (y0 - r) * COLOR_DESAT // 100
    g = g + (y0 - g) * COLOR_DESAT // 100
    b = b + (y0 - b) * COLOR_DESAT // 100
    y1 = _luma(r, g, b)

    wash_span = max(WASH_CEIL - INK_FLOOR, 1)
    chroma_span = max(CHROMA_WASH_FULL - CHROMA_WASH_START, 1)
    t = np.clip((y1 - INK_FLOOR) * 100 // wash_span, 0, 100)
    amount = WHITE_WASH * t * t // 10_000

    boost_mask = (chroma > CHROMA_WASH_START) & (y1 > INK_FLOOR)
    c_t = np.clip((chroma - CHROMA_WASH_START) * 100 // chroma_span, 0, 100)
    amount = np.where(
        boost_mask,
        np.clip(amount + CHROMA_WASH_BOOST * c_t * t // 10_000, 0, 100),
        amount,
    )

    r = r + (255 - r) * amount // 100
    g = g + (255 - g) * amount // 100
    b = b + (255 - b) * amount // 100
    y2 = _luma(r, g, b)

    lift = MID_LIFT * np.clip((y2 - INK_FLOOR) * 100 // wash_span, 0, 100) // 100
    y2 = np.where(y2 > INK_FLOOR, y2 + (255 - y2) * lift // 100, y2)
    return np.clip(y2, 0, 255).astype(np.uint8)


def background_normalize(gray: np.ndarray) -> np.ndarray:
    """Step [2]."""
    h, w = gray.shape
    sat = _integral(gray)
    g = gray.astype(np.int32)
    out = np.empty((h, w), dtype=np.int32)
    slack = BG_NEAR_MEAN_SLACK
    for y in range(h):
        for x in range(w):
            mean = int(_local_mean(sat, x, y, BG_NORM_HALF, w, h))
            mean = max(1, min(255, mean))
            gv = int(g[y, x])
            n = max(0, min(255, (gv * 255) // mean))
            if gv >= INK_FLOOR and abs(mean - gv) <= slack:
                n = 255
            elif gv >= INK_FLOOR and gv >= mean - (slack * 2 // 3):
                n = max(0, min(255, n + (255 - n) * BG_NEAR_MEAN_LIFT // 100))
            out[y, x] = n
    return out.astype(np.uint8)


def soft_bradley(gray: np.ndarray) -> np.ndarray:
    """Step [4]."""
    h, w = gray.shape
    sat = _integral(gray)
    g = gray.astype(np.int32)
    denom = max(2 * SOFT_BAND, 1)
    out = np.empty((h, w), dtype=np.uint8)
    for y in range(h):
        for x in range(w):
            mean = _local_mean(sat, x, y, HALF_WINDOW, w, h)
            diff = g[y, x] - (mean - SUBTRACT)
            if diff >= SOFT_BAND:
                v0 = 255
            elif diff <= -SOFT_BAND:
                v0 = 0
            else:
                v0 = int(max(0, min(255, (diff + SOFT_BAND) * 255 / denom)))
            v = 255 if (v0 >= WATERMARK_CLEAR and mean >= PAPER_MEAN_FLOOR) else v0
            out[y, x] = v
    return out


def proposal_form_camscan_bw(rgb: np.ndarray) -> np.ndarray:
    """
    Full pipeline. Input HxWx3 uint8 RGB (already perspective-cropped).
    Output HxWx3 uint8 greyscale B&W document look.
    """
    rgb = _resize_long_edge(rgb, MAX_BW_LONG_EDGE)
    gray = fade_colors_for_form_watermark(rgb)
    gray = background_normalize(gray)
    # local contrast skipped
    bw = soft_bradley(gray)
    return np.stack([bw, bw, bw], axis=-1)


def process_file(in_path: str, out_path: str) -> None:
    rgb = np.asarray(Image.open(in_path).convert("RGB"), dtype=np.uint8)
    out = proposal_form_camscan_bw(rgb)
    Image.fromarray(out, mode="RGB").save(
        out_path, format="JPEG", quality=JPEG_QUALITY, optimize=True
    )


if __name__ == "__main__":
    import sys

    if len(sys.argv) != 3:
        print("Usage: python proposal_form_bw.py input.jpg output.jpg")
        raise SystemExit(2)
    process_file(sys.argv[1], sys.argv[2])
```

> **Perf note:** nested Python loops are slow. Production Kotlin/Swift use the same O(W·H) math with integral images (fast enough on phone). Port the loops to C++/Kotlin/Swift/GPU; keep constants and formulas identical.

---

## 7. Production Kotlin (canonical)

From `MainActivity.kt` — method `toCamScanBw` + companion constants. Copy this into another Android CamScanner-like app as-is.

```kotlin
// Constants
private const val MAX_BW_SCAN_LONG_EDGE = 1600
private const val JPEG_QUALITY = 82
private const val BW_HALF_WINDOW = 26
private const val BW_SUBTRACT = 12
private const val BW_SOFT_BAND = 30
private const val BW_COLOR_DESAT = 78
private const val BW_WHITE_WASH = 90
private const val BW_INK_FLOOR = 70
private const val BW_WASH_CEIL = 215
private const val BW_MID_LIFT = 80
private const val BW_WATERMARK_CLEAR = 115
private const val BW_PAPER_MEAN_FLOOR = 128
private const val BW_CHROMA_WASH_START = 8
private const val BW_CHROMA_WASH_FULL = 42
private const val BW_CHROMA_WASH_BOOST = 95
private const val BW_BG_NORM_HALF = 48
private const val BW_BG_NEAR_MEAN_SLACK = 36
private const val BW_BG_NEAR_MEAN_LIFT = 88

/**
 * Proposal form: chroma wash → background flatten (kill soft logo under DOB)
 * → soft Bradley. Local contrast off — it was highlighting watermark edges.
 */
private fun toCamScanBw(src: Bitmap): Bitmap {
    val software = when {
        src.config == Bitmap.Config.HARDWARE ->
            src.copy(Bitmap.Config.ARGB_8888, false)
                ?: throw IllegalStateException("HARDWARE bitmap copy failed")
        src.config != Bitmap.Config.ARGB_8888 ->
            src.copy(Bitmap.Config.ARGB_8888, false) ?: src
        else -> src
    }
    val w = software.width
    val h = software.height
    val pixels = IntArray(w * h)
    software.getPixels(pixels, 0, w, 0, 0, w, h)
    if (software !== src) software.recycle()

    val gray = IntArray(w * h)
    val inkFloor = BW_INK_FLOOR
    val washCeil = BW_WASH_CEIL
    val washSpan = (washCeil - inkFloor).coerceAtLeast(1)
    val desat = BW_COLOR_DESAT
    val wash = BW_WHITE_WASH
    val chromaStart = BW_CHROMA_WASH_START
    val chromaFull = BW_CHROMA_WASH_FULL
    val chromaSpan = (chromaFull - chromaStart).coerceAtLeast(1)
    val chromaBoost = BW_CHROMA_WASH_BOOST
    for (i in pixels.indices) {
        val c = pixels[i]
        var r = (c ushr 16) and 0xff
        var g = (c ushr 8) and 0xff
        var b = c and 0xff
        val chroma = maxOf(r, g, b) - minOf(r, g, b)
        val y0 = (r * 299 + g * 587 + b * 114) / 1000
        r = r + ((y0 - r) * desat / 100)
        g = g + ((y0 - g) * desat / 100)
        b = b + ((y0 - b) * desat / 100)
        val y1 = (r * 299 + g * 587 + b * 114) / 1000
        val t = ((y1 - inkFloor) * 100 / washSpan).coerceIn(0, 100)
        var amount = wash * t * t / 10_000
        if (chroma > chromaStart && y1 > inkFloor) {
            val cT = ((chroma - chromaStart) * 100 / chromaSpan).coerceIn(0, 100)
            amount = (amount + chromaBoost * cT * t / 10_000).coerceIn(0, 100)
        }
        r = r + (255 - r) * amount / 100
        g = g + (255 - g) * amount / 100
        b = b + (255 - b) * amount / 100
        var y2 = (r * 299 + g * 587 + b * 114) / 1000
        if (y2 > inkFloor) {
            val lift = BW_MID_LIFT * ((y2 - inkFloor) * 100 / washSpan).coerceIn(0, 100) / 100
            y2 = y2 + (255 - y2) * lift / 100
        }
        gray[i] = y2
    }

    // Background flatten
    run {
        val half = BW_BG_NORM_HALF
        val slack = BW_BG_NEAR_MEAN_SLACK
        val nearLift = BW_BG_NEAR_MEAN_LIFT
        val satC = IntArray((w + 1) * (h + 1))
        val strideC = w + 1
        for (y in 1..h) {
            var rowSum = 0
            val gy = (y - 1) * w
            val sy = y * strideC
            for (x in 1..w) {
                rowSum += gray[gy + x - 1]
                satC[sy + x] = satC[sy - strideC + x] + rowSum
            }
        }
        val flat = IntArray(w * h)
        for (y in 0 until h) {
            val row = y * w
            for (x in 0 until w) {
                val xa = (x - half).coerceAtLeast(0)
                val xb = (x + half).coerceAtMost(w - 1)
                val ya = (y - half).coerceAtLeast(0)
                val yb = (y + half).coerceAtMost(h - 1)
                val area = (xb - xa + 1) * (yb - ya + 1)
                val sum = satC[(yb + 1) * strideC + (xb + 1)] -
                    satC[ya * strideC + (xb + 1)] -
                    satC[(yb + 1) * strideC + xa] +
                    satC[ya * strideC + xa]
                val mean = (sum / area).coerceIn(1, 255)
                val g = gray[row + x]
                var n = ((g * 255) / mean).coerceIn(0, 255)
                if (g >= inkFloor && kotlin.math.abs(mean - g) <= slack) {
                    n = 255
                } else if (g >= inkFloor && g >= mean - (slack * 2 / 3)) {
                    n = (n + (255 - n) * nearLift / 100).coerceIn(0, 255)
                }
                flat[row + x] = n
            }
        }
        System.arraycopy(flat, 0, gray, 0, gray.size)
    }

    // Soft Bradley
    val sat = IntArray((w + 1) * (h + 1))
    val stride = w + 1
    for (y in 1..h) {
        var rowSum = 0
        val gy = (y - 1) * w
        val sy = y * stride
        for (x in 1..w) {
            rowSum += gray[gy + x - 1]
            sat[sy + x] = sat[sy - stride + x] + rowSum
        }
    }

    val half = BW_HALF_WINDOW
    val c = BW_SUBTRACT
    val soft = BW_SOFT_BAND
    val denom = (2 * soft).coerceAtLeast(1)
    val clearFloor = BW_WATERMARK_CLEAR
    val paperMean = BW_PAPER_MEAN_FLOOR
    for (y in 0 until h) {
        val row = y * w
        for (x in 0 until w) {
            val xa = (x - half).coerceAtLeast(0)
            val xb = (x + half).coerceAtMost(w - 1)
            val ya = (y - half).coerceAtLeast(0)
            val yb = (y + half).coerceAtMost(h - 1)
            val area = (xb - xa + 1) * (yb - ya + 1)
            val sum = sat[(yb + 1) * stride + (xb + 1)] -
                sat[ya * stride + (xb + 1)] -
                sat[(yb + 1) * stride + xa] +
                sat[ya * stride + xa]
            val mean = sum / area
            val diff = gray[row + x] - (mean - c)
            val v0 = when {
                diff >= soft -> 255
                diff <= -soft -> 0
                else -> ((diff + soft) * 255 / denom).coerceIn(0, 255)
            }
            val v = if (v0 >= clearFloor && mean >= paperMean) 255 else v0
            pixels[row + x] = -0x1000000 or (v shl 16) or (v shl 8) or v
        }
    }

    val out = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
    out.setPixels(pixels, 0, w, 0, 0, w, h)
    return out
}
```

**Wire-up in a CamScanner-like app**

```kotlin
val scaled = scaleBitmapIfLarge(decoded, MAX_BW_SCAN_LONG_EDGE)
val bw = toCamScanBw(scaled)
bw.compress(Bitmap.CompressFormat.JPEG, JPEG_QUALITY, outputStream)
```

---

## 8. Dart parity (tests)

`lib/services/document_scan_enhancer.dart`:

```dart
static Uint8List processBlackAndWhiteBytes(Uint8List bytes, {int quality = 90}) {
  var im = _resizeIfLarge(decoded, maxEdge); // 1600
  im = _fadeColorsForFormWatermark(im);
  im = img.grayscale(im); // after wash already mono; kept for safety
  im = _backgroundNormalize(im);
  im = _localContrastBoost(im); // no-op when localContrastPct == 0
  im = _softAdaptiveThreshold(
    im,
    halfWindow: adaptiveHalfWindow, // 26
    subtract: adaptiveSubtract,     // 12
    softBand: softBand,             // 30
  );
  return Uint8List.fromList(img.encodeJpg(im, quality: quality));
}
```

Note: Dart test helper often uses JPEG quality **90**; **device scanner saves at 82**. For visual parity with the phone, use **82**.

---

## 9. What this is *not*

| Feature | Status |
|---------|--------|
| Perspective crop / edge detect | Done by OS scanner **before** B&W |
| Hard binary only (0/255) | Soft band + mid greys exist |
| Unsharp / local contrast | Off |
| Identity-doc greyscale | Separate simpler path (luma only, max edge 1280) |
| Color photo / signature | Filter `none` |

---

## 10. Validation checklist (reimplement)

1. Same input crop → pixel-compare grey after step [1], [2], [4] vs Kotlin (before JPEG).
2. Soft watermark under DOB boxes should be mostly white; DOB digits still readable.
3. Handwritten strokes stay dark.
4. Do **not** turn `LOCAL_CONTRAST` back on without re-tuning watermark clear.
5. Cap long edge at 1600 before processing (not after).

---

## 11. Quick parameter tuning guide (only if you diverge)

| Symptom | Try |
|---------|-----|
| Watermark still visible | ↑ `WHITE_WASH` / `CHROMA_WASH_BOOST`, or ↑ `BG_NEAR_MEAN_SLACK` |
| Thin digits washed out | ↓ wash / mid lift; or ↑ `MAX_BW_LONG_EDGE` |
| Logo edges outlined | Keep local contrast **0**; ↑ bg flatten |
| Page too grey / muddy | ↑ `SUBTRACT` slightly or tighten soft band |
| Harsh binary speckles | ↑ `SOFT_BAND` |

Changing constants breaks “exact as SLI proposal form” parity — fork a named preset if you tune.

---

*Generated from SLI_APP scanner code as of 2026-08-12.*
