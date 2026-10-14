package com.mrgardener.byebyesleep.alarm

import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.RingtoneManager
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/**
 * Rings when a timer ends, also with the app closed: an exact alarm, then a
 * notification that keeps sounding (alarm volume) until Stop is tapped.
 * Native side of `byebyesleep/timer` (lib/tools/timer_bell.dart).
 */
object TimerBell {
    private const val CHANNEL_ID = "timers"
    private const val NOTIFICATION_ID = 4800
    private const val PREFS = "timer_bell"
    private const val KEY_AT = "at"
    private const val KEY_LABEL = "label"
    const val ACTION_FIRE = "com.mrgardener.byebyesleep.TIMER_FIRE"
    const val ACTION_STOP = "com.mrgardener.byebyesleep.TIMER_STOP"

    fun register(messenger: BinaryMessenger, context: Context) {
        MethodChannel(messenger, "byebyesleep/timer").setMethodCallHandler { call, result ->
            runCatching {
                when (call.method) {
                    "schedule" -> schedule(
                        context,
                        call.argument<Number>("atMs")!!.toLong(),
                        call.argument<String>("label") ?: "Timer",
                    )
                    "cancel" -> cancel(context)
                    else -> return@setMethodCallHandler result.notImplemented()
                }
                result.success(null)
            }.onFailure { result.error("timer_error", it.message, null) }
        }
    }

    fun schedule(context: Context, atMs: Long, label: String) {
        prefs(context).edit().putLong(KEY_AT, atMs).putString(KEY_LABEL, label).apply()
        context.getSystemService(AlarmManager::class.java)
            .setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, atMs, fireIntent(context))
    }

    /** Cancels a pending timer and silences one that is ringing. */
    fun cancel(context: Context) {
        prefs(context).edit().clear().apply()
        context.getSystemService(AlarmManager::class.java).cancel(fireIntent(context))
        context.getSystemService(NotificationManager::class.java).cancel(NOTIFICATION_ID)
    }

    /** After a reboot: a timer still ahead is scheduled again, one that passed rings now. */
    fun restore(context: Context) {
        val at = prefs(context).getLong(KEY_AT, -1L)
        if (at < 0) return
        schedule(context, maxOf(at, System.currentTimeMillis() + 1_000L), prefs(context).getString(KEY_LABEL, null) ?: "Timer")
    }

    fun ring(context: Context) {
        val label = prefs(context).getString(KEY_LABEL, null) ?: "Timer"
        prefs(context).edit().clear().apply()
        val nm = context.getSystemService(NotificationManager::class.java)
        nm.createNotificationChannel(
            NotificationChannel(CHANNEL_ID, "Timers", NotificationManager.IMPORTANCE_HIGH).apply {
                setSound(
                    RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM),
                    AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_ALARM).build(),
                )
                enableVibration(true)
            },
        )
        val stop = PendingIntent.getBroadcast(
            context, 1, Intent(context, TimerReceiver::class.java).setAction(ACTION_STOP),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        val open = context.packageManager.getLaunchIntentForPackage(context.packageName)?.let {
            PendingIntent.getActivity(context, 2, it, PendingIntent.FLAG_IMMUTABLE)
        }
        val notification = Notification.Builder(context, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
            .setContentTitle("Time's up")
            .setContentText(label)
            .setCategory(Notification.CATEGORY_ALARM)
            .setContentIntent(open)
            .setDeleteIntent(stop)
            .addAction(Notification.Action.Builder(null, "Stop", stop).build())
            .build()
        // Keep sounding until stopped.
        notification.flags = notification.flags or Notification.FLAG_INSISTENT
        nm.notify(NOTIFICATION_ID, notification)
    }

    private fun fireIntent(context: Context) = PendingIntent.getBroadcast(
        context, 0, Intent(context, TimerReceiver::class.java).setAction(ACTION_FIRE),
        PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
    )

    private fun prefs(context: Context) = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
}

class TimerReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            TimerBell.ACTION_FIRE -> TimerBell.ring(context)
            TimerBell.ACTION_STOP -> TimerBell.cancel(context)
        }
    }
}
