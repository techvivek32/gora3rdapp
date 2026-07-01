package com.goracabs.gora_cabs

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "gora/overlay"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "canDrawOverlays" -> result.success(canDrawOverlays())
                    "openOverlaySettings" -> {
                        openOverlaySettings()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun canDrawOverlays(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            Settings.canDrawOverlays(this)
        } else {
            true
        }
    }

    /**
     * Opens the "Display over other apps" permission screen. Different OEMs (MIUI /
     * HyperOS in particular) bury this behind their own permission editor and the
     * standard AOSP intent can open a blank/black page, so we try a chain of
     * intents and stop at the first one that resolves.
     */
    private fun openOverlaySettings() {
        // Order of preference:
        // 1) The app-specific "Display over other apps" toggle (verified to render
        //    correctly, including on MIUI/HyperOS).
        // 2) The full overlay-permission list.
        // 3) The app-details page as a guaranteed fallback.
        val intents = listOf(
            Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION, Uri.parse("package:$packageName")),
            Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION),
            Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:$packageName")),
        )

        // Try each in order; startActivity throws ActivityNotFoundException when an
        // intent can't be handled (more reliable than resolveActivity, which is
        // filtered by package visibility on Android 11+), so we just catch & retry.
        for (intent in intents) {
            try {
                startActivity(intent)
                return
            } catch (_: Exception) {
                // Try the next fallback.
            }
        }
    }
}
