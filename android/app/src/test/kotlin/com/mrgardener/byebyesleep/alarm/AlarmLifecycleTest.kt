package com.mrgardener.byebyesleep.alarm

import java.time.ZonedDateTime
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Before
import org.junit.Test

class AlarmLifecycleTest {
    private lateinit var repo: FakeRepo
    private lateinit var sched: FakeScheduler
    private var now: ZonedDateTime = at(2026, 10, 12, 6, 0)
    private lateinit var lifecycle: AlarmLifecycle

    private fun ms(t: ZonedDateTime) = t.toInstant().toEpochMilli()

    @Before fun setUp() {
        repo = FakeRepo()
        sched = FakeScheduler()
        now = at(2026, 10, 12, 6, 0)
        lifecycle = AlarmLifecycle(repo, sched) { now }
    }

    @Test fun upsert_enabled_schedulesAndReturnsTrigger() {
        val r = lifecycle.upsert(spec(7, 0))
        assertEquals(ms(at(2026, 10, 12, 7, 0)), r)
        assertEquals(r, sched.scheduled[1])
    }

    @Test fun upsert_disabled_cancelsAndReturnsNull() {
        lifecycle.upsert(spec(7, 0))
        assertNull(lifecycle.upsert(spec(7, 0, enabled = false)))
        assertEquals("cancel:1", sched.calls.last())
        assertFalse(repo.get(1)!!.enabled)
    }

    @Test fun upsert_clearsPendingSnooze() {
        lifecycle.upsert(spec(7, 0))
        lifecycle.snooze(1, 9)
        lifecycle.upsert(spec(8, 0))
        assertNull(repo.get(1)!!.snoozeUntilMs)
    }

    @Test fun delete_removesAndCancels() {
        lifecycle.upsert(spec(7, 0))
        lifecycle.delete(1)
        assertNull(repo.get(1))
        assertEquals("cancel:1", sched.calls.last())
    }

    @Test fun onFired_oneShot_disables() {
        lifecycle.upsert(spec(7, 0))
        now = at(2026, 10, 12, 7, 0)
        lifecycle.onFired(1)
        assertFalse(repo.get(1)!!.enabled)
        assertEquals("cancel:1", sched.calls.last())
    }

    @Test fun onFired_repeating_schedulesNextOccurrence() {
        lifecycle.upsert(spec(7, 0, (1..7).toSet()))
        now = at(2026, 10, 12, 7, 0)
        lifecycle.onFired(1)
        assertEquals(ms(at(2026, 10, 13, 7, 0)), sched.scheduled[1])
    }

    @Test fun onFired_afterSnooze_schedulesNextRegular() {
        lifecycle.upsert(spec(7, 0, (1..7).toSet()))
        now = at(2026, 10, 12, 7, 0)
        lifecycle.onFired(1)
        assertEquals(ms(at(2026, 10, 12, 7, 9)), lifecycle.snooze(1, 9))
        now = at(2026, 10, 12, 7, 9)
        lifecycle.onFired(1)
        assertNull(repo.get(1)!!.snoozeUntilMs)
        assertEquals(ms(at(2026, 10, 13, 7, 0)), sched.scheduled[1])
    }

    @Test fun onFired_unknownId_isIgnored() {
        lifecycle.onFired(42)
        assertEquals(emptyList<String>(), sched.calls)
    }

    @Test fun rescheduleAll_restoresFutureSnooze() {
        lifecycle.upsert(spec(7, 0))
        now = at(2026, 10, 12, 7, 0)
        lifecycle.onFired(1) // one-shot: now disabled
        lifecycle.snooze(1, 9)
        sched.scheduled.clear()
        now = at(2026, 10, 12, 7, 5) // reboot happened
        lifecycle.rescheduleAll()
        assertEquals(ms(at(2026, 10, 12, 7, 9)), sched.scheduled[1])
    }

    @Test fun rescheduleAll_ignoresPastSnoozeAndDisabled() {
        lifecycle.upsert(spec(7, 0))
        now = at(2026, 10, 12, 7, 0)
        lifecycle.onFired(1)
        lifecycle.snooze(1, 9)
        now = at(2026, 10, 12, 7, 30)
        lifecycle.rescheduleAll()
        assertEquals("cancel:1", sched.calls.last())
    }

