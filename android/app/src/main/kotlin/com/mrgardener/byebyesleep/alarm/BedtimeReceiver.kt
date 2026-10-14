package com.mrgardener.byebyesleep.alarm

import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.provider.Settings
import com.mrgardener.byebyesleep.MainActivity
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.time.Instant
import java.time.ZoneId
import java.time.ZonedDateTime

/** Wind-down and bedtime reminders, quiet hours on and off; then plans the next night. */
class BedtimeReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val kind = intent.getStringExtra(EXTRA_KIND)?.let { runCatching { Bedtime.Kind.valueOf(it) }.getOrNull() }
        val alarmAt = intent.getLongExtra(EXTRA_ALARM_AT, -1L)
        if (BedtimeSchedule.enabled(context)) {
            when (kind) {
                Bedtime.Kind.WIND_DOWN ->
                    notify(context, "Wind down", Bedtime.windDownText(BedtimeSchedule.windDownMinutes(context)))
                Bedtime.Kind.BEDTIME -> {
                    if (alarmAt > 0) {
                        val alarm = ZonedDateTime.ofInstant(Instant.ofEpochMilli(alarmAt), ZoneId.systemDefault())
                        notify(context, "Time for bed", Bedtime.text(alarm, BedtimeSchedule.sleepMinutes(context)))
                    }
                    if (BedtimeSchedule.quietHours(context) && alarmAt > 0) QuietHours.start(context, alarmAt)
                }
                Bedtime.Kind.QUIET_OFF -> QuietHours.end(context)
                null -> {}
            }
        } else if (kind == Bedtime.Kind.QUIET_OFF) {
            QuietHours.end(context)
        }
        BedtimeSchedule.refresh(context)
    }

    private fun notify(context: Context, title: String, text: String) {
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
                .setContentTitle(title)
                .setContentText(text)
                .setStyle(Notification.BigTextStyle().bigText(text))
                .setContentIntent(open)
                .setAutoCancel(true)
                .build(),
        )
    }

    companion object {
        const val EXTRA_ALARM_AT = "alarm_at"
        const val EXTRA_KIND = "kind"
        private const val CHANNEL_ID = "bedtime"
        private const val NOTIFICATION_ID = 4900
    }
}

/**
 * Do Not Disturb from bedtime until the alarm. Alarms still ring (Android lets
 * alarms through Do Not Disturb). It is only switched off again if we switched
 * it on, so a Do Not Disturb the user set stays.
 */
object QuietHours {
    private const val PREFS = "quiet_hours"
    private const val KEY_OURS = "ours"

    fun allowed(context: Context): Boolean =
        context.getSystemService(NotificationManager::class.java).isNotificationPolicyAccessGranted

    /** Its own end request code: planning the next night must not cancel tonight's end. */
    private const val END_REQUEST = 100

    /** Quiet from now until [untilMs] (the alarm). */
    fun start(context: Context, untilMs: Long) {
        val nm = context.getSystemService(NotificationManager::class.java)
        if (!nm.isNotificationPolicyAccessGranted) return
        if (nm.currentInterruptionFilter != NotificationManager.INTERRUPTION_FILTER_ALL) return
        nm.setInterruptionFilter(NotificationManager.INTERRUPTION_FILTER_PRIORITY)
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().putBoolean(KEY_OURS, true).apply()
        val end = PendingIntent.getBroadcast(
            context, END_REQUEST,
            Intent(context, BedtimeReceiver::class.java)
                .setAction("bedtime.quiet_end")
                .putExtra(BedtimeReceiver.EXTRA_KIND, Bedtime.Kind.QUIET_OFF.name),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        context.getSystemService(AlarmManager::class.java)
            .setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, untilMs, end)
    }

    fun end(context: Context) {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        if (!prefs.getBoolean(KEY_OURS, false)) return
        prefs.edit().putBoolean(KEY_OURS, false).apply()
        val nm = context.getSystemService(NotificationManager::class.java)
        if (nm.isNotificationPolicyAccessGranted) nm.setInterruptionFilter(NotificationManager.INTERRUPTION_FILTER_ALL)
    }
}

