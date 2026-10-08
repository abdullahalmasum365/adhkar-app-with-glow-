package com.adhkaar365.app

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.graphics.Color
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetBackgroundIntent
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

class TasbihWidgetProvider : HomeWidgetProvider() {

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

        val title = widgetData.getString("tasbih_title", "SubhanAllah") ?: "SubhanAllah"
        val count = widgetData.getInt("tasbih_count", 33).toString()
        val target = widgetData.getString("tasbih_target", "Target: 33") ?: "Target: 33"
        val btnText = widgetData.getString("tasbih_btn_text", "➕ TAP") ?: "➕ TAP"

        for (appWidgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.widget_tasbih).apply {
                setInt(R.id.widget_bg, "setColorFilter", bgColor)
                setInt(R.id.widget_border, "setColorFilter", borderColor)
                setInt(R.id.tasbih_btn_bg, "setColorFilter", primaryColor)

                setTextViewText(R.id.tasbih_title, title)
                setTextColor(R.id.tasbih_title, textSecondary)

                setTextViewText(R.id.tasbih_count, count)
                setTextColor(R.id.tasbih_count, textPrimary)

                setTextViewText(R.id.tasbih_btn_text, btnText)
                setTextColor(R.id.tasbih_btn_text, Color.WHITE)

                setTextViewText(R.id.tasbih_target, target)
                setTextColor(R.id.tasbih_target, textSecondary)

                // Background interactive tap on the button
                val tapPendingIntent = HomeWidgetBackgroundIntent.getBroadcast(
                    context,
                    Uri.parse("adhkaar365://tasbih_increment")
                )
                setOnClickPendingIntent(R.id.btn_tasbih_tap, tapPendingIntent)

                // Main root click opens the tasbih focus screen
                val rootPendingIntent = HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java,
                    Uri.parse("adhkaar365://tasbih")
                )
                setOnClickPendingIntent(R.id.widget_root, rootPendingIntent)
            }

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
