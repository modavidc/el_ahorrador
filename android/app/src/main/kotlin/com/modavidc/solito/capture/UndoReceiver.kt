package com.elahorrador.app.capture

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import androidx.core.app.NotificationManagerCompat

/** "Deshacer" of a "Registrado" notification. */
class UndoReceiver : BroadcastReceiver() {
    companion object {
        const val MOVEMENT = "movement_id"
        const val NOTIFICATION = "notification_id"
    }

    override fun onReceive(context: Context, intent: Intent) {
        val movementId = intent.getStringExtra(MOVEMENT) ?: return
        NotificationManagerCompat.from(context).cancel(intent.getIntExtra(NOTIFICATION, 0))
        val pending = goAsync()
        BackgroundEngine.undo(context, movementId) { pending.finish() }
    }
}
