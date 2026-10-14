package com.mrgardener.byebyesleep.widget

import com.mrgardener.byebyesleep.alarm.at
import java.time.ZoneId
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class WorldCitiesTest {
    private val newYork = ZoneId.of("America/New_York")

    @Test fun everyZoneIsKnownToJavaTime() {
        WorldCities.all.forEach { ZoneId.of(it.zone) }
        assertEquals(47, WorldCities.all.size)
    }

    @Test fun search_ignoresCaseAndAccents() {
        assertEquals(listOf("São Paulo"), WorldCities.search("sao").map { it.name })
        assertEquals(listOf("Bogotá"), WorldCities.search("BOGOTA").map { it.name })
        assertTrue(WorldCities.search("usa").map { it.name }.containsAll(listOf("Chicago", "New York")))
        assertEquals(WorldCities.all, WorldCities.search("  "))
    }

    @Test fun storedChoice_keepsKnownZonesUpToThree() {
        assertEquals(listOf("Asia/Tokyo", "Europe/London"), WorldCities.decode("Asia/Tokyo, Mars/Base,Europe/London,Asia/Tokyo"))
        assertEquals(emptyList<String>(), WorldCities.decode(null))
        assertEquals(
            "Asia/Tokyo,Europe/London,Europe/Paris",
            WorldCities.encode(listOf("Asia/Tokyo", "Europe/London", "Europe/Paris", "Asia/Seoul")),
        )
    }

    @Test fun difference_fromHere_withSummerTime() {
        // 12 Oct 2026: New York EDT (−4), Tokyo +9, London BST (+1), Kathmandu +5:45.
        val now = at(2026, 10, 12, 12, 0).toInstant()
        assertEquals("+13 h", WorldCities.difference("Asia/Tokyo", newYork, now))
        assertEquals("+5 h", WorldCities.difference("Europe/London", newYork, now))
        assertEquals("+9 h 45 min", WorldCities.difference("Asia/Kathmandu", newYork, now))
        assertEquals("−3 h", WorldCities.difference("America/Los_Angeles", newYork, now))
        assertEquals("Same time", WorldCities.difference("America/Toronto", newYork, now))
        // After London leaves summer time (25 Oct) but before New York does (1 Nov).
        assertEquals("+4 h", WorldCities.difference("Europe/London", newYork, at(2026, 10, 28, 12, 0).toInstant()))
    }
}
