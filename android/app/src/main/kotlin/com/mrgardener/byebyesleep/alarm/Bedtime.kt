package com.mrgardener.byebyesleep.alarm

import java.time.Instant
import java.time.ZonedDateTime

/** "Time for bed" reminder: the next morning's first alarm minus the sleep goal. Pure, JVM-tested. */
object Bedtime {
    data class Reminder(val at: ZonedDateTime, val alarm: ZonedDateTime)

    /** Rings this close after a morning's first ring belong to that morning (a series). */
    private const val SAME_MORNING_HOURS = 4L

    fun next(specs: List<AlarmSpec>, now: ZonedDateTime, sleepMinutes: Int): Reminder? {
        var after = now
        repeat(8) {
            val ring = firstRing(specs, after) ?: return null
            val bed = ring.minusMinutes(sleepMinutes.toLong())
            if (bed.isAfter(now)) return Reminder(bed, ring)
            // Bedtime for this morning has passed: the next morning's first ring.
            after = ring.plusHours(SAME_MORNING_HOURS)
        }
        return null
    }

    private fun firstRing(specs: List<AlarmSpec>, after: ZonedDateTime): ZonedDateTime? =
        specs.filter { it.enabled }.mapNotNull { spec ->
            val pinned = spec.atMs
            if (pinned != null) {
                ZonedDateTime.ofInstant(Instant.ofEpochMilli(pinned), after.zone).takeIf { it.isAfter(after) }
            } else {
                NextTrigger.compute(spec, after)
            }
        }.minOrNull()

    fun text(alarm: ZonedDateTime, sleepMinutes: Int): String {
        val h = sleepMinutes / 60
        val m = sleepMinutes % 60
        val sleep = if (m == 0) "$h h" else "$h h $m min"
        return "Your alarm rings at %02d:%02d — go to bed now for %s of sleep.".format(alarm.hour, alarm.minute, sleep)
    }
}
