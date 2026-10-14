package com.mrgardener.byebyesleep.alarm

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import com.mrgardener.byebyesleep.widget.Widgets

/**
 * Re-registers alarms after reboot (also before first unlock), clock/time-zone changes and app updates,
 * and redraws the home-screen widgets then and when the date changes.
 */
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            Intent.ACTION_LOCKED_BOOT_COMPLETED,
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_TIME_CHANGED,
            Intent.ACTION_TIMEZONE_CHANGED,
            Intent.ACTION_MY_PACKAGE_REPLACED,
            -> {
                AlarmGraph.lifecycle(context).rescheduleAll()
                PreflightReceiver.schedule(context)
                if (intent.action != Intent.ACTION_LOCKED_BOOT_COMPLETED) {
                    TimerBell.restore(context)
                    BedtimeSchedule.refresh(context)
                    runCatching { Widgets.refresh(context) }
                }
            }
            // "Tomorrow" turns into "Today" on the widgets. (Widgets.refresh also
            // schedules its own midnight redraw, in case this is not delivered.)
            Intent.ACTION_DATE_CHANGED -> runCatching { Widgets.refresh(context) }
        }
    }
}
