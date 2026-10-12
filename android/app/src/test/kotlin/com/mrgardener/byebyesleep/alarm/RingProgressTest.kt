package com.mrgardener.byebyesleep.alarm

import org.junit.Assert.assertEquals
import org.junit.Test

class RingProgressTest {
    @Test fun ringProgress_roundTrip() {
        val p = RingProgress(alarmId = 3, stageIndex = 2, startedAtMs = 1_760_000_000_000L)
        assertEquals(p, RingProgress.fromJson(p.toJson()))
    }

    @Test fun ringProgress_channelMapRoundTrip() {
        val p = RingProgress(alarmId = 3, stageIndex = 2, startedAtMs = 1_760_000_000_000L)
        assertEquals(p, RingProgress.fromChannelMap(p.toChannelMap()))
    }

    private val now = 1_760_000_000_000L
    private val old = RingProgress(alarmId = 3, stageIndex = 4, startedAtMs = now - 24 * 3600_000L)

    @Test fun freshRing_afterUncleanEnd_startsOver() {
        assertEquals(RingProgress(3, 0, now), RingProgress.onRing(old, alarmId = 3, nowMs = now, redelivered = false))
    }

    @Test fun redeliveredRing_keepsProgress() {
        val current = RingProgress(3, 2, now - 60_000L)
        assertEquals(current, RingProgress.onRing(current, alarmId = 3, nowMs = now, redelivered = true))
    }

    @Test fun redeliveredRing_withoutProgress_startsOver() {
        assertEquals(RingProgress(3, 0, now), RingProgress.onRing(null, alarmId = 3, nowMs = now, redelivered = true))
    }

    @Test fun redeliveredRing_forOtherAlarm_startsOver() {
        assertEquals(RingProgress(5, 0, now), RingProgress.onRing(old.copy(startedAtMs = now), alarmId = 5, nowMs = now, redelivered = true))
    }

    @Test fun staleProgress_isIgnored() {
        assertEquals(null, RingProgress.current(old, nowMs = now, ringing = true))
        val recent = RingProgress(3, 1, now - 10 * 60_000L)
        assertEquals(recent, RingProgress.current(recent, nowMs = now, ringing = true))
    }

    @Test fun progress_isIgnoredWhenNothingRings() {
        val recent = RingProgress(3, 1, now - 60_000L)
        assertEquals(null, RingProgress.current(recent, nowMs = now, ringing = false))
    }
}
