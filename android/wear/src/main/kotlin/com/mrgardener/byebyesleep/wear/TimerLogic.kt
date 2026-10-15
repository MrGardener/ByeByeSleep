package com.mrgardener.byebyesleep.wear

import java.util.Locale
import kotlin.math.abs
import kotlin.math.max

/**
 * One countdown timer. Running: [endAtMs] > 0 (wall-clock millis, so a reboot
 * can reschedule it). Paused: [pausedRemainingMs] > 0. Otherwise idle, ready
 * to count [durationMs]. Pure, JVM-tested.
 */
data class TimerState(
    val durationMs: Long = TimerLogic.DEFAULT_MINUTES * TimerLogic.MINUTE,
    val endAtMs: Long = 0,
    val pausedRemainingMs: Long = 0,
) {
    val running: Boolean get() = endAtMs > 0
    val paused: Boolean get() = !running && pausedRemainingMs > 0
    val idle: Boolean get() = !running && !paused
}

object TimerLogic {
    const val MINUTE = 60_000L
    const val MIN_MINUTES = 1
    const val MAX_MINUTES = 180
    const val DEFAULT_MINUTES = 5
    val PRESETS = listOf(1, 3, 5, 10, 15, 30)

    /** What the screen shows: counts down while running, frozen when paused. */
    fun remaining(s: TimerState, nowMs: Long): Long = when {
        s.running -> max(0L, s.endAtMs - nowMs)
        s.paused -> s.pausedRemainingMs
        else -> s.durationMs
    }

    /** Running and its end has come. */
    fun isDone(s: TimerState, nowMs: Long): Boolean = s.running && nowMs >= s.endAtMs

    /** Starts from idle (full duration) or resumes from pause; running stays as is. */
    fun start(s: TimerState, nowMs: Long): TimerState = when {
        s.running -> s
        s.paused -> s.copy(endAtMs = nowMs + s.pausedRemainingMs, pausedRemainingMs = 0)
        else -> s.copy(endAtMs = nowMs + s.durationMs, pausedRemainingMs = 0)
    }

    /** Freezes the remaining time. A timer already at zero is left to ring. */
    fun pause(s: TimerState, nowMs: Long): TimerState {
        if (!s.running) return s
        val left = s.endAtMs - nowMs
        return if (left <= 0) s else s.copy(endAtMs = 0, pausedRemainingMs = left)
    }

    /** Back to idle with the same duration. */
    fun reset(s: TimerState): TimerState = TimerState(durationMs = s.durationMs)

    fun clampMinutes(minutes: Int): Int = minutes.coerceIn(MIN_MINUTES, MAX_MINUTES)

    /** Picks a duration; only while idle (a running or paused timer keeps its own). */
    fun setMinutes(s: TimerState, minutes: Int): TimerState =
        if (!s.idle) s else TimerState(durationMs = clampMinutes(minutes) * MINUTE)

    fun adjustMinutes(s: TimerState, delta: Int): TimerState =
        setMinutes(s, (s.durationMs / MINUTE).toInt() + delta)

    /** Share of the time still left, 1 → 0, for the progress ring. */
    fun fractionLeft(s: TimerState, nowMs: Long): Float {
        if (s.durationMs <= 0) return 0f
        return (remaining(s, nowMs).toFloat() / s.durationMs).coerceIn(0f, 1f)
    }

    /** "4:59", "1:05:00". Rounds up, so a running timer shows 0:00 only at the end. */
    fun format(ms: Long): String {
        val total = (max(0L, ms) + 999) / 1000
        val h = total / 3600
        val m = (total % 3600) / 60
        val sec = total % 60
        return if (h > 0) {
            String.format(Locale.ROOT, "%d:%02d:%02d", h, m, sec)
        } else {
            String.format(Locale.ROOT, "%d:%02d", m, sec)
        }
    }

    /** "5 min", "1 h", "1 h 30 min". */
    fun label(durationMs: Long): String {
        val minutes = (durationMs / MINUTE).toInt()
        val h = minutes / 60
        val m = minutes % 60
        return when {
            h == 0 -> "$m min"
            m == 0 -> "$h h"
            else -> "$h h $m min"
        }
    }

    fun encode(s: TimerState): String = "${s.durationMs},${s.endAtMs},${s.pausedRemainingMs}"

    /** Anything unreadable gives a fresh idle timer. */
    fun decode(text: String?): TimerState {
        val parts = text?.split(',')?.map { it.trim().toLongOrNull() }
        if (parts == null || parts.size != 3 || parts.any { it == null || it < 0 }) return TimerState()
        val (duration, endAt, paused) = parts.map { it!! }
        val minutes = clampMinutes((duration / MINUTE).toInt())
        return TimerState(minutes * MINUTE, endAt, if (endAt > 0) 0 else paused)
    }
}

/**
 * Turns rotary-crown scroll (pixels, clockwise positive) into whole steps, so
 * a short turn of the crown moves the timer by one minute. Pure, JVM-tested.
 */
class RotaryStepper(private val pixelsPerStep: Float) {
    private var pending = 0f

    /** Adds a scroll amount; returns how many steps (signed) to apply now. */
    fun add(pixels: Float): Int {
        // Turning back drops what was left over from the other direction.
        if (pending != 0f && (pending > 0) != (pixels > 0)) pending = 0f
        pending += pixels
        val steps = (pending / pixelsPerStep).toInt()
        pending -= steps * pixelsPerStep
        return if (abs(steps) > MAX_STEPS) MAX_STEPS * Integer.signum(steps) else steps
    }

    private companion object {
        const val MAX_STEPS = 10
    }
}
