package app.atl.scanme

import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.OpenableColumns
import android.view.WindowManager
import android.webkit.MimeTypeMap
import androidx.core.view.WindowCompat
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.io.File
import java.io.FileOutputStream

/**
 * Edge-to-edge host + “Open with” tool aliases (view / convert).
 * Copies content:// URIs into cache and notifies Flutter via [openChannelName].
 */
class MainActivity : FlutterFragmentActivity() {
    private val openChannelName = "app.atl.scanme/open_file"
    private val codecChannelName = "app.atl.scanme/image_codec"
    private var openChannel: MethodChannel? = null
    private var pendingOpen: Map<String, String>? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        // Java EdgeToEdge.enable — Play Pre-launch looks for this.
        PlayEdgeToEdge.enable(this)
        applyEdgeToEdgeCutout()
        super.onCreate(savedInstanceState)
        // FlutterFragmentActivity.onCreate may reset chrome; pin cutout again.
        applyEdgeToEdgeCutout()
    }

    override fun onPostResume() {
        super.onPostResume()
        applyEdgeToEdgeCutout()
    }

    /**
     * Backward-compat edge-to-edge + cutout ALWAYS (not deprecated SHORT_EDGES).
     */
    private fun applyEdgeToEdgeCutout() {
        WindowCompat.setDecorFitsSystemWindows(window, false)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            val lp = window.attributes
            lp.layoutInDisplayCutoutMode =
                WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_ALWAYS
            window.attributes = lp
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        openChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            openChannelName,
        ).also { channel ->
            channel.setMethodCallHandler { call, result ->
                when (call.method) {
                    "getInitialFile" -> {
                        val payload = pendingOpen
                        pendingOpen = null
                        result.success(payload)
                    }
                    else -> result.notImplemented()
                }
            }
        }
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            codecChannelName,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "heicToJpeg" -> {
                    val path = call.argument<String>("path")
                    if (path.isNullOrBlank()) {
                        result.error("bad_args", "path required", null)
                        return@setMethodCallHandler
                    }
                    try {
                        val jpeg = heicFileToJpeg(path)
                        if (jpeg == null) {
                            result.error("decode", "Could not decode HEIC", null)
                        } else {
                            result.success(jpeg)
                        }
                    } catch (e: Exception) {
                        result.error("decode", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
        handleViewIntent(intent)
    }

    private fun heicFileToJpeg(path: String, maxLongEdge: Int = 4096): ByteArray? {
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeFile(path, bounds)
        val w = bounds.outWidth
        val h = bounds.outHeight
        if (w <= 0 || h <= 0) return null

        var sample = 1
        val longEdge = maxOf(w, h)
        while (longEdge / sample > maxLongEdge) {
            sample *= 2
        }

        val opts = BitmapFactory.Options().apply {
            inSampleSize = sample
            inPreferredConfig = Bitmap.Config.ARGB_8888
        }
        val bitmap = BitmapFactory.decodeFile(path, opts) ?: return null
        return try {
            val out = ByteArrayOutputStream()
            if (!bitmap.compress(Bitmap.CompressFormat.JPEG, 90, out)) null
            else out.toByteArray()
        } finally {
            bitmap.recycle()
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleViewIntent(intent)
    }

    private fun handleViewIntent(intent: Intent?) {
        if (intent?.action != Intent.ACTION_VIEW) return
        val uri = intent.data ?: return
        try {
            val path = copyUriToCache(uri, intent.type) ?: return
            val action = resolveOpenAction(intent)
            val payload = mapOf("path" to path, "action" to action)
            pendingOpen = payload
            openChannel?.invokeMethod("onOpenFile", payload)
        } catch (_: Exception) {
            // Ignore — Flutter can show an error if user retries.
        }
    }

    /** Which activity-alias opened this file (see AndroidManifest). */
    private fun resolveOpenAction(intent: Intent): String {
        val cls = intent.component?.className ?: return "view"
        return when {
            cls.endsWith(".OpenPdfToTxt") -> "pdfToTxt"
            cls.endsWith(".OpenPdfToDocx") -> "pdfToDocx"
            cls.endsWith(".OpenTxtToPdf") -> "txtToPdf"
            cls.endsWith(".OpenPptxToPdf") -> "pptxToPdf"
            cls.endsWith(".OpenDocxToPdf") -> "docxToPdf"
            cls.endsWith(".OpenXlsxToCsv") -> "xlsxToCsv"
            cls.endsWith(".OpenXlsxToPdf") -> "xlsxToPdf"
            cls.endsWith(".OpenPngToJpg") || cls.endsWith(".OpenToJpg") -> "toJpg"
            cls.endsWith(".OpenJpgToPng") || cls.endsWith(".OpenToPng") -> "toPng"
            cls.endsWith(".OpenToWebp") -> "toWebp"
            cls.endsWith(".OpenToGif") -> "toGif"
            cls.endsWith(".OpenHeicToJpg") -> "heicToJpg"
            cls.endsWith(".OpenCropImage") -> "crop"
            cls.endsWith(".OpenResizeImage") -> "resize"
            cls.endsWith(".OpenCompressImage") -> "compress"
            else -> "view"
        }
    }

    private fun copyUriToCache(uri: Uri, mimeHint: String?): String? {
        val resolver = contentResolver
        val display = queryDisplayName(uri)
        val name = when {
            display != null && display.contains('.') -> display
            display != null -> display + extensionForMime(uri, mimeHint)
            else -> "scanme_open_${System.currentTimeMillis()}${extensionForMime(uri, mimeHint)}"
        }
        val safe = name.replace(Regex("""[\\/:*?"<>|]"""), "_")
        var out = File(cacheDir, "incoming_$safe")
        if (out.exists()) {
            out = File(cacheDir, "incoming_${System.currentTimeMillis()}_$safe")
        }
        resolver.openInputStream(uri)?.use { input ->
            FileOutputStream(out).use { output -> input.copyTo(output) }
        } ?: return null
        return out.absolutePath
    }

    private fun queryDisplayName(uri: Uri): String? {
        val cursor = contentResolver.query(uri, null, null, null, null) ?: return null
        cursor.use {
            val idx = it.getColumnIndex(OpenableColumns.DISPLAY_NAME)
            if (idx < 0 || !it.moveToFirst()) return null
            return it.getString(idx)
        }
    }

    private fun extensionForMime(uri: Uri, mimeHint: String?): String {
        val mime = mimeHint
            ?: contentResolver.getType(uri)
            ?: return ".bin"
        val ext = MimeTypeMap.getSingleton().getExtensionFromMimeType(mime)
        return if (ext.isNullOrBlank()) {
            when (mime) {
                "application/vnd.openxmlformats-officedocument.presentationml.presentation" ->
                    ".pptx"
                else -> ".bin"
            }
        } else {
            ".$ext"
        }
    }
}
