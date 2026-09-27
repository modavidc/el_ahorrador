package com.elahorrador.app.capture

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/** Starts the capture again after a reboot or an update. */
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action
        if (action != Intent.ACTION_BOOT_COMPLETED &&
            action != Intent.ACTION_MY_PACKAGE_REPLACED
        ) {
            return
        }
        if (CapturePrefs.enabled(context)) AppChannel.startService(context)
    }
}
