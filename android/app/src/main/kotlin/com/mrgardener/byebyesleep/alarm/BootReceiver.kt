package com.mrgardener.byebyesleep.alarm

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/** Re-registers alarms after reboot (also before first unlock), clock/time-zone changes and app updates. */
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            Intent.ACTION_LOCKED_BOOT_COMPLETED,
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_TIME_CHANGED,
            Intent.ACTION_TIMEZONE_CHANGED,
            Intent.ACTION_MY_PACKAGE_REPLACED,
            -> AlarmGraph.lifecycle(context).rescheduleAll()
        }
    }
}
