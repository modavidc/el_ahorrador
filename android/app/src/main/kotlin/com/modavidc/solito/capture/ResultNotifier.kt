package com.modavidc.solito.capture

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import com.modavidc.solito.MainActivity
import com.modavidc.solito.R

/** Notifications of the capture: the fixed one and "Registrado · Deshacer". */
object ResultNotifier {
    const val STATUS_CHANNEL = "capture_status"
    const val RESULT_CHANNEL = "capture_results"
    const val STATUS_ID = 4100
    private var nextId = 4200

    fun createChannels(context: Context) {
        if (Build.VERSION.SDK_INT < 26) return
        val manager = context.getSystemService(NotificationManager::class.java)
        manager.createNotificationChannel(
            NotificationChannel(
                STATUS_CHANNEL,
                "Captura de pagos",
                NotificationManager.IMPORTANCE_MIN,
            ).apply { description = "Aviso fijo mientras la captura está activa" },
        )
        manager.createNotificationChannel(
            NotificationChannel(
                RESULT_CHANNEL,
                "Pagos registrados",
                NotificationManager.IMPORTANCE_HIGH,
            ).apply { description = "Cada pago que se registra solo" },
        )
    }

    fun openApp(context: Context): PendingIntent = PendingIntent.getActivity(
        context,
        0,
        Intent(context, MainActivity::class.java)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP),
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
    )

    /** Shows the outcome Dart wrote; silent outcomes have no title. */
    fun show(context: Context, result: Map<*, *>?) {
        val title = result?.get("title") as? String ?: return
        val body = result["body"] as? String ?: ""
        val id = nextId++
        val builder = NotificationCompat.Builder(context, RESULT_CHANNEL)
            .setSmallIcon(R.drawable.ic_stat_solito)
            .setColor(0xFFD33F2B.toInt())
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(NotificationCompat.BigTextStyle().bigText(body))
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(true)
            .setContentIntent(openApp(context))
        val movementId = result["movementId"] as? String
        if (movementId != null) {
            val undo = Intent(context, UndoReceiver::class.java)
                .putExtra(UndoReceiver.MOVEMENT, movementId)
                .putExtra(UndoReceiver.NOTIFICATION, id)
            builder.addAction(
                0,
                "Deshacer",
                PendingIntent.getBroadcast(
                    context,
                    id,
                    undo,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
                ),
            )
        }
        try {
            NotificationManagerCompat.from(context).notify(id, builder.build())
        } catch (_: SecurityException) {
            // Notifications are off; the movement is registered anyway.
        }
    }
}
