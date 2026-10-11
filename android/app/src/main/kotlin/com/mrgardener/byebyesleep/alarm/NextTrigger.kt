package com.mrgardener.byebyesleep.alarm

import java.time.LocalTime
import java.time.ZonedDateTime

object NextTrigger {
    /**
     * Earliest instant strictly after [now] at the alarm's local time on an allowed day.
     * java.time moves times in a DST gap forward and picks the earlier offset in an overlap.
     */
    fun compute(spec: AlarmSpec, now: ZonedDateTime): ZonedDateTime {
        val time = LocalTime.of(spec.hour, spec.minute)
        for (offset in 0L..7L) {
            val date = now.toLocalDate().plusDays(offset)
            if (spec.repeatDays.isNotEmpty() && date.dayOfWeek.value !in spec.repeatDays) continue
            val candidate = ZonedDateTime.of(date, time, now.zone)
            if (candidate.isAfter(now)) return candidate
        }
        error("No trigger within 8 days for $spec")
    }
}
