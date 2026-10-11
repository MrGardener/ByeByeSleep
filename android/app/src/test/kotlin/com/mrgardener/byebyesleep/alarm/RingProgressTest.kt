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
}
