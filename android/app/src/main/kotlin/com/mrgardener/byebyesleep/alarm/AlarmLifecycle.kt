package com.mrgardener.byebyesleep.alarm

import java.time.ZonedDateTime

interface AlarmRepository {
    fun all(): List<AlarmSpec>
    fun get(id: Int): AlarmSpec?
    fun put(spec: AlarmSpec)
    fun remove(id: Int)
}

interface AlarmClockScheduler {
    fun schedule(id: Int, triggerAtMs: Long)
    fun cancel(id: Int)
}

/** Scheduling rules for alarms; pure so it can be unit-tested on the JVM. */
class AlarmLifecycle(
    private val repo: AlarmRepository,
    private val scheduler: AlarmClockScheduler,
    private val clock: () -> ZonedDateTime,
) {
    /** Saves [spec] and returns its next trigger (epoch ms), or null if disabled. */
    fun upsert(spec: AlarmSpec): Long? {
        val saved = spec.copy(snoozeUntilMs = null, skipUntilMs = null)
        repo.put(saved)
        scheduler.cancel(saved.id)
        return scheduleRegular(saved)
    }

    fun delete(id: Int) {
        repo.remove(id)
        scheduler.cancel(id)
    }

    fun onFired(id: Int) {
        val spec = repo.get(id) ?: return
        if (spec.repeatDays.isEmpty()) {
            repo.put(spec.copy(enabled = false, snoozeUntilMs = null, skipUntilMs = null))
            scheduler.cancel(id)
        } else {
            val cleared = spec.copy(snoozeUntilMs = null, skipUntilMs = null)
            repo.put(cleared)
            scheduleRegular(cleared)
        }
    }

    /**
     * Skips the alarm's next ring ("skip the rest of the series today"): a one-shot
     * alarm is switched off, a repeating one rings again at the occurrence after.
     */
    fun skipNext(id: Int) {
        val spec = repo.get(id)?.takeIf { it.enabled } ?: return
        if (spec.repeatDays.isEmpty() || spec.atMs != null) {
            repo.put(spec.copy(enabled = false, snoozeUntilMs = null, skipUntilMs = null))
            scheduler.cancel(id)
            return
        }
        val skipped = NextTrigger.compute(spec, clock())
        val saved = spec.copy(snoozeUntilMs = null, skipUntilMs = skipped.toInstant().toEpochMilli())
        repo.put(saved)
        scheduler.schedule(id, NextTrigger.compute(saved, skipped).toInstant().toEpochMilli())
    }

    /** Returns the snooze trigger (epoch ms). */
    fun snooze(id: Int, minutes: Int): Long {
        val at = clock().plusMinutes(minutes.toLong()).toInstant().toEpochMilli()
        repo.get(id)?.let { repo.put(it.copy(snoozeUntilMs = at)) }
        scheduler.schedule(id, at)
        return at
    }

    /** Snoozes every alarm in [ids] (several can ring at once); returns the snooze trigger. */
    fun snoozeAll(ids: Collection<Int>, minutes: Int): Long {
        val at = clock().plusMinutes(minutes.toLong()).toInstant().toEpochMilli()
        for (id in ids) {
            repo.get(id)?.let { repo.put(it.copy(snoozeUntilMs = at)) }
            scheduler.schedule(id, at)
        }
        return at
    }

    /** After boot, time change or app update: a future snooze wins over the regular time. */
    fun rescheduleAll() {
        val nowMs = clock().toInstant().toEpochMilli()
        for (spec in repo.all()) {
            // One failing alarm (e.g. SecurityException) must not stop the others.
            runCatching {
                val snooze = spec.snoozeUntilMs
                val skip = spec.skipUntilMs
                when {
                    snooze != null && snooze > nowMs -> scheduler.schedule(spec.id, snooze)
                    spec.enabled && skip != null && skip > nowMs -> scheduler.schedule(
                        spec.id,
                        NextTrigger.compute(spec, ZonedDateTime.ofInstant(java.time.Instant.ofEpochMilli(skip), clock().zone))
                            .toInstant().toEpochMilli(),
                    )
                    spec.enabled -> scheduleRegular(spec)
                    else -> scheduler.cancel(spec.id)
                }
            }
        }
    }

    private fun scheduleRegular(spec: AlarmSpec): Long? {
        if (!spec.enabled) return null
        val pinned = spec.atMs
        if (pinned != null) {
            // A pinned one-shot rings at that instant or, once past, not at all.
            if (pinned > clock().toInstant().toEpochMilli()) {
                scheduler.schedule(spec.id, pinned)
                return pinned
            }
            repo.put(spec.copy(enabled = false))
            scheduler.cancel(spec.id)
            return null
        }
        val at = NextTrigger.compute(spec, clock()).toInstant().toEpochMilli()
        scheduler.schedule(spec.id, at)
        return at
    }
}
