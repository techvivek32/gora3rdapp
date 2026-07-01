package com.goracabs.gora_cabs

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "gora/overlay"

    // Must match flutter_overlay_window's OverlayConstants.CACHED_TAG.
    private val overlayEngineCacheTag = "myCachedEngine"
    private val overlayActionChannel = "gora/overlay_actions"
    private var overlayActionRegistered = false

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

    override fun onResume() {
        super.onResume()
        // The overlay runs in a separate Flutter engine with no plugins and no
        // Activity, so url_launcher can't work there. Register a native channel on
        // that engine so the overlay's Call/WhatsApp buttons can launch intents.
        registerOverlayActionChannel()
    }

    private fun registerOverlayActionChannel() {
        if (overlayActionRegistered) return
        val overlayEngine = FlutterEngineCache.getInstance().get(overlayEngineCacheTag) ?: return
        MethodChannel(overlayEngine.dartExecutor.binaryMessenger, overlayActionChannel)
            .setMethodCallHandler { call, result ->
                val number = (call.argument<String>("number") ?: "").filter { it.isDigit() || it == '+' }
                when (call.method) {
                    "call" -> {
                        launchIntent(Intent(Intent.ACTION_DIAL, Uri.parse("tel:$number")))
                        result.success(true)
                    }
                    "whatsapp" -> {
                        launchIntent(Intent(Intent.ACTION_VIEW, Uri.parse("https://wa.me/$number")))
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
        overlayActionRegistered = true
    }

    /**
     * Start an activity from a non-Activity context. Uses the application context +
     * NEW_TASK because the app is in the background when the overlay is tapped; the
     * SYSTEM_ALERT_WINDOW permission exempts us from background-activity-start limits.
     */
    private fun launchIntent(intent: Intent) {
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        try {
            applicationContext.startActivity(intent)
        } catch (_: Exception) {
            // No handler (e.g. WhatsApp not installed) — ignore.
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
