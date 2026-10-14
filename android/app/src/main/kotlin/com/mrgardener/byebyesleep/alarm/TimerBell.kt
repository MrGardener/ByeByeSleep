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
import org.json.JSONObject

/**
 * Rings when a timer ends, also with the app closed: an exact alarm, then a
 * notification that keeps sounding (alarm volume) until Stop is tapped. Each
 * timer has its own alarm and notification, so several can run at once.
 * Native side of `byebyesleep/timer` (lib/tools/timer_bell.dart).
 */
object TimerBell {
    private const val CHANNEL_ID = "timers"
    private const val NOTIFICATION_BASE = 4800
    private const val PREFS = "timer_bell"
    private const val KEY_PENDING = "pending"
    const val EXTRA_ID = "timer_id"
    const val ACTION_FIRE = "com.mrgardener.byebyesleep.TIMER_FIRE"
    const val ACTION_STOP = "com.mrgardener.byebyesleep.TIMER_STOP"

    fun register(messenger: BinaryMessenger, context: Context) {
        MethodChannel(messenger, "byebyesleep/timer").setMethodCallHandler { call, result ->
            runCatching {
                val id = call.argument<Number>("id")?.toInt() ?: 0
                when (call.method) {
                    "schedule" -> schedule(
                        context,
                        id,
                        call.argument<Number>("atMs")!!.toLong(),
                        call.argument<String>("label") ?: "Timer",
                    )
                    "cancel" -> cancel(context, id)
                    else -> return@setMethodCallHandler result.notImplemented()
                }
                result.success(null)
            }.onFailure { result.error("timer_error", it.message, null) }
        }
    }

    /** Pending timers: id → {at, label}, kept for a reboot. */
    private fun pending(context: Context): JSONObject =
        runCatching { JSONObject(prefs(context).getString(KEY_PENDING, "{}")!!) }.getOrDefault(JSONObject())

    private fun savePending(context: Context, json: JSONObject) =
        prefs(context).edit().putString(KEY_PENDING, json.toString()).apply()

    fun schedule(context: Context, id: Int, atMs: Long, label: String) {
        savePending(context, pending(context).put("$id", JSONObject().put("at", atMs).put("label", label)))
        context.getSystemService(AlarmManager::class.java)
            .setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, atMs, fireIntent(context, id))
    }

    /** Cancels a pending timer and silences one that is ringing. */
    fun cancel(context: Context, id: Int) {
        savePending(context, pending(context).apply { remove("$id") })
        context.getSystemService(AlarmManager::class.java).cancel(fireIntent(context, id))
        context.getSystemService(NotificationManager::class.java).cancel(NOTIFICATION_BASE + id)
    }

    /** After a reboot: timers still ahead are scheduled again, ones that passed ring now. */
    fun restore(context: Context) {
        val json = pending(context)
        for (key in json.keys()) {
            val t = json.optJSONObject(key) ?: continue
            val id = key.toIntOrNull() ?: continue
            schedule(context, id, maxOf(t.optLong("at"), System.currentTimeMillis() + 1_000L), t.optString("label", "Timer"))
        }
    }

    fun ring(context: Context, id: Int) {
        val json = pending(context)
        val label = json.optJSONObject("$id")?.optString("label") ?: "Timer"
        savePending(context, json.apply { remove("$id") })
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
            context, 10_000 + id,
            Intent(context, TimerReceiver::class.java).setAction(ACTION_STOP).putExtra(EXTRA_ID, id),
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
        nm.notify(NOTIFICATION_BASE + id, notification)
    }

    private fun fireIntent(context: Context, id: Int) = PendingIntent.getBroadcast(
        context, id,
        Intent(context, TimerReceiver::class.java).setAction(ACTION_FIRE).putExtra(EXTRA_ID, id),
        PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
    )

    private fun prefs(context: Context) = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
}

class TimerReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val id = intent.getIntExtra(TimerBell.EXTRA_ID, 0)
        when (intent.action) {
            TimerBell.ACTION_FIRE -> TimerBell.ring(context, id)
            TimerBell.ACTION_STOP -> TimerBell.cancel(context, id)
        }
    }
}