    @Test fun rescheduleAll_schedulesEnabledAlarms() {
        repo.put(spec(7, 0))
        lifecycle.rescheduleAll()
        assertEquals(ms(at(2026, 10, 12, 7, 0)), sched.scheduled[1])
    }

    @Test fun rescheduleAll_oneFailureDoesNotDropOthers() {
        repo.put(spec(7, 0))
        repo.put(spec(8, 0).copy(id = 2))
        val throwing = object : AlarmClockScheduler {
            override fun schedule(id: Int, triggerAtMs: Long) {
                if (id == 1) throw SecurityException("exact alarms revoked")
                sched.schedule(id, triggerAtMs)
            }
            override fun cancel(id: Int) = sched.cancel(id)
        }
        AlarmLifecycle(repo, throwing) { now }.rescheduleAll()
        assertEquals(ms(at(2026, 10, 12, 8, 0)), sched.scheduled[2])
    }

    @Test fun snoozeAll_snoozesEveryRingingAlarm() {
        lifecycle.upsert(spec(7, 0, (1..7).toSet()))
        lifecycle.upsert(spec(7, 0, (1..7).toSet()).copy(id = 2))
        now = at(2026, 10, 12, 7, 0)
        lifecycle.onFired(1)
        lifecycle.onFired(2)
        val at = lifecycle.snoozeAll(listOf(1, 2), 9)
        assertEquals(ms(at(2026, 10, 12, 7, 9)), at)
        assertEquals(at, sched.scheduled[1])
        assertEquals(at, sched.scheduled[2])
    }

    // 2026-10-12 is a Monday (ISO 1).
    @Test fun skipNext_repeating_skipsExactlyOneRing() {
        lifecycle.upsert(spec(7, 0, days = setOf(1, 2, 3)))
        lifecycle.skipNext(1)
        assertEquals(ms(at(2026, 10, 13, 7, 0)), sched.scheduled[1])
        assertEquals(ms(at(2026, 10, 12, 7, 0)), repo.get(1)!!.skipUntilMs)
    }

    @Test fun skipNext_oneShot_disables() {
        lifecycle.upsert(spec(7, 0))
        lifecycle.skipNext(1)
        assertFalse(repo.get(1)!!.enabled)
        assertEquals("cancel:1", sched.calls.last())
    }

    @Test fun skipNext_survivesReschedule() {
        lifecycle.upsert(spec(7, 0, days = setOf(1, 2, 3)))
        lifecycle.skipNext(1)
        sched.scheduled.clear()
        lifecycle.rescheduleAll()
        assertEquals(ms(at(2026, 10, 13, 7, 0)), sched.scheduled[1])
    }

    @Test fun skipNext_isClearedByUpsertAndFiring() {
        lifecycle.upsert(spec(7, 0, days = setOf(1, 2, 3)))
        lifecycle.skipNext(1)
        lifecycle.upsert(spec(7, 0, days = setOf(1, 2, 3)))
        assertNull(repo.get(1)!!.skipUntilMs)
        assertEquals(ms(at(2026, 10, 12, 7, 0)), sched.scheduled[1])
        lifecycle.skipNext(1)
        now = at(2026, 10, 13, 7, 0)
        lifecycle.onFired(1)
        assertNull(repo.get(1)!!.skipUntilMs)
    }

    @Test fun atMs_ringsAtThatExactInstant() {
        val tomorrow = ms(at(2026, 10, 13, 7, 5))
        assertEquals(tomorrow, lifecycle.upsert(spec(7, 5).copy(atMs = tomorrow)))
        assertEquals(tomorrow, sched.scheduled[1])
    }

    @Test fun atMs_inThePast_doesNotRingAtAll() {
        val earlier = ms(at(2026, 10, 12, 5, 40))
        assertNull(lifecycle.upsert(spec(5, 40).copy(atMs = earlier)))
        assertFalse(repo.get(1)!!.enabled)
        assertEquals("cancel:1", sched.calls.last())
    }

    @Test fun atMs_survivesReschedule() {
        val tomorrow = ms(at(2026, 10, 13, 7, 5))
        lifecycle.upsert(spec(7, 5).copy(atMs = tomorrow))
        sched.scheduled.clear()
        lifecycle.rescheduleAll()
        assertEquals(tomorrow, sched.scheduled[1])
    }
}
