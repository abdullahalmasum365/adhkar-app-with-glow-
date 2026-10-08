package com.adhkaar365.app

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.graphics.Color
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

class AdhkarTrackerWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        val bgColor = WidgetThemeHelper.getBgColor(widgetData)
        val surfaceColor = WidgetThemeHelper.getSurfaceColor(widgetData)
        val primaryColor = WidgetThemeHelper.getPrimaryColor(widgetData)
        val textPrimary = WidgetThemeHelper.getTextPrimary(widgetData)
        val textSecondary = WidgetThemeHelper.getTextSecondary(widgetData)
        val borderColor = WidgetThemeHelper.getBorderColor(widgetData)

        val headerTitle = widgetData.getString("adhkar_header_title", "DAILY ADHKAAR") ?: "DAILY ADHKAAR"
        val streakText = widgetData.getString("adhkar_streak_text", "🔥 7-DAY STREAK") ?: "🔥 7-DAY STREAK"
        val morningTitle = widgetData.getString("adhkar_morning_title", "🌅 Morning") ?: "🌅 Morning"
        val morningStatus = widgetData.getString("adhkar_morning_status", "✓ 18/18 Done") ?: "✓ 18/18 Done"
        val morningProgress = widgetData.getInt("adhkar_morning_progress", 100)

        val eveningTitle = widgetData.getString("adhkar_evening_title", "🌆 Evening") ?: "🌆 Evening"
        val eveningStatus = widgetData.getString("adhkar_evening_status", "Pending (0/12)") ?: "Pending (0/12)"
        val eveningProgress = widgetData.getInt("adhkar_evening_progress", 0)

        val footerText = widgetData.getString(
            "adhkar_footer_text",
            "In the remembrance of Allah do hearts find rest."
        ) ?: "In the remembrance of Allah do hearts find rest."

        for (appWidgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.widget_adhkar_tracker).apply {
                setInt(R.id.widget_bg, "setColorFilter", bgColor)
                setInt(R.id.widget_border, "setColorFilter", borderColor)
                setInt(R.id.streak_pill_bg, "setColorFilter", primaryColor)
                setInt(R.id.morning_card_bg, "setColorFilter", surfaceColor)
                setInt(R.id.evening_card_bg, "setColorFilter", surfaceColor)

                setTextViewText(R.id.adhkar_header_title, headerTitle)
                setTextColor(R.id.adhkar_header_title, textPrimary)

                setTextViewText(R.id.streak_text, streakText)
                setTextColor(R.id.streak_text, Color.WHITE)

                setTextViewText(R.id.morning_title, morningTitle)
                setTextColor(R.id.morning_title, textPrimary)

                setTextViewText(R.id.morning_status, morningStatus)
                setTextColor(R.id.morning_status, textSecondary)
                setProgressBar(R.id.morning_progress, 100, morningProgress, false)

                setTextViewText(R.id.evening_title, eveningTitle)
                setTextColor(R.id.evening_title, textPrimary)

                setTextViewText(R.id.evening_status, eveningStatus)
                setTextColor(R.id.evening_status, textSecondary)
                setProgressBar(R.id.evening_progress, 100, eveningProgress, false)

                setTextViewText(R.id.adhkar_footer, footerText)
                setTextColor(R.id.adhkar_footer, textSecondary)

                // Deep links
                val morningPendingIntent = HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java,
                    Uri.parse("adhkaar365://adhkar/morning")
                )
                setOnClickPendingIntent(R.id.btn_morning_card, morningPendingIntent)

                val eveningPendingIntent = HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java,
                    Uri.parse("adhkaar365://adhkar/evening")
                )
                setOnClickPendingIntent(R.id.btn_evening_card, eveningPendingIntent)

                val rootPendingIntent = HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java,
                    Uri.parse("adhkaar365://progress")
                )
                setOnClickPendingIntent(R.id.widget_root, rootPendingIntent)
            }

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
