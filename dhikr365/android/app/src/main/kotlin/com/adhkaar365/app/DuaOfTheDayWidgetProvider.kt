package com.adhkaar365.app

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.graphics.Color
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

class DuaOfTheDayWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        val bgColor = WidgetThemeHelper.getBgColor(widgetData)
        val primaryColor = WidgetThemeHelper.getPrimaryColor(widgetData)
        val textPrimary = WidgetThemeHelper.getTextPrimary(widgetData)
        val textSecondary = WidgetThemeHelper.getTextSecondary(widgetData)
        val borderColor = WidgetThemeHelper.getBorderColor(widgetData)

        val headerTitle = widgetData.getString("dua_header_title", "✨ DUA OF THE DAY") ?: "✨ DUA OF THE DAY"
        val categoryBadge = widgetData.getString("dua_category_badge", "Protection") ?: "Protection"
        val arabicText = widgetData.getString(
            "dua_arabic_text",
            "رَبَّنَا آتِنَا فِي الدُّنْيَا حَسَنَةً وَفِي الآخِرَةِ حَسَنَةً"
        ) ?: "رَبَّنَا آتِنَا فِي الدُّنْيَا حَسَنَةً وَفِي الآخِرَةِ حَسَنَةً"
        val translationText = widgetData.getString(
            "dua_translation_text",
            "Our Lord, give us in this world that which is good and in the Hereafter that which is good..."
        ) ?: "Our Lord, give us in this world that which is good and in the Hereafter that which is good..."
        val referenceText = widgetData.getString("dua_reference_text", "— Surah Al-Baqarah: 201") ?: "— Surah Al-Baqarah: 201"

        for (appWidgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.widget_dua_of_day).apply {
                setInt(R.id.widget_bg, "setColorFilter", bgColor)
                setInt(R.id.widget_border, "setColorFilter", borderColor)
                setInt(R.id.dua_badge_bg, "setColorFilter", primaryColor)

                setTextViewText(R.id.dua_header_title, headerTitle)
                setTextColor(R.id.dua_header_title, textPrimary)

                setTextViewText(R.id.dua_category_badge, categoryBadge)
                setTextColor(R.id.dua_category_badge, Color.WHITE)

                setTextViewText(R.id.dua_arabic_text, arabicText)
                setTextColor(R.id.dua_arabic_text, textPrimary)

                setTextViewText(R.id.dua_translation_text, translationText)
                setTextColor(R.id.dua_translation_text, textSecondary)

                setTextViewText(R.id.dua_reference_text, referenceText)
                setTextColor(R.id.dua_reference_text, textSecondary)

                val pendingIntent = HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java,
                    Uri.parse("adhkaar365://dua_of_day")
                )
                setOnClickPendingIntent(R.id.widget_root, pendingIntent)
            }

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
