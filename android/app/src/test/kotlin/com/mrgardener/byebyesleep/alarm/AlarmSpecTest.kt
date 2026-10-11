package com.mrgardener.byebyesleep.alarm

import org.junit.Assert.assertEquals
import org.junit.Test

class AlarmSpecTest {
    private val full = AlarmSpec(3, 6, 45, setOf(5, 1), "Gym", false, 1_760_000_000_000L)

    @Test fun json_roundTrip() = assertEquals(full, AlarmSpec.fromJson(full.toJson()))

    @Test fun json_roundTrip_withoutSnooze() {
        val s = full.copy(snoozeUntilMs = null)
        assertEquals(s, AlarmSpec.fromJson(s.toJson()))
    }

    @Test fun channelMap_roundTrip() {
        val s = full.copy(snoozeUntilMs = null)
        val map = s.toChannelMap()
        assertEquals(listOf(1, 5), map["repeatDays"])
        assertEquals(setOf("id", "hour", "minute", "repeatDays", "label", "enabled", "stages"), map.keys)
        assertEquals(s, AlarmSpec.fromChannelMap(map))
    }

    @Test fun channelMap_acceptsLongNumbers() {
        // Flutter's codec may deliver small ints as Int or Long.
        val m = mapOf("id" to 2L, "hour" to 7, "minute" to 0L, "repeatDays" to listOf(1L, 2), "label" to "", "enabled" to true)
        assertEquals(AlarmSpec(2, 7, 0, setOf(1, 2), "", true), AlarmSpec.fromChannelMap(m))
    }

    @Test fun json_roundTrip_keepsStages() {
        val s = full.copy(stagesJson = "[{\"challenge\":\"tiltMaze\"}]")
        assertEquals(s, AlarmSpec.fromJson(s.toJson()))
    }

    @Test fun channelMap_includesStages() {
        val s = full.copy(snoozeUntilMs = null, stagesJson = "[]")
        assertEquals("[]", s.toChannelMap()["stages"])
        assertEquals(s, AlarmSpec.fromChannelMap(s.toChannelMap()))
    }
}
