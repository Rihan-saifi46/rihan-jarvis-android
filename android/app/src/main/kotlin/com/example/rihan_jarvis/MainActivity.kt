package com.example.rihan_jarvis

import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.provider.Settings
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.rihan_jarvis/app_control"
    private val TAG = "JARVIS_NATIVE"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            Log.d(TAG, "MethodChannel call received: method='${call.method}', args='${call.arguments}'")
            when (call.method) {
                "openApp" -> {
                    val appName = call.argument<String>("app")?.lowercase()?.trim()
                    if (appName == null) {
                        Log.e(TAG, "openApp failed: App parameter is required")
                        result.error("INVALID_ARGS", "App parameter is required", null)
                        return@setMethodCallHandler
                    }

                    when (appName) {
                        "settings" -> {
                            try {
                                Log.d(TAG, "Opening Android Settings...")
                                val intent = Intent(Settings.ACTION_SETTINGS).apply {
                                    flags = Intent.FLAG_ACTIVITY_NEW_TASK
                                }
                                startActivity(intent)
                                Log.d(TAG, "Android Settings opened successfully")
                                result.success(true)
                            } catch (e: Exception) {
                                Log.e(TAG, "SETTINGS_ERROR: ${e.message}", e)
                                result.error("SETTINGS_ERROR", e.message, null)
                            }
                        }
                        "chrome" -> launchPackage("com.android.chrome", result)
                        "youtube" -> launchPackage("com.google.android.youtube", result)
                        "maps" -> launchPackage("com.google.android.apps.maps", result)
                        else -> {
                            Log.w(TAG, "Unsupported app requested: $appName")
                            result.error("UNSUPPORTED_APP", "App '$appName' is not in the allowlist", null)
                        }
                    }
                }
                "makeCall" -> {
                    val phoneNumber = call.argument<String>("phoneNumber")?.trim()
                    if (phoneNumber.isNullOrEmpty()) {
                        Log.e(TAG, "makeCall failed: Phone number is empty")
                        result.error("INVALID_ARGS", "Phone number is required", null)
                        return@setMethodCallHandler
                    }

                    try {
                        Log.d(TAG, "Opening ACTION_DIAL with tel:$phoneNumber")
                        // ACTION_DIAL opens dialer with prefilled number - no CALL_PHONE permission required
                        val intent = Intent(Intent.ACTION_DIAL).apply {
                            data = Uri.parse("tel:$phoneNumber")
                            flags = Intent.FLAG_ACTIVITY_NEW_TASK
                        }
                        startActivity(intent)
                        Log.d(TAG, "ACTION_DIAL started successfully for $phoneNumber")
                        result.success(true)
                    } catch (e: Exception) {
                        Log.e(TAG, "DIAL_ERROR: ${e.message}", e)
                        result.error("DIAL_ERROR", e.message, null)
                    }
                }
                "sendSms" -> {
                    val phoneNumber = call.argument<String>("phoneNumber")?.trim()
                    val message = call.argument<String>("message")?.trim() ?: ""
                    if (phoneNumber.isNullOrEmpty()) {
                        Log.e(TAG, "sendSms failed: Phone number is empty")
                        result.error("INVALID_ARGS", "Phone number is required", null)
                        return@setMethodCallHandler
                    }

                    try {
                        Log.d(TAG, "Opening ACTION_SENDTO with smsto:$phoneNumber and message preview: '$message'")
                        // ACTION_SENDTO with smsto: opens SMS app with recipient & message prefilled - no SEND_SMS permission required
                        val intent = Intent(Intent.ACTION_SENDTO).apply {
                            data = Uri.parse("smsto:$phoneNumber")
                            putExtra("sms_body", message)
                            flags = Intent.FLAG_ACTIVITY_NEW_TASK
                        }
                        startActivity(intent)
                        Log.d(TAG, "ACTION_SENDTO started successfully for $phoneNumber")
                        result.success(true)
                    } catch (e: Exception) {
                        Log.e(TAG, "SMS_ERROR: ${e.message}", e)
                        result.error("SMS_ERROR", e.message, null)
                    }
                }
                "openWhatsApp" -> {
                    val phoneNumber = call.argument<String>("phoneNumber")?.trim()
                    val message = call.argument<String>("message")?.trim() ?: ""
                    if (phoneNumber.isNullOrEmpty()) {
                        Log.e(TAG, "openWhatsApp failed: Phone number is empty")
                        result.error("INVALID_ARGS", "Phone number is required", null)
                        return@setMethodCallHandler
                    }

                    try {
                        val encodedMsg = Uri.encode(message)
                        val uri = Uri.parse("https://wa.me/$phoneNumber?text=$encodedMsg")

                        // Support both regular WhatsApp and WhatsApp Business (w4b)
                        val targetPackage = when {
                            isPackageInstalled("com.whatsapp") -> "com.whatsapp"
                            isPackageInstalled("com.whatsapp.w4b") -> "com.whatsapp.w4b"
                            else -> null
                        }

                        Log.d(TAG, "openWhatsApp targeting package: $targetPackage, URI: $uri")

                        val intent = Intent(Intent.ACTION_VIEW, uri).apply {
                            if (targetPackage != null) {
                                setPackage(targetPackage)
                            }
                            flags = Intent.FLAG_ACTIVITY_NEW_TASK
                        }

                        startActivity(intent)
                        Log.d(TAG, "WhatsApp conversation launched successfully")
                        result.success(true)
                    } catch (e: Exception) {
                        Log.w(TAG, "WhatsApp native launch failed: ${e.message}")
                        result.error("APP_NOT_INSTALLED", "WhatsApp is not installed: ${e.message}", null)
                    }
                }
                "startMickeyService" -> {
                    try {
                        Log.d(TAG, "Starting MickeyService foreground service...")
                        val serviceIntent = Intent(this, MickeyService::class.java).apply {
                            action = MickeyService.ACTION_START_MICKEY
                        }
                        androidx.core.content.ContextCompat.startForegroundService(this, serviceIntent)
                        result.success(true)
                    } catch (e: Exception) {
                        Log.e(TAG, "Failed to start MickeyService: ${e.message}", e)
                        result.error("SERVICE_START_ERROR", e.message, null)
                    }
                }
                "stopMickeyService" -> {
                    try {
                        Log.d(TAG, "Stopping MickeyService...")
                        val serviceIntent = Intent(this, MickeyService::class.java).apply {
                            action = MickeyService.ACTION_STOP_MICKEY
                        }
                        startService(serviceIntent)
                        result.success(true)
                    } catch (e: Exception) {
                        Log.e(TAG, "Failed to stop MickeyService: ${e.message}", e)
                        result.error("SERVICE_STOP_ERROR", e.message, null)
                    }
                }
                "isMickeyServiceRunning" -> {
                    result.success(MickeyService.isRunning)
                }
                else -> {
                    Log.w(TAG, "Method not implemented: ${call.method}")
                    result.notImplemented()
                }
            }
        }
    }

    private fun isPackageInstalled(packageName: String): Boolean {
        return try {
            packageManager.getPackageInfo(packageName, 0)
            true
        } catch (e: PackageManager.NameNotFoundException) {
            false
        }
    }

    private fun launchPackage(packageName: String, result: MethodChannel.Result) {
        try {
            Log.d(TAG, "launchPackage called for: $packageName")
            val intent = packageManager.getLaunchIntentForPackage(packageName)
            if (intent != null) {
                intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                startActivity(intent)
                Log.d(TAG, "startActivity succeeded for package: $packageName")
                result.success(true)
            } else {
                Log.w(TAG, "Package $packageName launch intent is null (not installed or hidden)")
                result.error("APP_NOT_INSTALLED", "Package $packageName is not installed", null)
            }
        } catch (e: Exception) {
            Log.e(TAG, "LAUNCH_ERROR for $packageName: ${e.message}", e)
            result.error("LAUNCH_ERROR", e.message, null)
        }
    }
}
