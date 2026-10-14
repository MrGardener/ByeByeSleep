package com.mrgardener.byebyesleep.widget

import android.app.AlarmManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.Rect
import android.os.Build
import android.view.View
import android.view.WindowInsets
import com.mrgardener.byebyesleep.MainActivity
import com.mrgardener.byebyesleep.alarm.PrefsAlarmRepository
import java.time.ZonedDateTime

/** Keeps every home-screen widget instance up to date. */
object Widgets {
    private const val OPEN_APP_REQUEST = 4910
    private const val TICK_REQUEST = 4911

    /**
     * Redraws all widget instances. Called after alarm changes, boot, clock, time-zone
     * and date changes, and by a light alarm at midnight / just after the next ring.
     */
    fun refresh(context: Context) {
        val app = context.applicationContext
        val manager = AppWidgetManager.getInstance(app) ?: return
        val clocks = ids(app, manager, ClockWidgetProvider::class.java)
        val nexts = ids(app, manager, NextAlarmWidgetProvider::class.java)
        val worlds = ids(app, manager, WorldClockWidgetProvider::class.java)
        val now = ZonedDateTime.now()
        val upcoming = if (clocks.isEmpty() && nexts.isEmpty()) null else nextAlarm(app, now)
        for (id in clocks) runCatching { ClockWidgetProvider.update(app, manager, id, upcoming, now) }
        for (id in nexts) runCatching { NextAlarmWidgetProvider.update(app, manager, id, upcoming, now) }
        for (id in worlds) runCatching { WorldClockWidgetProvider.update(app, manager, id) }
        // World clocks only need the 30-min safety net (TextClock ticks by itself);
        // the alarm line goes stale at midnight and when the next alarm rings.
        if (clocks.isEmpty() && nexts.isEmpty()) {
            cancelTick(app)
        } else {
            scheduleTick(app, NextAlarm.refreshAt(upcoming, now).toInstant().toEpochMilli())
        }
    }

    /** The next ring across the app's alarms, or null (also if they cannot be read). */
    fun nextAlarm(context: Context, now: ZonedDateTime = ZonedDateTime.now()): NextAlarm.Upcoming? =
        runCatching { NextAlarm.find(PrefsAlarmRepository(context.applicationContext).all(), now) }.getOrNull()

    /** Opens the app (widget taps). */
    fun openApp(context: Context): PendingIntent = PendingIntent.getActivity(
        context,
        OPEN_APP_REQUEST,
        Intent(context, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
        PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
    )

    private fun ids(context: Context, manager: AppWidgetManager, provider: Class<*>): IntArray =
        runCatching { manager.getAppWidgetIds(ComponentName(context, provider)) }.getOrNull() ?: IntArray(0)

    private fun tickIntent(context: Context, flags: Int): PendingIntent? = PendingIntent.getBroadcast(
        context,
        TICK_REQUEST,
        Intent(context, WidgetTickReceiver::class.java),
        PendingIntent.FLAG_IMMUTABLE or flags,
    )

    /** Inexact, non-waking: a widget only matters while the screen is on. */
    private fun scheduleTick(context: Context, atMs: Long) {
        val pi = tickIntent(context, PendingIntent.FLAG_UPDATE_CURRENT) ?: return
        context.getSystemService(AlarmManager::class.java)?.set(AlarmManager.RTC, atMs, pi)
    }

    private fun cancelTick(context: Context) {
        val pi = tickIntent(context, PendingIntent.FLAG_NO_CREATE) ?: return
        context.getSystemService(AlarmManager::class.java)?.cancel(pi)
        pi.cancel()
    }
}

/** Redraws the widgets at midnight and just after the next alarm rang (see [Widgets.refresh]). */
class WidgetTickReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        Widgets.refresh(context)
    }
}

/** Keeps a native screen's content clear of the status, navigation bar and keyboard (edge-to-edge). */
internal fun View.padForSystemBars() {
    val left = paddingLeft
    val top = paddingTop
    val right = paddingRight
    val bottom = paddingBottom
    setOnApplyWindowInsetsListener { v, insets ->
        val bars = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            val i = insets.getInsets(WindowInsets.Type.systemBars() or WindowInsets.Type.ime())
            Rect(i.left, i.top, i.right, i.bottom)
        } else {
            @Suppress("DEPRECATION")
            Rect(
                insets.systemWindowInsetLeft,
                insets.systemWindowInsetTop,
                insets.systemWindowInsetRight,
                insets.systemWindowInsetBottom,
            )
        }
        v.setPadding(left + bars.left, top + bars.top, right + bars.right, bottom + bars.bottom)
        insets
    }
    requestApplyInsets()
}
