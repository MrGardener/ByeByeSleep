package com.mrgardener.byebyesleep.alarm

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/** Fired by AlarmManager at the alarm time. */
class AlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val id = intent.getIntExtra(EXTRA_ALARM_ID, -1)
        if (id < 0) return
        val check = AlarmGraph.lifecycle(context).onFired(id)
        context.startForegroundService(AlarmService.ringIntent(context, id, followUp = check))
    }
}
