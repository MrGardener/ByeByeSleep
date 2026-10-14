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
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.time.ZonedDateTime

/** Posts the bedtime reminder, then schedules the next one. */
class BedtimeReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val alarmAt = intent.getLongExtra(EXTRA_ALARM_AT, -1L)
        if (alarmAt > 0 && BedtimeSchedule.enabled(context)) {
            val alarm = ZonedDateTime.ofInstant(java.time.Instant.ofEpochMilli(alarmAt), java.time.ZoneId.systemDefault())
            notify(context, Bedtime.text(alarm, BedtimeSchedule.sleepMinutes(context)))
        }
        BedtimeSchedule.refresh(context)
    }

    private fun notify(context: Context, text: String) {
        val nm = context.getSystemService(NotificationManager::class.java)
        nm.createNotificationChannel(
            NotificationChannel(CHANNEL_ID, "Bedtime", NotificationManager.IMPORTANCE_DEFAULT),
        )
        val open = PendingIntent.getActivity(
            context, 0, Intent(context, MainActivity::class.java),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        nm.notify(
            NOTIFICATION_ID,
            Notification.Builder(context, CHANNEL_ID)
                .setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
                .setContentTitle("Time for bed")
                .setContentText(text)
                .setStyle(Notification.BigTextStyle().bigText(text))
                .setContentIntent(open)
                .setAutoCancel(true)
                .build(),
        )
    }

    companion object {
        const val EXTRA_ALARM_AT = "alarm_at"
        private const val CHANNEL_ID = "bedtime"
        private const val NOTIFICATION_ID = 4900
    }
}

/** Bedtime settings and scheduling; native side of `byebyesleep/bedtime`. */
object BedtimeSchedule {
    private const val PREFS = "bedtime"
    private const val KEY_ENABLED = "enabled"
    private const val KEY_SLEEP = "sleep_minutes"
    const val DEFAULT_SLEEP_MINUTES = 8 * 60

    private fun prefs(context: Context) = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    fun enabled(context: Context) = prefs(context).getBoolean(KEY_ENABLED, false)

    fun sleepMinutes(context: Context) = prefs(context).getInt(KEY_SLEEP, DEFAULT_SLEEP_MINUTES)

    fun register(messenger: BinaryMessenger, context: Context) {
        MethodChannel(messenger, "byebyesleep/bedtime").setMethodCallHandler { call, result ->
            runCatching {
                when (call.method) {
                    "get" -> result.success(status(context))
                    "set" -> {
                        prefs(context).edit()
                            .putBoolean(KEY_ENABLED, call.argument<Boolean>("enabled") ?: false)
                            .putInt(KEY_SLEEP, call.argument<Number>("sleepMinutes")?.toInt() ?: DEFAULT_SLEEP_MINUTES)
                            .apply()
                        refresh(context)
                        result.success(status(context))
                    }
                    else -> result.notImplemented()
                }
            }.onFailure { result.error("bedtime_error", it.message, null) }
        }
    }

    private fun status(context: Context): Map<String, Any?> {
        val next = if (enabled(context)) nextReminder(context) else null
        return mapOf(
            "enabled" to enabled(context),
            "sleepMinutes" to sleepMinutes(context),
            "nextAtMs" to next?.at?.toInstant()?.toEpochMilli(),
        )
    }

    private fun nextReminder(context: Context): Bedtime.Reminder? = runCatching {
        Bedtime.next(PrefsAlarmRepository(context).all(), ZonedDateTime.now(), sleepMinutes(context))
    }.getOrNull()

    /** Schedules the next reminder (alarms or settings changed, after boot, after one fired). */
    fun refresh(context: Context) {
        val am = context.getSystemService(AlarmManager::class.java)
        val base = Intent(context, BedtimeReceiver::class.java)
        val existing = PendingIntent.getBroadcast(
            context, 0, base, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_NO_CREATE,
        )
        existing?.let { am.cancel(it) }
        if (!enabled(context)) return
        val next = nextReminder(context) ?: return
        val pi = PendingIntent.getBroadcast(
            context, 0,
            base.putExtra(BedtimeReceiver.EXTRA_ALARM_AT, next.alarm.toInstant().toEpochMilli()),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        // A reminder may be a minute late; no exact alarm needed.
        am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, next.at.toInstant().toEpochMilli(), pi)
    }
}
