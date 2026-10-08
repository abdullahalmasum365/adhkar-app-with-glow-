package com.adhkaar365.app

import android.content.SharedPreferences
import android.graphics.Color

object WidgetThemeHelper {
    fun getColor(prefs: SharedPreferences, key: String, defaultColor: Int): Int {
        return try {
            if (prefs.contains(key)) {
                try {
                    prefs.getInt(key, defaultColor)
                } catch (e: ClassCastException) {
                    prefs.getLong(key, defaultColor.toLong()).toInt()
                }
            } else {
                defaultColor
            }
        } catch (e: Exception) {
            defaultColor
        }
    }

    fun getBgColor(prefs: SharedPreferences): Int =
        getColor(prefs, "widget_bg_color", Color.parseColor("#0A1212"))

    fun getSurfaceColor(prefs: SharedPreferences): Int =
        getColor(prefs, "widget_surface_color", Color.parseColor("#1A2E2E"))

    fun getPrimaryColor(prefs: SharedPreferences): Int =
        getColor(prefs, "widget_primary_color", Color.parseColor("#EC7F13"))

    fun getAccentColor(prefs: SharedPreferences): Int =
        getColor(prefs, "widget_accent_color", Color.parseColor("#F59E0B"))

    fun getTextPrimary(prefs: SharedPreferences): Int =
        getColor(prefs, "widget_text_primary", Color.parseColor("#FFFFFF"))

    fun getTextSecondary(prefs: SharedPreferences): Int =
        getColor(prefs, "widget_text_secondary", Color.parseColor("#94A3B8"))

    fun getBorderColor(prefs: SharedPreferences): Int =
        getColor(prefs, "widget_border_color", Color.parseColor("#22FFFFFF"))
}
