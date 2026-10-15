package com.mrgardener.byebyesleep.wear

import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.graphics.drawable.Icon
import android.os.Build

/**
 * The watch's own timer and stopwatch state (SharedPreferences, so both keep
 * going when the screen or the app is closed) and the timer's alarm: an exact
 * AlarmManager alarm that fires [TimerReceiver] even in Doze, which posts a
 * full-screen "Time's up" notification ([TimesUpActivity]) that vibrates until
 * Stop. Works without the phone.
 */
object TimerAlarm {
    private const val PREFS = "watch_tools"
    private const val KEY_TIMER = "timer"
    private const val KEY_STOPWATCH = "stopwatch"
    private const val CHANNEL = "timer_done"
    private const val NOTIFICATION_ID = 4101
    const val ACTION_FIRE = "com.mrgardener.byebyesleep.wear.TIMER_FIRE"
    const val ACTION_STOP = "com.mrgardener.byebyesleep.wear.TIMER_STOP"
    const val EXTRA_LABEL = "label"

    /** Vibrate 0.6 s, pause 0.4 s, twice, then rest 1 s; repeats. */
    val PATTERN = longArrayOf(0, 600, 400, 600, 1000)

    /** The ringing stops by itself after this long. */
    const val RING_LIMIT_MS = 10 * 60 * 1000L

    private fun prefs(context: Context) = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    fun loadTimer(context: Context): TimerState = TimerLogic.decode(prefs(context).getString(KEY_TIMER, null))

    fun saveTimer(context: Context, s: TimerState) {
        prefs(context).edit().putString(KEY_TIMER, TimerLogic.encode(s)).apply()
    }

    fun loadStopwatch(context: Context): StopwatchState =
        StopwatchLogic.decode(prefs(context).getString(KEY_STOPWATCH, null))

    fun saveStopwatch(context: Context, s: StopwatchState) {
        prefs(context).edit().putString(KEY_STOPWATCH, StopwatchLogic.encode(s)).apply()
    }

    /** Saves the timer and sets (running) or cancels (paused, idle) its alarm. */
    fun apply(context: Context, s: TimerState) {
        saveTimer(context, s)
        val alarms = context.getSystemService(AlarmManager::class.java) ?: return
        val pending = firePending(context)
        alarms.cancel(pending)
        if (!s.running) return
        // USE_EXACT_ALARM (API 33+) is granted at install; this only fails if
        // a user revoked SCHEDULE_EXACT_ALARM on API 31-32.
        val exact = Build.VERSION.SDK_INT < Build.VERSION_CODES.S || alarms.canScheduleExactAlarms()
        if (exact) {
            alarms.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, s.endAtMs, pending)
        } else {
            alarms.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, s.endAtMs, pending)
        }
    }

    private fun firePending(context: Context): PendingIntent = PendingIntent.getBroadcast(
        context,
        1,
        Intent(context, TimerReceiver::class.java).setAction(ACTION_FIRE),
        PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
    )

    /**
     * Called when the alarm fires (or after a reboot that missed it): checks
     * the stored timer really ended, resets it and starts the ringing.
     */
    fun onFire(context: Context) {
        val s = loadTimer(context)
        if (!s.running) return // paused or reset meanwhile: a stale alarm
        val now = System.currentTimeMillis()
        if (s.endAtMs - now > 2_000) {
            apply(context, s) // fired early (clock changed): set it again
            return
        }
        saveTimer(context, TimerLogic.reset(s))
        ring(context, "${TimerLogic.label(s.durationMs)} timer")
    }

    /** After a reboot alarms are gone: set it again, or ring if it ended meanwhile. */
    fun restore(context: Context) {
        val s = loadTimer(context)
        if (!s.running) return
        if (TimerLogic.isDone(s, System.currentTimeMillis())) onFire(context) else apply(context, s)
    }

    private fun ring(context: Context, label: String) {
        val nm = context.getSystemService(NotificationManager::class.java) ?: return
        ensureChannel(nm)
        val screen = PendingIntent.getActivity(
            context,
            2,
            Intent(context, TimesUpActivity::class.java)
                .putExtra(EXTRA_LABEL, label)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_NO_USER_ACTION),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        val stop = PendingIntent.getBroadcast(
            context,
            3,
            Intent(context, TimerReceiver::class.java).setAction(ACTION_STOP),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        val notification = Notification.Builder(context, CHANNEL)
            .setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
            .setContentTitle("Time's up")
            .setContentText(label)
            .setCategory(Notification.CATEGORY_ALARM)
            .setVisibility(Notification.VISIBILITY_PUBLIC)
            .setOngoing(true)
            .setAutoCancel(false)
            .setContentIntent(screen)
            .setFullScreenIntent(screen, true)
            .setDeleteIntent(stop)
            .setTimeoutAfter(RING_LIMIT_MS)
            .addAction(
                Notification.Action.Builder(
                    Icon.createWithResource(context, android.R.drawable.ic_menu_close_clear_cancel),
                    "Stop",
                    stop,
                ).build(),
            )
            .build()
        // Insistent: the channel's vibration repeats until Stop (or the timeout).
        notification.flags = notification.flags or Notification.FLAG_INSISTENT
        runCatching { nm.notify(NOTIFICATION_ID, notification) }
    }

    private fun ensureChannel(nm: NotificationManager) {
        if (nm.getNotificationChannel(CHANNEL) != null) return
        nm.createNotificationChannel(
            NotificationChannel(CHANNEL, "Timer", NotificationManager.IMPORTANCE_HIGH).apply {
                description = "Time's up alerts of the watch timer"
                enableVibration(true)
                vibrationPattern = PATTERN
                setSound(null, null)
                setBypassDnd(true)
                lockscreenVisibility = Notification.VISIBILITY_PUBLIC
            },
        )
    }

    /** Ends the ringing: the notification goes and the "Time's up" screen closes. */
    fun stopRinging(context: Context) {
        context.getSystemService(NotificationManager::class.java)?.cancel(NOTIFICATION_ID)
        TimesUpActivity.closeAll()
    }

    /** Whether alerts can open full screen (API 34+ lets users switch it off). */
    fun canAlertFullScreen(context: Context): Boolean {
        val nm = context.getSystemService(NotificationManager::class.java) ?: return false
        if (!nm.areNotificationsEnabled()) return false
        return Build.VERSION.SDK_INT < Build.VERSION_CODES.UPSIDE_DOWN_CAKE || nm.canUseFullScreenIntent()
    }
}

/** The timer's alarm and the notification's Stop (not exported). */
class TimerReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            TimerAlarm.ACTION_FIRE -> TimerAlarm.onFire(context)
            TimerAlarm.ACTION_STOP -> TimerAlarm.stopRinging(context)
        }
    }
}

/** Sets the timer's alarm again after a reboot or an app update. */
class TimerBootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            Intent.ACTION_BOOT_COMPLETED, Intent.ACTION_MY_PACKAGE_REPLACED -> TimerAlarm.restore(context)
        }
    }
}
