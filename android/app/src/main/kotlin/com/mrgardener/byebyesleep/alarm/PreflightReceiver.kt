package com.mrgardener.byebyesleep.alarm

import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import com.mrgardener.byebyesleep.MainActivity
import java.time.ZonedDateTime

/** Runs the evening pre-flight check at 21:00 and notifies about problems. */
class PreflightReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val core = listOf("exactAlarm", "fullScreenIntent", "notifications", "ignoreBatteryOptimizations", "overlay")
        val status = Permissions.status(context)
        val problems = Preflight.problems(
            PrefsAlarmRepository(context).all(),
            core.all { status[it] == true },
            ZonedDateTime.now(),
        )
        if (problems.isNotEmpty()) notify(context, problems)
        schedule(context)
    }

    private fun notify(context: Context, problems: List<String>) {
        val nm = context.getSystemService(NotificationManager::class.java)
        nm.createNotificationChannel(
            NotificationChannel(CHANNEL_ID, "Alarm checks", NotificationManager.IMPORTANCE_DEFAULT),
        )
        val open = PendingIntent.getActivity(
            context, 0, Intent(context, MainActivity::class.java),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        nm.notify(
            NOTIFICATION_ID,
            Notification.Builder(context, CHANNEL_ID)
                .setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
                .setContentTitle("Tomorrow's alarm may not work — tap to fix")
                .setContentText(problems.first())
                .setStyle(Notification.BigTextStyle().bigText(problems.joinToString("\n")))
                .setContentIntent(open)
                .setAutoCancel(true)
                .build(),
        )
    }

    companion object {
        private const val CHANNEL_ID = "preflight"
        private const val NOTIFICATION_ID = 4243

        /** Schedules the next 21:00 check (inexact is fine for a reminder). */
        fun schedule(context: Context) {
            val at = Preflight.nextCheck(ZonedDateTime.now()).toInstant().toEpochMilli()
            val pi = PendingIntent.getBroadcast(
                context, 0, Intent(context, PreflightReceiver::class.java),
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
            )
            context.getSystemService(AlarmManager::class.java)
                .setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, pi)
        }
    }
}
