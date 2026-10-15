package com.mrgardener.byebyesleep.wear

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class TimerLogicTest {
    private val min = TimerLogic.MINUTE
    private val t0 = 1_760_000_000_000L

    @Test fun idle_showsTheFullDuration() {
        val s = TimerState(durationMs = 3 * min)
        assertTrue(s.idle)
        assertEquals(3 * min, TimerLogic.remaining(s, t0))
        assertEquals("3:00", TimerLogic.format(TimerLogic.remaining(s, t0)))
    }

    @Test fun start_setsTheEndInstant() {
        val s = TimerLogic.start(TimerState(durationMs = 5 * min), t0)
        assertTrue(s.running)
        assertEquals(t0 + 5 * min, s.endAtMs)
        assertEquals(5 * min - 1_000, TimerLogic.remaining(s, t0 + 1_000))
        assertFalse(TimerLogic.isDone(s, t0 + 5 * min - 1))
        assertTrue(TimerLogic.isDone(s, t0 + 5 * min))
        assertEquals(0, TimerLogic.remaining(s, t0 + 6 * min))
    }

    @Test fun startTwice_keepsTheFirstEnd() {
        val s = TimerLogic.start(TimerState(durationMs = min), t0)
        assertEquals(s, TimerLogic.start(s, t0 + 10_000))
    }

    @Test fun pauseAndResume_keepTheRemainingTime() {
        val running = TimerLogic.start(TimerState(durationMs = 10 * min), t0)
        val paused = TimerLogic.pause(running, t0 + 4 * min)
        assertTrue(paused.paused)
        assertEquals(6 * min, TimerLogic.remaining(paused, t0 + 9 * min)) // frozen
        val resumed = TimerLogic.start(paused, t0 + 20 * min)
        assertEquals(t0 + 26 * min, resumed.endAtMs)
        assertEquals(10 * min, resumed.durationMs)
    }

    @Test fun pauseAtZero_isLeftToRing() {
        val running = TimerLogic.start(TimerState(durationMs = min), t0)
        assertEquals(running, TimerLogic.pause(running, t0 + min))
        val idle = TimerState()
        assertEquals(idle, TimerLogic.pause(idle, t0))
    }

    @Test fun reset_keepsTheDuration() {
        val paused = TimerLogic.pause(TimerLogic.start(TimerState(durationMs = 15 * min), t0), t0 + min)
        assertEquals(TimerState(durationMs = 15 * min), TimerLogic.reset(paused))
    }

    @Test fun minutes_areClampedAndOnlyChangeWhileIdle() {
        val s = TimerState(durationMs = 2 * min)
        assertEquals(min, TimerLogic.adjustMinutes(s, -5).durationMs)
        assertEquals(180 * min, TimerLogic.setMinutes(s, 999).durationMs)
        assertEquals(30 * min, TimerLogic.setMinutes(s, 30).durationMs)
        val running = TimerLogic.start(s, t0)
        assertEquals(running, TimerLogic.adjustMinutes(running, 1))
    }

    @Test fun presets() {
        assertEquals(listOf(1, 3, 5, 10, 15, 30), TimerLogic.PRESETS)
    }

    @Test fun format_roundsUpAndShowsHours() {
        assertEquals("0:00", TimerLogic.format(0))
        assertEquals("0:01", TimerLogic.format(1))
        assertEquals("0:59", TimerLogic.format(59_000))
        assertEquals("1:00:00", TimerLogic.format(60 * min))
        assertEquals("2:05:09", TimerLogic.format(2 * 60 * min + 5 * min + 9_000))
        assertEquals("0:00", TimerLogic.format(-500))
    }

    @Test fun label() {
        assertEquals("5 min", TimerLogic.label(5 * min))
        assertEquals("1 h", TimerLogic.label(60 * min))
        assertEquals("1 h 30 min", TimerLogic.label(90 * min))
    }

    @Test fun fractionLeft() {
        val s = TimerLogic.start(TimerState(durationMs = 4 * min), t0)
        assertEquals(1f, TimerLogic.fractionLeft(s, t0), 0.0001f)
        assertEquals(0.25f, TimerLogic.fractionLeft(s, t0 + 3 * min), 0.0001f)
        assertEquals(0f, TimerLogic.fractionLeft(s, t0 + 9 * min), 0.0001f)
    }

    @Test fun encodeDecode_roundTrips() {
        val states = listOf(
            TimerState(durationMs = 3 * min),
            TimerLogic.start(TimerState(durationMs = 10 * min), t0),
            TimerLogic.pause(TimerLogic.start(TimerState(durationMs = 10 * min), t0), t0 + 61_234),
        )
        for (s in states) assertEquals(s, TimerLogic.decode(TimerLogic.encode(s)))
    }

    @Test fun decode_badTextGivesAFreshTimer() {
        for (bad in listOf(null, "", "x", "1,2", "a,b,c", "-1,0,0", "1,2,3,4")) {
            assertEquals(TimerState(), TimerLogic.decode(bad))
        }
        // Out-of-range durations are clamped.
        assertEquals(min, TimerLogic.decode("5,0,0").durationMs)
    }

    @Test fun rotary_stepsPerThreshold() {
        val r = RotaryStepper(40f)
        assertEquals(0, r.add(30f))
        assertEquals(1, r.add(15f)) // 45 → 1 step, 5 left
        assertEquals(0, r.add(30f)) // 35
        assertEquals(0, r.add(-10f)) // direction change drops the 35
        assertEquals(-1, r.add(-35f))
        assertEquals(10, r.add(4000f)) // capped per event
    }
}
