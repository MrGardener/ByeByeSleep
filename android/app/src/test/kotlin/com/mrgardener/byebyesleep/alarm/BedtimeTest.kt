package com.mrgardener.byebyesleep.alarm

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class BedtimeTest {
    private val daily = (1..7).toSet()
    private val eightHours = 8 * 60

    @Test fun bedtime_isTheAlarmMinusTheSleepGoal() {
        val b = Bedtime.next(listOf(spec(7, 0, daily)), at(2026, 10, 12, 20, 0), eightHours)!!
        assertEquals(at(2026, 10, 12, 23, 0), b.at)
        assertEquals(at(2026, 10, 13, 7, 0), b.alarm)
    }

    @Test fun pastBedtime_remindsForTheFollowingNight() {
        val b = Bedtime.next(listOf(spec(7, 0, daily)), at(2026, 10, 12, 23, 30), eightHours)!!
        assertEquals(at(2026, 10, 13, 23, 0), b.at)
    }

    @Test fun aSeries_usesItsFirstRing() {
        val alarms = listOf(spec(6, 30, daily), spec(6, 40, daily))
        // 22:35: bedtime for 06:30 passed; 06:40 must not give a 22:40 reminder.
        assertEquals(at(2026, 10, 13, 22, 30), Bedtime.next(alarms, at(2026, 10, 12, 22, 35), eightHours)!!.at)
        assertEquals(at(2026, 10, 12, 22, 30), Bedtime.next(alarms, at(2026, 10, 12, 21, 0), eightHours)!!.at)
    }

    @Test fun onlyAlarmsThatAreOn() {
        assertNull(Bedtime.next(listOf(spec(7, 0, daily, enabled = false)), at(2026, 10, 12, 20, 0), eightHours))
        assertNull(Bedtime.next(emptyList(), at(2026, 10, 12, 20, 0), eightHours))
    }

    @Test fun weekendWithoutAlarm_waitsForTheNextOne() {
        // Mon–Fri 07:00; Friday 23:30 → next alarm Monday, bedtime Sunday 23:00.
        val weekdays = setOf(1, 2, 3, 4, 5)
        val b = Bedtime.next(listOf(spec(7, 0, weekdays)), at(2026, 10, 16, 23, 30), eightHours)!!
        assertEquals(at(2026, 10, 18, 23, 0), b.at)
    }

    @Test fun text_saysWhenTheAlarmRings() {
        assertEquals(
            "Your alarm rings at 07:00 — go to bed now for 8 h of sleep.",
            Bedtime.text(at(2026, 10, 13, 7, 0), eightHours),
        )
        assertEquals(
            "Your alarm rings at 06:30 — go to bed now for 7 h 30 min of sleep.",
            Bedtime.text(at(2026, 10, 13, 6, 30), 450),
        )
    }
}
