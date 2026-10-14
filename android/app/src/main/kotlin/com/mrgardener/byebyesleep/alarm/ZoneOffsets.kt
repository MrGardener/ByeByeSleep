package com.mrgardener.byebyesleep.alarm

import java.time.Instant
import java.time.ZoneId

/** UTC offsets of time zones (world clocks), from the phone's zone database. Pure, JVM-tested. */
object ZoneOffsets {
    fun offsets(zones: List<String>, atMs: Long): Map<String, Int> {
        val at = Instant.ofEpochMilli(atMs)
        return zones.mapNotNull { id ->
            runCatching { id to ZoneId.of(id).rules.getOffset(at).totalSeconds }.getOrNull()
        }.toMap()
    }
}
