package com.adhkaar365.app

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.graphics.Color
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

class PrayerCompactWidgetProvider : HomeWidgetProvider() {

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

        val location = widgetData.getString("prayer_compact_location", "Dhaka") ?: "Dhaka"
        val prayerName = widgetData.getString("prayer_compact_name", "ASR") ?: "ASR"
        val prayerTime = widgetData.getString("prayer_compact_time", "4:18 PM") ?: "4:18 PM"
        val countdown = widgetData.getString("prayer_compact_countdown", "in 34 mins") ?: "in 34 mins"

        for (appWidgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.widget_prayer_compact).apply {
                setInt(R.id.widget_bg, "setColorFilter", bgColor)
                setInt(R.id.widget_border, "setColorFilter", borderColor)
                setInt(R.id.compact_pill_bg, "setColorFilter", primaryColor)

                setTextViewText(R.id.compact_location, location)
                setTextColor(R.id.compact_location, textSecondary)

                setTextViewText(R.id.compact_prayer_name, prayerName)
                setTextColor(R.id.compact_prayer_name, textPrimary)

                setTextViewText(R.id.compact_prayer_time, prayerTime)
                setTextColor(R.id.compact_prayer_time, textSecondary)

                setTextViewText(R.id.compact_countdown, countdown)
                setTextColor(R.id.compact_countdown, Color.WHITE)

                val pendingIntent = HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java,
                    Uri.parse("adhkaar365://prayer_times")
                )
                setOnClickPendingIntent(R.id.widget_root, pendingIntent)
            }

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
