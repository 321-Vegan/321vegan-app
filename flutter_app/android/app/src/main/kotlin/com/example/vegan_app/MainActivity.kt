package com.app321vegan.veganapp

import android.content.ActivityNotFoundException
import android.content.ContentValues
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Files given to the person (lib/helpers/pdf_download.dart)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "app.321vegan/files")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "saveToDownloads" -> try {
                        result.success(
                            saveToDownloads(
                                call.argument<String>("path")!!,
                                call.argument<String>("name")!!,
                                call.argument<String>("mimeType")!!,
                            )
                        )
                    } catch (e: Exception) {
                        result.error("save_failed", e.message, null)
                    }
                    "openUri" -> result.success(
                        openUri(call.argument<String>("uri")!!, call.argument<String>("mimeType")!!)
                    )
                    else -> result.notImplemented()
                }
            }
    }

    /// Copies the file into Téléchargements and returns its content uri, or
    /// null before Android 10 (writing there would need a permission).
    private fun saveToDownloads(path: String, name: String, mimeType: String): String? {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) return null
        val resolver = contentResolver
        val values = ContentValues().apply {
            put(MediaStore.Downloads.DISPLAY_NAME, name)
            put(MediaStore.Downloads.MIME_TYPE, mimeType)
            put(MediaStore.Downloads.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS)
            put(MediaStore.Downloads.IS_PENDING, 1)
        }
        val uri = resolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values)
            ?: throw IllegalStateException("MediaStore insert failed")
        try {
            resolver.openOutputStream(uri).use { output ->
                File(path).inputStream().use { it.copyTo(output!!) }
            }
            values.clear()
            values.put(MediaStore.Downloads.IS_PENDING, 0)
            resolver.update(uri, values, null, null)
        } catch (e: Exception) {
            resolver.delete(uri, null, null)
            throw e
        }
        return uri.toString()
    }

    /// Opens the uri in the app chosen for [mimeType]; false when none.
    private fun openUri(uri: String, mimeType: String): Boolean {
        val intent = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(Uri.parse(uri), mimeType)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        return try {
            startActivity(intent)
            true
        } catch (e: ActivityNotFoundException) {
            false
        }
    }
}
