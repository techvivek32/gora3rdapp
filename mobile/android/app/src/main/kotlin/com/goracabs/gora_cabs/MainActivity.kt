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
        val intents = mutableListOf<Intent>()

        val appDetails = Intent(
            Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
            Uri.parse("package:$packageName"),
        )

        val manufacturer = Build.MANUFACTURER.lowercase()
        val isXiaomi = manufacturer.contains("xiaomi") ||
            manufacturer.contains("redmi") ||
            manufacturer.contains("poco")

        if (isXiaomi) {
            // MIUI / HyperOS: both the AOSP overlay page and the securitycenter
            // permission-editor deep-link frequently open a blank/black screen on
            // newer builds. The standard App-info page is the one screen that
            // always renders, so open it directly; the user turns on "Other
            // permissions -> Display over other apps" from there.
            intents.add(appDetails)
        } else {
            // Standard AOSP overlay-permission page for this app.
            intents.add(
                Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION, Uri.parse("package:$packageName"))
            )
            // Standard AOSP overlay-permission full list (no package data).
            intents.add(Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION))
            // Last resort: this app's details page.
            intents.add(appDetails)
        }

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
