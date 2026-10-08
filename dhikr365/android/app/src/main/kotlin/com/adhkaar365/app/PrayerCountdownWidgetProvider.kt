package com.adhkaar365.app

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.graphics.Color
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

class PrayerCountdownWidgetProvider : HomeWidgetProvider() {

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

        val location = widgetData.getString("prayer_location", "Dhaka, BD") ?: "Dhaka, BD"
        val currentWaqt = widgetData.getString("prayer_current_waqt", "DHUHR") ?: "DHUHR"
        val nextTitle = widgetData.getString("prayer_next_title", "Asr in 34 mins") ?: "Asr in 34 mins"
        val nextSubtitle = widgetData.getString("prayer_next_subtitle", "Next prayer: 4:18 PM") ?: "Next prayer: 4:18 PM"
        val progressPercent = widgetData.getInt("prayer_progress_percent", 60)

        val fajrTime = widgetData.getString("prayer_fajr_time", "4:42") ?: "4:42"
        val dhuhrTime = widgetData.getString("prayer_dhuhr_time", "11:58") ?: "11:58"
        val asrTime = widgetData.getString("prayer_asr_time", "4:18") ?: "4:18"
        val maghribTime = widgetData.getString("prayer_maghrib_time", "5:50") ?: "5:50"
        val ishaTime = widgetData.getString("prayer_isha_time", "7:04") ?: "7:04"

        for (appWidgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.widget_prayer_countdown).apply {
                // Dynamic colors
                setInt(R.id.widget_bg, "setColorFilter", bgColor)
                setInt(R.id.widget_border, "setColorFilter", borderColor)
                setInt(R.id.current_waqt_bg, "setColorFilter", primaryColor)

                // Texts
                setTextViewText(R.id.location_text, location)
                setTextColor(R.id.location_text, textSecondary)

                setTextViewText(R.id.current_waqt_badge, currentWaqt)
                setTextColor(R.id.current_waqt_badge, Color.WHITE)

                setTextViewText(R.id.next_prayer_title, nextTitle)
                setTextColor(R.id.next_prayer_title, textPrimary)

                setTextViewText(R.id.next_prayer_subtitle, nextSubtitle)
                setTextColor(R.id.next_prayer_subtitle, textSecondary)

                setProgressBar(R.id.prayer_progress_bar, 100, progressPercent, false)

                // 5 Prayers
                setTextViewText(R.id.tv_fajr_time, fajrTime)
                setTextViewText(R.id.tv_dhuhr_time, dhuhrTime)
                setTextViewText(R.id.tv_asr_time, asrTime)
                setTextViewText(R.id.tv_maghrib_time, maghribTime)
                setTextViewText(R.id.tv_isha_time, ishaTime)

                setTextColor(R.id.tv_fajr_name, textSecondary)
                setTextColor(R.id.tv_dhuhr_name, textSecondary)
                setTextColor(R.id.tv_asr_name, textSecondary)
                setTextColor(R.id.tv_maghrib_name, textSecondary)
                setTextColor(R.id.tv_isha_name, textSecondary)

                setTextColor(R.id.tv_fajr_time, textPrimary)
                setTextColor(R.id.tv_dhuhr_time, textPrimary)
                setTextColor(R.id.tv_asr_time, textPrimary)
                setTextColor(R.id.tv_maghrib_time, textPrimary)
                setTextColor(R.id.tv_isha_time, textPrimary)

                // Deep link on click
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
