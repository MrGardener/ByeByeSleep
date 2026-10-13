package com.mrgardener.byebyesleep.alarm

import org.junit.Assert.assertEquals
import org.junit.Test

class RingLimitTest {
    @Test fun default_isThirtyMinutes() {
        assertEquals(30, RingLimit.minutes(""))
        assertEquals(30, RingLimit.minutes("not json"))
        assertEquals(30, RingLimit.minutes("""{"reminder":{}}"""))
    }

    @Test fun takesTheAlarmsSetting_withinSafeBounds() {
        assertEquals(10, RingLimit.minutes("""{"maxRing":10}"""))
        assertEquals(5, RingLimit.minutes("""{"maxRing":1}"""))
        assertEquals(120, RingLimit.minutes("""{"maxRing":999}"""))
    }

    @Test fun remaining_countsFromWhenTheRingStarted() {
        // A ring redelivered after a process restart keeps its original end.
        assertEquals(20 * 60_000L, RingLimit.remainingMs(30, startedAtMs = 0, nowMs = 10 * 60_000L))
        assertEquals(0L, RingLimit.remainingMs(30, startedAtMs = 0, nowMs = 40 * 60_000L))
    }
}
