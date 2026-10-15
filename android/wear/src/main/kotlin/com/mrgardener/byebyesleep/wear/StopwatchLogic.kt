package com.mrgardener.byebyesleep.wear

import java.util.Locale
import kotlin.math.max

/**
 * The stopwatch. Running: [startedAtMs] > 0 (wall-clock millis), counting on
 * top of [accumulatedMs]. [laps] holds the total time at each lap press, in
 * order. Stored as text, so it keeps counting when the screen is closed or the
 * app is killed. Pure, JVM-tested.
 */
data class StopwatchState(
    val startedAtMs: Long = 0,
    val accumulatedMs: Long = 0,
    val laps: List<Long> = emptyList(),
) {
    val running: Boolean get() = startedAtMs > 0
    val clear: Boolean get() = !running && accumulatedMs == 0L && laps.isEmpty()
}

/** One row of the lap list: lap [number], its own time and the total at that point. */
data class LapRow(
    val number: Int,
    val lapMs: Long,
    val splitMs: Long,
    val fastest: Boolean,
    val slowest: Boolean,
)

object StopwatchLogic {
    const val MAX_LAPS = 99

    /** A clock set backwards must not make the time go negative. */
    fun elapsed(s: StopwatchState, nowMs: Long): Long =
        s.accumulatedMs + if (s.running) max(0L, nowMs - s.startedAtMs) else 0L

    fun start(s: StopwatchState, nowMs: Long): StopwatchState =
        if (s.running) s else s.copy(startedAtMs = max(1L, nowMs))

    fun pause(s: StopwatchState, nowMs: Long): StopwatchState =
        if (!s.running) s else s.copy(startedAtMs = 0, accumulatedMs = elapsed(s, nowMs))

    fun reset(): StopwatchState = StopwatchState()

    fun canLap(s: StopwatchState): Boolean = s.running && s.laps.size < MAX_LAPS

    fun lap(s: StopwatchState, nowMs: Long): StopwatchState =
        if (!canLap(s)) s else s.copy(laps = s.laps + elapsed(s, nowMs))

    /** Newest first; the fastest and slowest lap are marked once there are two. */
    fun rows(s: StopwatchState): List<LapRow> {
        val lapTimes = s.laps.mapIndexed { i, split -> split - if (i == 0) 0L else s.laps[i - 1] }
        val mark = lapTimes.size >= 2
        val fastest = lapTimes.minOrNull()
        val slowest = lapTimes.maxOrNull()
        val fastestIndex = if (mark) lapTimes.indexOf(fastest) else -1
        val slowestIndex = if (mark && fastest != slowest) lapTimes.lastIndexOf(slowest) else -1
        return lapTimes.indices.reversed().map { i ->
            LapRow(i + 1, lapTimes[i], s.laps[i], i == fastestIndex, i == slowestIndex)
        }
    }

    /** "00:07.42", "12:34.56", "1:02:03.45" (hundredths, rounded down). */
    fun format(ms: Long): String {
        val t = max(0L, ms)
        val cs = (t % 1000) / 10
        val totalSec = t / 1000
        val h = totalSec / 3600
        val m = (totalSec % 3600) / 60
        val sec = totalSec % 60
        return if (h > 0) {
            String.format(Locale.ROOT, "%d:%02d:%02d.%02d", h, m, sec, cs)
        } else {
            String.format(Locale.ROOT, "%02d:%02d.%02d", m, sec, cs)
        }
    }

    fun encode(s: StopwatchState): String =
        "${s.startedAtMs};${s.accumulatedMs};${s.laps.joinToString(",")}"

    /** Anything unreadable gives a cleared stopwatch. */
    fun decode(text: String?): StopwatchState {
        val parts = text?.split(';') ?: return StopwatchState()
        if (parts.size != 3) return StopwatchState()
        val started = parts[0].toLongOrNull()
        val acc = parts[1].toLongOrNull()
        if (started == null || acc == null || started < 0 || acc < 0) return StopwatchState()
        val laps = if (parts[2].isBlank()) emptyList() else parts[2].split(',').mapNotNull { it.toLongOrNull() }
        return StopwatchState(started, acc, laps.filter { it >= 0 }.sorted().take(MAX_LAPS))
    }
}