/** Bedtime settings and scheduling; native side of `byebyesleep/bedtime`. */
object BedtimeSchedule {
    private const val PREFS = "bedtime"
    private const val KEY_ENABLED = "enabled"
    private const val KEY_SLEEP = "sleep_minutes"
    private const val KEY_WIND_DOWN = "wind_down_minutes"
    private const val KEY_QUIET = "quiet_hours"
    const val DEFAULT_SLEEP_MINUTES = 8 * 60

    private fun prefs(context: Context) = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    fun enabled(context: Context) = prefs(context).getBoolean(KEY_ENABLED, false)

    fun sleepMinutes(context: Context) = prefs(context).getInt(KEY_SLEEP, DEFAULT_SLEEP_MINUTES)

    fun windDownMinutes(context: Context) = prefs(context).getInt(KEY_WIND_DOWN, 0)

    fun quietHours(context: Context) = prefs(context).getBoolean(KEY_QUIET, false)

    fun register(messenger: BinaryMessenger, context: Context) {
        MethodChannel(messenger, "byebyesleep/bedtime").setMethodCallHandler { call, result ->
            runCatching {
                when (call.method) {
                    "get" -> result.success(status(context))
                    "set" -> {
                        prefs(context).edit()
                            .putBoolean(KEY_ENABLED, call.argument<Boolean>("enabled") ?: false)
                            .putInt(KEY_SLEEP, call.argument<Number>("sleepMinutes")?.toInt() ?: DEFAULT_SLEEP_MINUTES)
                            .putInt(KEY_WIND_DOWN, call.argument<Number>("windDownMinutes")?.toInt() ?: 0)
                            .putBoolean(KEY_QUIET, call.argument<Boolean>("quietHours") ?: false)
                            .apply()
                        if (!enabled(context) || !quietHours(context)) QuietHours.end(context)
                        refresh(context)
                        result.success(status(context))
                    }
                    "openQuietHoursAccess" -> {
                        context.startActivity(
                            Intent(Settings.ACTION_NOTIFICATION_POLICY_ACCESS_SETTINGS)
                                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
                        )
                        result.success(null)
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
            "windDownMinutes" to windDownMinutes(context),
            "quietHours" to quietHours(context),
            "quietHoursAllowed" to QuietHours.allowed(context),
            "nextAtMs" to next?.at?.toInstant()?.toEpochMilli(),
        )
    }

    private fun nextReminder(context: Context): Bedtime.Reminder? = runCatching {
        Bedtime.next(PrefsAlarmRepository(context).all(), ZonedDateTime.now(), sleepMinutes(context))
    }.getOrNull()

    private fun intent(context: Context, kind: Bedtime.Kind) =
        Intent(context, BedtimeReceiver::class.java).setAction("bedtime.${kind.name}")

    /** Plans the next night (alarms or settings changed, after boot, after each event). */
    fun refresh(context: Context) {
        val am = context.getSystemService(AlarmManager::class.java)
        for (kind in Bedtime.Kind.values()) {
            PendingIntent.getBroadcast(
                context, kind.ordinal, intent(context, kind),
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_NO_CREATE,
            )?.let { am.cancel(it) }
        }
        if (!enabled(context)) return
        val next = nextReminder(context) ?: return
        // Quiet hours end at the alarm through their own request (QuietHours.start).
        val events = Bedtime.plan(next, ZonedDateTime.now(), windDownMinutes(context), quietHours = false)
        for (event in events) {
            val pi = PendingIntent.getBroadcast(
                context, event.kind.ordinal,
                intent(context, event.kind)
                    .putExtra(BedtimeReceiver.EXTRA_KIND, event.kind.name)
                    .putExtra(BedtimeReceiver.EXTRA_ALARM_AT, next.alarm.toInstant().toEpochMilli()),
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
            )
            // A reminder may be a minute late; no exact alarm needed.
            am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, event.at.toInstant().toEpochMilli(), pi)
        }
    }
}
