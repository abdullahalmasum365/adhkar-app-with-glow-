package com.adhkaar365.app

import android.app.Activity
import android.app.PendingIntent
import android.content.Context
import android.net.Uri
import es.antonborri.home_widget.HomeWidgetBackgroundIntent
import es.antonborri.home_widget.HomeWidgetLaunchIntent

/**
 * Helper to guarantee all AppWidget PendingIntents comply with Android 12+ (API 31+)
 * and Android 13/14/15 (API 33/34/35) PendingIntent mutability requirements:
 *
 * 1. Enforces [PendingIntent.FLAG_IMMUTABLE] to prevent system crashes on Android 12+.
 * 2. Employs [HomeWidgetLaunchIntent.getActivity] which automatically configures
 *    [android.app.ActivityOptions.MODE_BACKGROUND_ACTIVITY_START_ALLOWED] on Android 14/15 (API 34/35).
 * 3. Employs [HomeWidgetBackgroundIntent.getBroadcast] with [PendingIntent.FLAG_IMMUTABLE]
 *    for one-tap interactive widgets (such as Quick Tasbih counter).
 */
object WidgetIntentHelper {

    fun <T : Activity> getActivityPendingIntent(
        context: Context,
        activityClass: Class<T>,
        uri: Uri
    ): PendingIntent {
        return HomeWidgetLaunchIntent.getActivity(context, activityClass, uri)
    }

    fun getBroadcastPendingIntent(
        context: Context,
        uri: Uri
    ): PendingIntent {
        return HomeWidgetBackgroundIntent.getBroadcast(context, uri)
    }
}
