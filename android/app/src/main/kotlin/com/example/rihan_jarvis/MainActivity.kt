package com.example.rihan_jarvis

import android.content.Intent
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.rihan_jarvis/app_control"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "openApp" -> {
                    val appName = call.argument<String>("app")?.lowercase()?.trim()
                    if (appName == null) {
                        result.error("INVALID_ARGS", "App parameter is required", null)
                        return@setMethodCallHandler
                    }

                    when (appName) {
                        "settings" -> {
                            try {
                                val intent = Intent(Settings.ACTION_SETTINGS).apply {
                                    flags = Intent.FLAG_ACTIVITY_NEW_TASK
                                }
                                startActivity(intent)
                                result.success(true)
                            } catch (e: Exception) {
                                result.error("SETTINGS_ERROR", e.message, null)
                            }
                        }
                        "chrome" -> launchPackage("com.android.chrome", result)
                        "youtube" -> launchPackage("com.google.android.youtube", result)
                        "maps" -> launchPackage("com.google.android.apps.maps", result)
                        else -> result.error("UNSUPPORTED_APP", "App '$appName' is not in the allowlist", null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun launchPackage(packageName: String, result: MethodChannel.Result) {
        try {
            val intent = packageManager.getLaunchIntentForPackage(packageName)
            if (intent != null) {
                intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                startActivity(intent)
                result.success(true)
            } else {
                result.error("APP_NOT_INSTALLED", "Package $packageName is not installed", null)
            }
        } catch (e: Exception) {
            result.error("LAUNCH_ERROR", e.message, null)
        }
    }
}
