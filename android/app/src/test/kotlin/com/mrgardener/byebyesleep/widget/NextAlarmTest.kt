package com.mrgardener.byebyesleep.widget

import com.mrgardener.byebyesleep.alarm.at
import com.mrgardener.byebyesleep.alarm.spec
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class NextAlarmTest {
    private val daily = (1..7).toSet()
    private fun ms(h: Int, mi: Int, d: Int = 12) = at(2026, 10, d, h, mi).toInstant().toEpochMilli()

    // 2026-10-12 is a Monday.
    @Test fun earliestAcrossAlarms() {
        val alarms = listOf(spec(7, 0, daily).copy(id = 1), spec(6, 30, daily).copy(id = 2))
        val next = NextAlarm.find(alarms, at(2026, 10, 12, 22, 0))!!
        assertEquals(2, next.spec.id)
        assertEquals(at(2026, 10, 13, 6, 30), next.at)
        assertFalse(next.snoozed)
    }

    @Test fun onlyAlarmsThatAreOn() {
        assertNull(NextAlarm.find(listOf(spec(7, 0, daily, enabled = false)), at(2026, 10, 12, 22, 0)))
        assertNull(NextAlarm.find(emptyList(), at(2026, 10, 12, 22, 0)))
        val alarms = listOf(spec(6, 0, daily, enabled = false).copy(id = 1), spec(8, 0).copy(id = 2))
        assertEquals(2, NextAlarm.find(alarms, at(2026, 10, 12, 22, 0))!!.spec.id)
    }

    @Test fun laterTodayBeatsTomorrow() {
        assertEquals(at(2026, 10, 12, 9, 0), NextAlarm.find(listOf(spec(9, 0)), at(2026, 10, 12, 8, 0))!!.at)
    }

    @Test fun pinnedOneShot_ringsAtItsInstant_andNotOncePast() {
        val pinned = spec(7, 0).copy(atMs = ms(7, 0, d = 15))
        assertEquals(at(2026, 10, 15, 7, 0), NextAlarm.find(listOf(pinned), at(2026, 10, 12, 22, 0))!!.at)
        assertNull(NextAlarm.find(listOf(pinned), at(2026, 10, 15, 7, 1)))
    }

    @Test fun skippedRing_isPassedOver() {
        val skipped = spec(7, 0, daily).copy(skipUntilMs = ms(7, 0, d = 13))
        assertEquals(at(2026, 10, 14, 7, 0), NextAlarm.find(listOf(skipped), at(2026, 10, 12, 22, 0))!!.at)
        // Once the skipped instant is past, the skip no longer matters.
        assertEquals(at(2026, 10, 14, 7, 0), NextAlarm.find(listOf(skipped), at(2026, 10, 13, 8, 0))!!.at)
    }

    @Test fun snooze_winsEvenOnAOneShotThatWasSwitchedOff() {
        val snoozed = spec(7, 0, enabled = false).copy(snoozeUntilMs = ms(7, 9))
        val next = NextAlarm.find(listOf(snoozed), at(2026, 10, 12, 7, 2))!!
        assertEquals(at(2026, 10, 12, 7, 9), next.at)
        assertTrue(next.snoozed)
        assertNull(NextAlarm.find(listOf(snoozed), at(2026, 10, 12, 7, 10)))
    }

    @Test fun repeatingDays_skipTheWeekend() {
        // Mon–Fri 07:00 seen on Friday evening → Monday.
        val next = NextAlarm.find(listOf(spec(7, 0, setOf(1, 2, 3, 4, 5))), at(2026, 10, 16, 20, 0))!!
        assertEquals(at(2026, 10, 19, 7, 0), next.at)
    }

    @Test fun day_label() {
        val now = at(2026, 10, 12, 22, 0)
        assertEquals("Today", NextAlarm.day(at(2026, 10, 12, 23, 0), now))
        assertEquals("Tomorrow", NextAlarm.day(at(2026, 10, 13, 6, 30), now))
        assertEquals("Friday", NextAlarm.day(at(2026, 10, 16, 7, 0), now))
        assertEquals("Mon 19 Oct", NextAlarm.day(at(2026, 10, 19, 7, 0), now))
    }

    @Test fun time_followsThePhone24hSetting() {
        assertEquals("06:30", NextAlarm.time(at(2026, 10, 13, 6, 30), is24h = true))
        assertEquals("6:30 AM", NextAlarm.time(at(2026, 10, 13, 6, 30), is24h = false))
        assertEquals("18:05", NextAlarm.time(at(2026, 10, 13, 18, 5), is24h = true))
    }

    @Test fun summary_line() {
        val now = at(2026, 10, 12, 22, 0)
        val next = NextAlarm.find(listOf(spec(6, 30, daily)), now)
        assertEquals("Next alarm 06:30 · Tomorrow", NextAlarm.summary(next, now, is24h = true))
        assertEquals("No alarm set", NextAlarm.summary(null, now, is24h = true))
        val snoozed = NextAlarm.find(listOf(spec(7, 0).copy(snoozeUntilMs = ms(22, 9))), now)
        assertEquals("Snoozed until 10:09 PM · Today", NextAlarm.summary(snoozed, now, is24h = false))
    }

    @Test fun detail_line() {
        val now = at(2026, 10, 12, 22, 0)
        val labelled = NextAlarm.find(listOf(spec(6, 30, daily).copy(label = " Wake up ")), now)!!
        assertEquals("Tomorrow · Wake up", NextAlarm.detail(labelled, now))
        assertEquals("Tomorrow", NextAlarm.detail(NextAlarm.find(listOf(spec(6, 30, daily)), now)!!, now))
    }

    @Test fun refreshAt_afterTheRingOrAtMidnight() {
        val evening = at(2026, 10, 12, 22, 0)
        // Ring tomorrow: midnight comes first ("Tomorrow" turns into "Today").
        val tomorrow = NextAlarm.find(listOf(spec(6, 30, daily)), evening)
        assertEquals(at(2026, 10, 13, 0, 0), NextAlarm.refreshAt(tomorrow, evening))
        // Ring later today: just after it fires.
        val today = NextAlarm.find(listOf(spec(23, 0)), evening)
        assertEquals(at(2026, 10, 12, 23, 1), NextAlarm.refreshAt(today, evening))
        assertEquals(at(2026, 10, 13, 0, 0), NextAlarm.refreshAt(null, evening))
    }
}
