package com.mrgardener.byebyesleep.alarm

import org.json.JSONObject

/**
 * How long an alarm may ring with nobody stopping it (owner away, phone
 * forgotten): the alarm's "Stop ringing after" setting (Dart extras
 * "maxRing", minutes), 30 by default, kept within 5–120. Pure, JVM-tested.
 */
object RingLimit {
    const val DEFAULT_MINUTES = 30

    fun minutes(extrasJson: String): Int {
        val set = runCatching { JSONObject(extrasJson).optInt("maxRing", DEFAULT_MINUTES) }
            .getOrDefault(DEFAULT_MINUTES)
        return set.coerceIn(5, 120)
    }

    /** Time left before the ring stops itself (0 = now). */
    fun remainingMs(limitMinutes: Int, startedAtMs: Long, nowMs: Long): Long =
        (startedAtMs + limitMinutes * 60_000L - nowMs).coerceAtLeast(0)
}
