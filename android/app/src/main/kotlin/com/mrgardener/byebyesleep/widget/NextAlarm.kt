package com.mrgardener.byebyesleep.widget

import com.mrgardener.byebyesleep.alarm.AlarmSpec
import com.mrgardener.byebyesleep.alarm.NextTrigger
import java.time.Instant
import java.time.ZoneId
import java.time.ZonedDateTime
import java.time.format.DateTimeFormatter
import java.time.temporal.ChronoUnit
import java.util.Locale

/**
 * The next alarm to ring, for the home-screen widgets and the screen saver.
 * Follows the same rules as AlarmLifecycle's scheduling: a pending snooze (or
 * "check I'm awake" ring) wins, a pinned one-shot rings at its instant, a skipped
 * ring is passed over. Pure, JVM-tested.
 */
object NextAlarm {
    data class Upcoming(val spec: AlarmSpec, val at: ZonedDateTime, val snoozed: Boolean)

    /** The earliest ring strictly after [now] across [specs], or null if none rings. */
    fun find(specs: List<AlarmSpec>, now: ZonedDateTime): Upcoming? =
        specs.mapNotNull { next(it, now) }.minByOrNull { it.at.toInstant() }

    /** The next ring of one alarm. */
    fun next(spec: AlarmSpec, now: ZonedDateTime): Upcoming? {
        val nowMs = now.toInstant().toEpochMilli()
        // A snooze rings even for a one-shot that was switched off when it fired.
        val snooze = spec.snoozeUntilMs?.takeIf { it > nowMs }
            ?.let { Upcoming(spec, ofMs(it, now.zone), snoozed = true) }
        val regular = if (spec.enabled) regular(spec, now)?.let { Upcoming(spec, it, snoozed = false) } else null
        return listOfNotNull(snooze, regular).minByOrNull { it.at.toInstant() }
    }

    private fun regular(spec: AlarmSpec, now: ZonedDateTime): ZonedDateTime? {
        val nowMs = now.toInstant().toEpochMilli()
        val pinned = spec.atMs
        if (pinned != null) return if (pinned > nowMs) ofMs(pinned, now.zone) else null
        val skip = spec.skipUntilMs
        val from = if (skip != null && skip > nowMs) ofMs(skip, now.zone) else now
        return NextTrigger.compute(spec, from)
    }

    private fun ofMs(ms: Long, zone: ZoneId) = ZonedDateTime.ofInstant(Instant.ofEpochMilli(ms), zone)

    /** "06:30" or "6:30 AM". */
    fun time(at: ZonedDateTime, is24h: Boolean): String =
        at.format(DateTimeFormatter.ofPattern(if (is24h) "HH:mm" else "h:mm a", Locale.ENGLISH))

    /** "Today", "Tomorrow", "Friday" (within a week) or "Mon 26 Oct", seen from [now]. */
    fun day(at: ZonedDateTime, now: ZonedDateTime): String {
        val local = at.withZoneSameInstant(now.zone)
        val days = ChronoUnit.DAYS.between(now.toLocalDate(), local.toLocalDate())
        val pattern = when (days) {
            0L -> return "Today"
            1L -> return "Tomorrow"
            in 2L..6L -> "EEEE"
            else -> "EEE d MMM"
        }
        return local.format(DateTimeFormatter.ofPattern(pattern, Locale.ENGLISH))
    }

    /** One line for the clock widget and the screen saver: "Next alarm 06:30 · Tomorrow". */
    fun summary(next: Upcoming?, now: ZonedDateTime, is24h: Boolean): String {
        if (next == null) return "No alarm set"
        val prefix = if (next.snoozed) "Snoozed until" else "Next alarm"
        return "$prefix ${time(next.at, is24h)} · ${day(next.at, now)}"
    }

    /** Second line of the next-alarm widget: "Tomorrow · Wake up", "Snoozed · Wake up". */
    fun detail(next: Upcoming, now: ZonedDateTime): String {
        val head = if (next.snoozed) "Snoozed" else day(next.at, now)
        val label = next.spec.label.trim()
        return if (label.isEmpty()) head else "$head · $label"
    }

    /**
     * When the widgets must be redrawn without anyone telling them: just after the
     * next ring (it fired, so the next one changes) or at midnight ("Tomorrow"
     * becomes "Today"), whichever comes first.
     */
    fun refreshAt(next: Upcoming?, now: ZonedDateTime): ZonedDateTime {
        val midnight = now.toLocalDate().plusDays(1).atStartOfDay(now.zone)
        val afterRing = next?.at?.plusMinutes(1) ?: return midnight
        return if (afterRing.isBefore(midnight)) afterRing else midnight
    }
}
