package com.elahorrador.app.capture

import android.Manifest
import android.app.Activity
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import androidx.core.app.ActivityCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat

/**
 * The permissions of `CapturePermission` in Dart, by name: photos, alerts,
 * notifications, battery, autostart, recents.
 */
object CapturePermissions {
    const val REQUEST_CODE = 4107

    private val isXiaomi: Boolean
        get() = Build.MANUFACTURER.equals("xiaomi", ignoreCase = true) ||
            Build.MANUFACTURER.equals("redmi", ignoreCase = true) ||
            Build.MANUFACTURER.equals("poco", ignoreCase = true)

    private val photosPermission: String
        get() = if (Build.VERSION.SDK_INT >= 33) Manifest.permission.READ_MEDIA_IMAGES
        else Manifest.permission.READ_EXTERNAL_STORAGE

    private fun has(context: Context, permission: String) =
        ContextCompat.checkSelfPermission(context, permission) ==
            PackageManager.PERMISSION_GRANTED

    fun granted(context: Context): List<String> {
        val result = mutableListOf<String>()
        if (has(context, photosPermission)) result += "photos"
        val alerts = if (Build.VERSION.SDK_INT >= 33) {
            has(context, Manifest.permission.POST_NOTIFICATIONS)
        } else {
            NotificationManagerCompat.from(context).areNotificationsEnabled()
        }
        if (alerts) result += "alerts"
        if (NotificationManagerCompat.getEnabledListenerPackages(context)
                .contains(context.packageName)
        ) {
            result += "notifications"
        }
        val power = context.getSystemService(Context.POWER_SERVICE) as PowerManager
        if (power.isIgnoringBatteryOptimizations(context.packageName)) result += "battery"
        // Only Xiaomi's HyperOS/MIUI blocks autostart by default.
        if (!isXiaomi || CapturePrefs.confirmed(context, "autostart")) result += "autostart"
        if (CapturePrefs.confirmed(context, "recents")) result += "recents"
        return result
    }

    /** Asks for [name] or opens its system page. */
    fun open(activity: Activity, name: String) {
        when (name) {
            "photos" -> request(activity, photosPermission)
            "alerts" -> if (Build.VERSION.SDK_INT >= 33) {
                request(activity, Manifest.permission.POST_NOTIFICATIONS)
            } else {
                openAppDetails(activity)
            }
            "notifications" -> start(
                activity,
                Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS),
            )
            "battery" -> {
                val direct = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS)
                    .setData(Uri.parse("package:${activity.packageName}"))
                if (!start(activity, direct)) {
                    start(activity, Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS))
                }
            }
            "autostart" -> {
                CapturePrefs.confirm(activity, "autostart")
                val miui = Intent().setComponent(
                    ComponentName(
                        "com.miui.securitycenter",
                        "com.miui.permcenter.autostart.AutoStartManagementActivity",
                    ),
                )
                if (!start(activity, miui)) openAppDetails(activity)
            }
            // There is no page for it: the user locks the app in recents.
            "recents" -> CapturePrefs.confirm(activity, "recents")
        }
    }

    private fun request(activity: Activity, permission: String) {
        val deniedBefore = !ActivityCompat.shouldShowRequestPermissionRationale(
            activity,
            permission,
        ) && CapturePrefs.confirmed(activity, "asked_$permission")
        if (deniedBefore) {
            // Android no longer shows the dialog: send the user to settings.
            openAppDetails(activity)
            return
        }
        CapturePrefs.confirm(activity, "asked_$permission")
        ActivityCompat.requestPermissions(activity, arrayOf(permission), REQUEST_CODE)
    }

    private fun openAppDetails(activity: Activity) {
        start(
            activity,
            Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
                .setData(Uri.parse("package:${activity.packageName}")),
        )
    }

    private fun start(activity: Activity, intent: Intent): Boolean = try {
        activity.startActivity(intent)
        true
    } catch (_: Exception) {
        false
    }
}
