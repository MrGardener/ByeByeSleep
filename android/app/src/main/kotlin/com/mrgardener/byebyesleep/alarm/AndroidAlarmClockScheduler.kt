package com.mrgardener.byebyesleep.alarm

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import com.mrgardener.byebyesleep.MainActivity

/** Uses setAlarmClock: exact, exempt from Doze, shown in the status bar. */
class AndroidAlarmClockScheduler(private val context: Context) : AlarmClockScheduler {
    private val alarmManager = context.getSystemService(AlarmManager::class.java)

    override fun schedule(id: Int, triggerAtMs: Long) {
        val show = PendingIntent.getActivity(
            context, id, Intent(context, MainActivity::class.java),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        alarmManager.setAlarmClock(AlarmManager.AlarmClockInfo(triggerAtMs, show), operation(id))
    }

    override fun cancel(id: Int) = alarmManager.cancel(operation(id))

    private fun operation(id: Int): PendingIntent = PendingIntent.getBroadcast(
        context, id,
        Intent(context, AlarmReceiver::class.java).putExtra(EXTRA_ALARM_ID, id),
        PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
    )
}
