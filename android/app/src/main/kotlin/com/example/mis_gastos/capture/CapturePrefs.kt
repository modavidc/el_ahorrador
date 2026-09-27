package com.elahorrador.app.capture

import android.content.Context

/** Background capture settings, readable by the service without Flutter. */
object CapturePrefs {
    private const val FILE = "el_ahorrador_capture"

    private fun prefs(context: Context) =
        context.getSharedPreferences(FILE, Context.MODE_PRIVATE)

    fun enabled(context: Context): Boolean = prefs(context).getBoolean("enabled", false)

    fun setEnabled(context: Context, enabled: Boolean) =
        prefs(context).edit().putBoolean("enabled", enabled).apply()

    /** Permissions Android cannot report (autostart, lock in recents). */
    fun confirmed(context: Context, name: String): Boolean =
        prefs(context).getBoolean("confirmed_$name", false)

    fun confirm(context: Context, name: String) =
        prefs(context).edit().putBoolean("confirmed_$name", true).apply()

    fun lastImageId(context: Context): Long = prefs(context).getLong("last_image_id", -1)

    fun setLastImageId(context: Context, id: Long) =
        prefs(context).edit().putLong("last_image_id", id).apply()
}
