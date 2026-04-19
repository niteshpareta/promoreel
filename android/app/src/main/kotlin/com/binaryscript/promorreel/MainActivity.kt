package com.binaryscript.promorreel

import android.content.Intent
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val channel = "com.binaryscript.statuspro/whatsapp"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channel)
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
                            val intent = Intent(Intent.ACTION_SEND).apply {
                                type = "video/mp4"
                                putExtra(Intent.EXTRA_STREAM, contentUri)
                                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                                setPackage("com.whatsapp")
                            }
                            startActivity(intent)
                            result.success(true)
                        } catch (e: android.content.ActivityNotFoundException) {
                            result.error("NOT_INSTALLED", "WhatsApp not installed", null)
                        } catch (e: Exception) {
                            result.error("SHARE_ERROR", e.message, null)
                        }
                    }
                    "isWhatsAppInstalled" -> {
                        val pm = applicationContext.packageManager
                        val installed = try {
                            pm.getPackageInfo("com.whatsapp", 0)
                            true
                        } catch (_: Exception) { false }
                        result.success(installed)
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
