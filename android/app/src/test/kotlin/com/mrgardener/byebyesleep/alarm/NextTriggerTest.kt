package com.mrgardener.byebyesleep.alarm

import java.time.ZoneOffset
import java.time.ZonedDateTime
import org.junit.Assert.assertEquals
import org.junit.Test

class NextTriggerTest {
    @Test fun oneShot_laterToday() =
        assertEquals(at(2026, 10, 12, 7, 0), NextTrigger.compute(spec(7, 0), at(2026, 10, 12, 6, 0)))

    @Test fun oneShot_sameMinute_goesTomorrow() =
        assertEquals(at(2026, 10, 13, 7, 0), NextTrigger.compute(spec(7, 0), at(2026, 10, 12, 7, 0)))

    // 2026-10-12 is a Monday; {3} = Wednesday.
    @Test fun repeat_skipsToNextAllowedDay() =
        assertEquals(at(2026, 10, 14, 7, 0), NextTrigger.compute(spec(7, 0, setOf(3)), at(2026, 10, 12, 8, 0)))

    @Test fun repeat_sameDayStillAhead() =
        assertEquals(at(2026, 10, 12, 7, 0), NextTrigger.compute(spec(7, 0, setOf(1)), at(2026, 10, 12, 6, 59)))

    @Test fun repeat_onlyToday_alreadyPassed_goesNextWeek() =
        assertEquals(at(2026, 10, 19, 7, 0), NextTrigger.compute(spec(7, 0, setOf(1)), at(2026, 10, 12, 7, 30)))

    // 2026-03-08 02:30 does not exist in New York (clocks jump 02:00 -> 03:00).
    @Test fun nextTrigger_springForwardGap() =
        assertEquals(
            ZonedDateTime.of(2026, 3, 8, 3, 30, 0, 0, zone),
            NextTrigger.compute(spec(2, 30), at(2026, 3, 8, 0, 0)),
        )

    // 2026-11-01 01:30 happens twice; the first one (EDT, -04:00) wins.
    @Test fun nextTrigger_fallBackOverlap() {
        val r = NextTrigger.compute(spec(1, 30), at(2026, 11, 1, 0, 0))
        assertEquals(ZoneOffset.ofHours(-4), r.offset)
        assertEquals(1, r.hour)
    }
}
