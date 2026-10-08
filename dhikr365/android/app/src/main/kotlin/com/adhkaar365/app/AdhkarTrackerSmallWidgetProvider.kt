package com.adhkaar365.app

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

class AdhkarTrackerSmallWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        val bgColor = WidgetThemeHelper.getBgColor(widgetData)
        val textPrimary = WidgetThemeHelper.getTextPrimary(widgetData)
        val textSecondary = WidgetThemeHelper.getTextSecondary(widgetData)
        val borderColor = WidgetThemeHelper.getBorderColor(widgetData)

        val streakNum = widgetData.getInt("adhkar_small_streak_num", 7).toString()
        val streakLabel = widgetData.getString("adhkar_small_streak_label", "DAYS STREAK") ?: "DAYS STREAK"
        val morningCheck = widgetData.getString("adhkar_small_morning", "🌅 ✓") ?: "🌅 ✓"
        val eveningCheck = widgetData.getString("adhkar_small_evening", "🌆 ○") ?: "🌆 ○"

        for (appWidgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.widget_adhkar_tracker_small).apply {
                setInt(R.id.widget_bg, "setColorFilter", bgColor)
                setInt(R.id.widget_border, "setColorFilter", borderColor)

                setTextViewText(R.id.small_streak_num, streakNum)
                setTextColor(R.id.small_streak_num, textPrimary)

                setTextViewText(R.id.small_streak_label, streakLabel)
                setTextColor(R.id.small_streak_label, textSecondary)

                setTextViewText(R.id.small_morning_check, morningCheck)
                setTextColor(R.id.small_morning_check, textPrimary)

                setTextViewText(R.id.small_evening_check, eveningCheck)
                setTextColor(R.id.small_evening_check, textSecondary)

                val pendingIntent = HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java,
                    Uri.parse("adhkaar365://progress")
                )
                setOnClickPendingIntent(R.id.widget_root, pendingIntent)
            }

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
