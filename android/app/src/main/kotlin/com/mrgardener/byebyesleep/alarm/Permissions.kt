package com.mrgardener.byebyesleep.alarm

import android.app.Activity
import android.app.AlarmManager
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings

/** Permission health for the preflight banner. Keys match Dart's PermissionKind names. */
object Permissions {
    fun status(context: Context): Map<String, Boolean> {
        val nm = context.getSystemService(NotificationManager::class.java)
        return mapOf(
            "exactAlarm" to (Build.VERSION.SDK_INT < 31 ||
                context.getSystemService(AlarmManager::class.java).canScheduleExactAlarms()),
            "fullScreenIntent" to (Build.VERSION.SDK_INT < 34 || nm.canUseFullScreenIntent()),
            "notifications" to nm.areNotificationsEnabled(),
            "ignoreBatteryOptimizations" to context.getSystemService(PowerManager::class.java)
                .isIgnoringBatteryOptimizations(context.packageName),
        )
    }

    fun openSettings(activity: Activity, kind: String) {
        val pkg = Uri.parse("package:${activity.packageName}")
        val intent = when (kind) {
            "exactAlarm" -> if (Build.VERSION.SDK_INT >= 31) {
                Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM, pkg)
            } else null
            "fullScreenIntent" -> if (Build.VERSION.SDK_INT >= 34) {
                Intent(Settings.ACTION_MANAGE_APP_USE_FULL_SCREEN_INTENT, pkg)
            } else null
            "notifications" -> Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
                .putExtra(Settings.EXTRA_APP_PACKAGE, activity.packageName)
            "ignoreBatteryOptimizations" ->
                Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS, pkg)
            else -> null
        } ?: Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, pkg)
        runCatching { activity.startActivity(intent) }.onFailure {
            activity.startActivity(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, pkg))
        }
    }
}
