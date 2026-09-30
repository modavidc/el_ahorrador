package com.modavidc.solito.capture

import android.app.Service
import android.content.ContentUris
import android.content.Intent
import android.content.pm.ServiceInfo
import android.database.ContentObserver
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.HandlerThread
import android.os.IBinder
import android.provider.MediaStore
import androidx.core.app.NotificationCompat
import androidx.core.app.ServiceCompat
import com.modavidc.solito.R
import java.io.File

/**
 * Foreground service that watches new screenshots. Each one is copied to
 * the cache and read by [BackgroundEngine]; images that are not payments
 * are ignored in silence.
 */
class ScreenshotCaptureService : Service() {
    companion object {
        const val ACTION_PAUSE = "com.modavidc.solito.capture.PAUSE"

        /** Screenshots older than this when noticed are not new. */
        private const val RECENT_SECONDS = 20L
    }

    private lateinit var thread: HandlerThread
    private lateinit var handler: Handler
    private var observer: ContentObserver? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        ResultNotifier.createChannels(this)
        thread = HandlerThread("screenshot-capture").also { it.start() }
        handler = Handler(thread.looper)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_PAUSE) {
            CapturePrefs.setEnabled(this, false)
            stopSelf()
            return START_NOT_STICKY
        }
        startInForeground()
        if (observer == null) {
            observer = object : ContentObserver(handler) {
                override fun onChange(selfChange: Boolean, uri: Uri?) {
                    // The file may still be written: look again shortly.
                    handler.removeCallbacksAndMessages(null)
                    handler.postDelayed({ scan() }, 400)
                    handler.postDelayed({ scan() }, 1500)
                }
            }.also {
                contentResolver.registerContentObserver(
                    MediaStore.Images.Media.EXTERNAL_CONTENT_URI,
                    true,
                    it,
                )
            }
        }
        // Warm the engine now so the first screenshot is fast.
        BackgroundEngine.warmUp(this)
        return START_STICKY
    }

    override fun onDestroy() {
        observer?.let { contentResolver.unregisterContentObserver(it) }
        observer = null
        thread.quitSafely()
        BackgroundEngine.destroy()
        super.onDestroy()
    }

    private fun startInForeground() {
        val pause = android.app.PendingIntent.getService(
            this,
            1,
            Intent(this, ScreenshotCaptureService::class.java).setAction(ACTION_PAUSE),
            android.app.PendingIntent.FLAG_IMMUTABLE,
        )
        val notification = NotificationCompat.Builder(this, ResultNotifier.STATUS_CHANNEL)
            .setSmallIcon(R.drawable.ic_stat_solito)
            .setColor(0xFFD33F2B.toInt())
            .setContentTitle("Captura de pagos")
            .setContentText("Captura activa · toma una captura de tu pago")
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_MIN)
            .setContentIntent(ResultNotifier.openApp(this))
            .addAction(0, "Pausar", pause)
            .build()
        val type = if (Build.VERSION.SDK_INT >= 34) {
            ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE
        } else {
            0
        }
        ServiceCompat.startForeground(this, ResultNotifier.STATUS_ID, notification, type)
    }

    /** Reads the screenshots added since the last one handled. */
    private fun scan() {
        val since = System.currentTimeMillis() / 1000 - RECENT_SECONDS
        val projection = mutableListOf(
            MediaStore.Images.Media._ID,
            MediaStore.Images.Media.DISPLAY_NAME,
            MediaStore.Images.Media.DATE_ADDED,
        )
        if (Build.VERSION.SDK_INT >= 29) {
            projection += MediaStore.Images.Media.RELATIVE_PATH
            projection += MediaStore.Images.Media.IS_PENDING
        } else {
            @Suppress("DEPRECATION")
            projection += MediaStore.Images.Media.DATA
        }
        val last = CapturePrefs.lastImageId(this)
        val found = mutableListOf<Long>()
        try {
            contentResolver.query(
                MediaStore.Images.Media.EXTERNAL_CONTENT_URI,
                projection.toTypedArray(),
                "${MediaStore.Images.Media.DATE_ADDED} >= ? AND ${MediaStore.Images.Media._ID} > ?",
                arrayOf(since.toString(), last.toString()),
                "${MediaStore.Images.Media._ID} ASC",
            )?.use { cursor ->
                while (cursor.moveToNext()) {
                    val id = cursor.getLong(0)
                    val name = cursor.getString(1) ?: ""
                    val where = cursor.getString(3) ?: ""
                    val pending = Build.VERSION.SDK_INT >= 29 && cursor.getInt(4) == 1
                    if (pending) continue
                    val isScreenshot = "screenshot" in name.lowercase() ||
                        "screenshot" in where.lowercase() ||
                        "captura" in name.lowercase()
                    if (isScreenshot) found += id
                }
            }
        } catch (_: SecurityException) {
            return
        }
        for (id in found) {
            CapturePrefs.setLastImageId(this, id)
            read(id)
        }
    }

    private fun read(id: Long) {
        val uri = ContentUris.withAppendedId(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, id)
        val copy = File(cacheDir, "capture_$id.jpg")
        try {
            contentResolver.openInputStream(uri)?.use { input ->
                copy.outputStream().use { input.copyTo(it) }
            } ?: return
        } catch (_: Exception) {
            return
        }
        BackgroundEngine.processImage(this, copy.absolutePath) { result ->
            ResultNotifier.show(this, result)
            copy.delete()
        }
    }
}
