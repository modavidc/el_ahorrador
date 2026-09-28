package com.elahorrador.app.capture

import android.app.Notification
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification

/**
 * Reads payment notifications of Yape, Plin and Peruvian banks ("Te
 * yapearon S/ 50") and registers them without a screenshot.
 */
class PaymentNotificationListener : NotificationListenerService() {
    companion object {
        private val SOURCES = mapOf(
            "com.bcp.innovacxion.yapeapp" to "Yape",
            "com.bcp.bank.bcp" to "BCP",
            "com.bbva.nxt_peru" to "BBVA",
            "pe.com.interbank.mobilebanking" to "Interbank",
            "pe.com.scotiabank.blpm.android.client" to "Scotiabank",
        )
    }

    override fun onNotificationPosted(sbn: StatusBarNotification) {
        if (!CapturePrefs.enabled(this)) return
        val source = SOURCES[sbn.packageName] ?: return
        val extras = sbn.notification.extras
        val title = extras.getCharSequence(Notification.EXTRA_TITLE)?.toString() ?: ""
        val body = extras.getCharSequence(Notification.EXTRA_BIG_TEXT)?.toString()
            ?: extras.getCharSequence(Notification.EXTRA_TEXT)?.toString()
            ?: ""
        if (title.isBlank() && body.isBlank()) return
        // The app name helps the reader tell the source apart.
        val text = "$source\n$title\n$body"
        BackgroundEngine.processText(this, text, "Aviso de $source") { result ->
            ResultNotifier.show(this, result)
        }
    }
}
