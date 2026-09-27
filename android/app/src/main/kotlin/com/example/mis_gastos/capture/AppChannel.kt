package com.elahorrador.app.capture

import android.app.Activity
import android.content.Intent
import android.os.Build
import android.os.Handler
import android.os.Looper
import androidx.core.content.ContextCompat
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/**
 * Channel `el_ahorrador/capture` between the open app and the capture
 * service: state, switch, permission pages, and "captured" so the open
 * screens refresh.
 */
object AppChannel {
    private const val NAME = "el_ahorrador/capture"
    private var channel: MethodChannel? = null
    private val main = Handler(Looper.getMainLooper())

    fun attach(activity: Activity, messenger: BinaryMessenger) {
        channel = MethodChannel(messenger, NAME).apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    "state" -> result.success(state(activity))
                    "setEnabled" -> {
                        setEnabled(activity, call.arguments as? Boolean ?: false)
                        result.success(state(activity))
                    }
                    "openSettings" -> {
                        CapturePermissions.open(activity, call.arguments as String)
                        result.success(state(activity))
                    }
                    else -> result.notImplemented()
                }
            }
        }
    }

    fun detach() {
        channel?.setMethodCallHandler(null)
        channel = null
    }

    /** Sends the permissions again (after a dialog or returning to the app). */
    fun pushState(activity: Activity) = main.post {
        channel?.invokeMethod("state", state(activity))
        // Starts the service once its permissions arrive.
        if (CapturePrefs.enabled(activity)) startService(activity)
    }

    fun notifyCaptured() = main.post { channel?.invokeMethod("captured", null) }

    private fun state(activity: Activity): Map<String, Any> = mapOf(
        "enabled" to CapturePrefs.enabled(activity),
        "granted" to CapturePermissions.granted(activity),
    )

    private fun setEnabled(activity: Activity, enabled: Boolean) {
        CapturePrefs.setEnabled(activity, enabled)
        if (enabled) {
            startService(activity)
        } else {
            activity.stopService(Intent(activity, ScreenshotCaptureService::class.java))
        }
    }

    fun startService(context: android.content.Context) {
        if (!CapturePermissions.granted(context).contains("photos")) return
        val intent = Intent(context, ScreenshotCaptureService::class.java)
        try {
            if (Build.VERSION.SDK_INT >= 26) {
                ContextCompat.startForegroundService(context, intent)
            } else {
                context.startService(intent)
            }
        } catch (_: Exception) {
            // Android refuses to start it now (e.g. from the background).
        }
    }
}
