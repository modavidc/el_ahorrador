package com.elahorrador.app.reminders

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import com.elahorrador.app.capture.BackgroundEngine
import com.elahorrador.app.capture.CapturePrefs

/** An alarm of Recordatorios: asks Dart what to notify, then re-arms. */
class ReminderReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val slot = intent.getStringExtra(SLOT) ?: return
        val app = context.applicationContext
        val pending = goAsync()
        val keepEngine = BackgroundEngine.isRunning || CapturePrefs.enabled(app)
        BackgroundEngine.reminders(app, slot) { notices ->
            notices.forEach { Reminders.show(app, it) }
            Reminders.scheduleAll(app)
            // The engine stays warm only while the capture uses it.
            if (!keepEngine) BackgroundEngine.destroy()
            pending.finish()
        }
    }

    companion object {
        const val SLOT = "slot"
    }
}
