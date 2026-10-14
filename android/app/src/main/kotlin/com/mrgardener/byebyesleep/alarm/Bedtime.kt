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

    enum class Kind { WIND_DOWN, BEDTIME, QUIET_OFF }

    data class Event(val kind: Kind, val at: ZonedDateTime)

    /**
     * What happens around one night: an optional wind-down reminder, the
     * bedtime reminder (which also starts quiet hours when they are on) and
     * the end of quiet hours at the alarm. Events already past are dropped.
     */
    fun plan(reminder: Reminder, now: ZonedDateTime, windDownMinutes: Int, quietHours: Boolean): List<Event> =
        listOfNotNull(
            if (windDownMinutes > 0) Event(Kind.WIND_DOWN, reminder.at.minusMinutes(windDownMinutes.toLong())) else null,
            Event(Kind.BEDTIME, reminder.at),
            if (quietHours) Event(Kind.QUIET_OFF, reminder.alarm) else null,
        ).filter { it.at.isAfter(now) }

    fun windDownText(minutes: Int): String {
        val time = if (minutes % 60 == 0) "${minutes / 60} h" else "$minutes min"
        return "Bedtime in $time — time to wind down."
    }
}
