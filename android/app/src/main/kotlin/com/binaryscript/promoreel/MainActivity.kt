package com.binaryscript.promoreel

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.OpenableColumns
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream

class MainActivity : FlutterActivity() {
    private val shareChannel = "com.binaryscript.promoreel/whatsapp"
    private val incomingChannel = "com.binaryscript.promoreel/shared_media"

    // Paths to media that arrived via an Android share intent, waiting to be
    // picked up by Flutter on the next `getSharedMedia` call.
    private val pendingSharedPaths = mutableListOf<String>()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handleShareIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleShareIntent(intent)
    }

    private fun handleShareIntent(intent: Intent?) {
        if (intent == null) return
        when (intent.action) {
            Intent.ACTION_SEND -> {
                extractUri(intent)?.let { copyUriToCache(it) }?.let {
                    pendingSharedPaths.add(it)
                }
            }
            Intent.ACTION_SEND_MULTIPLE -> {
                extractUriList(intent)?.forEach { uri ->
                    copyUriToCache(uri)?.let { pendingSharedPaths.add(it) }
                }
            }
        }
    }

    @Suppress("DEPRECATION")
    private fun extractUri(intent: Intent): Uri? {
        return if (Build.VERSION.SDK_INT >= 33) {
            intent.getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java)
        } else {
            intent.getParcelableExtra(Intent.EXTRA_STREAM)
        }
    }

    @Suppress("DEPRECATION")
    private fun extractUriList(intent: Intent): List<Uri>? {
        return if (Build.VERSION.SDK_INT >= 33) {
            intent.getParcelableArrayListExtra(Intent.EXTRA_STREAM, Uri::class.java)
        } else {
            intent.getParcelableArrayListExtra(Intent.EXTRA_STREAM)
        }
    }

    /**
     * Copies a content:// or file:// URI into app cache so Flutter/FFmpeg can
     * read it via a plain filesystem path. Returns the copied file path, or
     * null if the copy failed.
     */
    private fun copyUriToCache(uri: Uri): String? {
        return try {
            val inbox = File(cacheDir, "shared_inbox")
            if (!inbox.exists()) inbox.mkdirs()

            val fileName = queryDisplayName(uri)
                ?: "share_${System.currentTimeMillis()}_${uri.hashCode()}"
            val out = File(inbox, fileName)

            contentResolver.openInputStream(uri)?.use { input ->
                FileOutputStream(out).use { output ->
                    input.copyTo(output)
                }
            } ?: return null

            out.absolutePath
        } catch (e: Exception) {
            null
        }
    }

    private fun isPackageInstalled(pkg: String): Boolean {
        return try {
            applicationContext.packageManager.getPackageInfo(pkg, 0)
            true
        } catch (_: Exception) {
            false
        }
    }

    private fun queryDisplayName(uri: Uri): String? {
        return try {
            contentResolver.query(uri, null, null, null, null)?.use { cursor ->
                if (cursor.moveToFirst()) {
                    val idx = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                    if (idx >= 0) cursor.getString(idx) else null
                } else null
            }
        } catch (_: Exception) {
            null
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Existing WhatsApp-targeted share channel.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, shareChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "shareToWhatsApp" -> {
                        val filePath = call.argument<String>("path")
                        if (filePath == null) {
                            result.error("INVALID_ARGS", "path is required", null)
                            return@setMethodCallHandler
                        }
                        try {
                            val file = File(filePath)
                            val authority = "${applicationContext.packageName}.fileprovider"
                            val contentUri = FileProvider.getUriForFile(
                                applicationContext, authority, file
                            )
                            val sendIntent = Intent(Intent.ACTION_SEND).apply {
                                type = "video/mp4"
                                putExtra(Intent.EXTRA_STREAM, contentUri)
                                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                                setPackage("com.whatsapp")
                            }
                            startActivity(sendIntent)
                            result.success(true)
                        } catch (e: android.content.ActivityNotFoundException) {
                            result.error("NOT_INSTALLED", "WhatsApp not installed", null)
                        } catch (e: Exception) {
                            result.error("SHARE_ERROR", e.message, null)
                        }
                    }
                    "isWhatsAppInstalled" -> {
                        result.success(isPackageInstalled("com.whatsapp"))
                    }
                    "isAppInstalled" -> {
                        val pkg = call.argument<String>("package")
                        if (pkg == null) {
                            result.error("INVALID_ARGS", "package is required", null)
                            return@setMethodCallHandler
                        }
                        result.success(isPackageInstalled(pkg))
                    }
                    "shareVideoToApp" -> {
                        val filePath = call.argument<String>("path")
                        val pkg = call.argument<String>("package")
                        if (filePath == null || pkg == null) {
                            result.error("INVALID_ARGS", "path and package are required", null)
                            return@setMethodCallHandler
                        }
                        try {
                            val file = File(filePath)
                            val authority = "${applicationContext.packageName}.fileprovider"
                            val contentUri = FileProvider.getUriForFile(
                                applicationContext, authority, file
                            )
                            val sendIntent = Intent(Intent.ACTION_SEND).apply {
                                type = "video/mp4"
                                putExtra(Intent.EXTRA_STREAM, contentUri)
                                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                                setPackage(pkg)
                            }
                            startActivity(sendIntent)
                            result.success(true)
                        } catch (e: android.content.ActivityNotFoundException) {
                            result.error("NOT_INSTALLED", "$pkg is not installed", null)
                        } catch (e: Exception) {
                            result.error("SHARE_ERROR", e.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }

        // New channel: Flutter polls for media shared into the app via an
        // Android share intent. Returned paths are cleared on each call.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, incomingChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getSharedMedia" -> {
                        val snapshot = pendingSharedPaths.toList()
                        pendingSharedPaths.clear()
                        result.success(snapshot)
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
