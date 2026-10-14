package com.mrgardener.byebyesleep.alarm

import org.junit.Assert.assertEquals
import org.junit.Test

class ZoneOffsetsTest {
    private val summer = at(2026, 7, 1, 12, 0).toInstant().toEpochMilli()
    private val winter = at(2026, 1, 15, 12, 0).toInstant().toEpochMilli()

    @Test fun offsets_followSummerTime() {
        assertEquals(mapOf("Europe/Paris" to 7200), ZoneOffsets.offsets(listOf("Europe/Paris"), summer))
        assertEquals(mapOf("Europe/Paris" to 3600), ZoneOffsets.offsets(listOf("Europe/Paris"), winter))
    }

    @Test fun offsets_halfHourZonesAndUnknownIds() {
        assertEquals(
            mapOf("Asia/Kolkata" to 19800),
            ZoneOffsets.offsets(listOf("Asia/Kolkata", "Not/AZone"), summer),
        )
    }
}
