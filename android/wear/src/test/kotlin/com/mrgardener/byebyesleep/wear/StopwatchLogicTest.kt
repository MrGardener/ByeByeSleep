package com.mrgardener.byebyesleep.wear

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class StopwatchLogicTest {
    private val t0 = 1_760_000_000_000L

    @Test fun cleared_isZero() {
        val s = StopwatchState()
        assertTrue(s.clear)
        assertFalse(s.running)
        assertEquals(0, StopwatchLogic.elapsed(s, t0))
        assertEquals("00:00.00", StopwatchLogic.format(0))
    }

    @Test fun running_countsFromTheStart() {
        val s = StopwatchLogic.start(StopwatchState(), t0)
        assertTrue(s.running)
        assertEquals(7_420, StopwatchLogic.elapsed(s, t0 + 7_420))
        assertEquals(s, StopwatchLogic.start(s, t0 + 5_000)) // start again: no change
    }

    @Test fun pauseAndResume_addUp() {
        var s = StopwatchLogic.start(StopwatchState(), t0)
        s = StopwatchLogic.pause(s, t0 + 10_000)
        assertFalse(s.running)
        assertEquals(10_000, StopwatchLogic.elapsed(s, t0 + 99_000)) // frozen
        s = StopwatchLogic.start(s, t0 + 60_000)
        assertEquals(15_000, StopwatchLogic.elapsed(s, t0 + 65_000))
        val once = StopwatchLogic.pause(s, t0 + 70_000)
        assertEquals(once, StopwatchLogic.pause(once, t0 + 80_000)) // pause again: no change
        assertEquals(20_000, StopwatchLogic.elapsed(once, t0 + 80_000))
    }

    @Test fun clockSetBackwards_neverGoesNegative() {
        val s = StopwatchLogic.start(StopwatchState(accumulatedMs = 3_000), t0)
        assertEquals(3_000, StopwatchLogic.elapsed(s, t0 - 50_000))
    }

    @Test fun laps_onlyWhileRunning() {
        var s = StopwatchLogic.start(StopwatchState(), t0)
        s = StopwatchLogic.lap(s, t0 + 30_000)
        s = StopwatchLogic.lap(s, t0 + 55_000)
        s = StopwatchLogic.lap(s, t0 + 95_000)
        assertEquals(listOf(30_000L, 55_000L, 95_000L), s.laps)
        val paused = StopwatchLogic.pause(s, t0 + 100_000)
        assertEquals(paused, StopwatchLogic.lap(paused, t0 + 120_000))
    }

    @Test fun rows_newestFirstWithFastestAndSlowest() {
        val s = StopwatchState(accumulatedMs = 100_000, laps = listOf(30_000, 55_000, 95_000))
        val rows = StopwatchLogic.rows(s)
        assertEquals(listOf(3, 2, 1), rows.map { it.number })
        assertEquals(listOf(40_000L, 25_000L, 30_000L), rows.map { it.lapMs })
        assertEquals(listOf(95_000L, 55_000L, 30_000L), rows.map { it.splitMs })
        assertEquals(listOf(false, true, false), rows.map { it.fastest })
        assertEquals(listOf(true, false, false), rows.map { it.slowest })
    }

    @Test fun rows_singleOrEqualLapsAreNotMarked() {
        val one = StopwatchLogic.rows(StopwatchState(laps = listOf(5_000)))
        assertFalse(one[0].fastest || one[0].slowest)
        val equal = StopwatchLogic.rows(StopwatchState(laps = listOf(5_000, 10_000)))
        assertEquals(1, equal.count { it.fastest })
        assertEquals(0, equal.count { it.slowest })
    }

    @Test fun laps_areCapped() {
        var s = StopwatchLogic.start(StopwatchState(), t0)
        repeat(StopwatchLogic.MAX_LAPS + 5) { s = StopwatchLogic.lap(s, t0 + 1_000L * (it + 1)) }
        assertEquals(StopwatchLogic.MAX_LAPS, s.laps.size)
        assertFalse(StopwatchLogic.canLap(s))
    }

    @Test fun reset_clearsAll() {
        assertTrue(StopwatchLogic.reset().clear)
    }

    @Test fun format() {
        assertEquals("00:07.42", StopwatchLogic.format(7_429))
        assertEquals("12:34.56", StopwatchLogic.format((12 * 60 + 34) * 1000L + 560))
        assertEquals("1:02:03.45", StopwatchLogic.format((3600 + 2 * 60 + 3) * 1000L + 450))
        assertEquals("00:00.00", StopwatchLogic.format(-5))
    }

    @Test fun encodeDecode_roundTrips() {
        val states = listOf(
            StopwatchState(),
            StopwatchLogic.start(StopwatchState(), t0),
            StopwatchState(startedAtMs = t0, accumulatedMs = 12_345, laps = listOf(1_000, 5_000)),
            StopwatchState(accumulatedMs = 99_999, laps = listOf(42)),
        )
        for (s in states) assertEquals(s, StopwatchLogic.decode(StopwatchLogic.encode(s)))
    }

    @Test fun decode_badTextGivesACleared() {
        for (bad in listOf(null, "", "1;2", "x;0;", "-1;0;", "0;-4;")) {
            assertEquals(StopwatchState(), StopwatchLogic.decode(bad))
        }
        assertEquals(listOf(1L, 3L), StopwatchLogic.decode("0;5;3,x,1,-2").laps)
    }
}
