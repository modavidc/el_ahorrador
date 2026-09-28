package com.modavidc.solito.reminders

import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import com.modavidc.solito.R
import com.modavidc.solito.capture.ResultNotifier
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.util.Calendar

/**
 * Recordatorios: one alarm at the chosen hour (daily reminder, budget
 * alert) and one at 09:00 (weekly and monthly recaps). Each alarm wakes
 * the background engine, which decides what to notify from the ledger.
 *
 * Channel `solito/reminders`: `schedule({evening, hour, minute,
 * morning, morningHour})` and `show({id, title, body})`.
 */
object Reminders {
    const val EVENING = "evening"
    const val MORNING = "morning"
    private const val CHANNEL = "solito/reminders"
    private const val NOTICE_CHANNEL = "reminders"
    private const val PREFS = "solito_reminders"

    fun attach(context: Context, messenger: BinaryMessenger) {
        val app = context.applicationContext
        MethodChannel(messenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "schedule" -> {
                    val args = call.arguments as? Map<*, *> ?: emptyMap<String, Any>()
                    prefs(app).edit()
                        .putBoolean(EVENING, args["evening"] as? Boolean ?: false)
                        .putInt("hour", (args["hour"] as? Number)?.toInt() ?: 21)
                        .putInt("minute", (args["minute"] as? Number)?.toInt() ?: 0)
                        .putBoolean(MORNING, args["morning"] as? Boolean ?: false)
                        .putInt("morningHour", (args["morningHour"] as? Number)?.toInt() ?: 9)
                        .apply()
                    scheduleAll(app)
                    result.success(null)
                }
                "show" -> {
                    show(app, call.arguments as? Map<*, *> ?: emptyMap<String, Any>())
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    /** Sets both alarms from the saved plan (also after a reboot). */
    fun scheduleAll(context: Context) {
        val p = prefs(context)
        arm(context, EVENING, p.getBoolean(EVENING, false), p.getInt("hour", 21), p.getInt("minute", 0))
        arm(context, MORNING, p.getBoolean(MORNING, false), p.getInt("morningHour", 9), 0)
    }

    fun show(context: Context, notice: Map<*, *>) {
        val title = notice["title"] as? String ?: return
        val body = notice["body"] as? String ?: ""
        createChannel(context)
        val id = 4300 + ((notice["id"] as? String)?.hashCode() ?: 0).mod(100)
        val notification = NotificationCompat.Builder(context, NOTICE_CHANNEL)
            .setSmallIcon(R.drawable.ic_stat_solito)
            .setColor(0xFFD33F2B.toInt())
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(NotificationCompat.BigTextStyle().bigText(body))
            .setAutoCancel(true)
            .setContentIntent(ResultNotifier.openApp(context))
            .build()
        try {
            NotificationManagerCompat.from(context).notify(id, notification)
        } catch (_: SecurityException) {
            // Notifications are off.
        }
    }

    private fun arm(context: Context, slot: String, on: Boolean, hour: Int, minute: Int) {
        val alarms = context.getSystemService(AlarmManager::class.java)
        val intent = PendingIntent.getBroadcast(
            context,
            slot.hashCode(),
            Intent(context, ReminderReceiver::class.java).putExtra(ReminderReceiver.SLOT, slot),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        alarms.cancel(intent)
        if (!on) return
        val next = Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, hour)
            set(Calendar.MINUTE, minute)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
            if (timeInMillis <= System.currentTimeMillis()) add(Calendar.DAY_OF_YEAR, 1)
        }
        // Inexact on purpose: no exact-alarm permission, and a few minutes
        // late is fine for a reminder.
        alarms.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, next.timeInMillis, intent)
    }

    private fun createChannel(context: Context) {
        if (Build.VERSION.SDK_INT < 26) return
        context.getSystemService(NotificationManager::class.java).createNotificationChannel(
            NotificationChannel(
                NOTICE_CHANNEL,
                "Recordatorios y resúmenes",
                NotificationManager.IMPORTANCE_DEFAULT,
            ).apply { description = "Aviso diario, recaps y alerta de presupuesto" },
        )
    }

    private fun prefs(context: Context) =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
}
