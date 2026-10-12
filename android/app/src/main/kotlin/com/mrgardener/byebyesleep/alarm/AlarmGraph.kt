package com.mrgardener.byebyesleep.alarm

import android.content.Context
import java.time.ZonedDateTime

const val EXTRA_ALARM_ID = "alarm_id"

object AlarmGraph {
    fun lifecycle(context: Context): AlarmLifecycle {
        val app = context.applicationContext
        return AlarmLifecycle(PrefsAlarmRepository(app), AndroidAlarmClockScheduler(app)) {
            ZonedDateTime.now()
        }
    }
}
