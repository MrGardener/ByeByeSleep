package com.mrgardener.byebyesleep.alarm

import java.time.ZoneId
import java.time.ZonedDateTime

val zone: ZoneId = ZoneId.of("America/New_York")

fun at(y: Int, mo: Int, d: Int, h: Int, mi: Int): ZonedDateTime =
    ZonedDateTime.of(y, mo, d, h, mi, 0, 0, zone)

fun spec(h: Int, m: Int, days: Set<Int> = emptySet(), enabled: Boolean = true) =
    AlarmSpec(id = 1, hour = h, minute = m, repeatDays = days, label = "", enabled = enabled)

class FakeRepo : AlarmRepository {
    val map = mutableMapOf<Int, AlarmSpec>()
    override fun all() = map.values.toList()
    override fun get(id: Int) = map[id]
    override fun put(spec: AlarmSpec) { map[spec.id] = spec }
    override fun remove(id: Int) { map.remove(id) }
}

class FakeScheduler : AlarmClockScheduler {
    val calls = mutableListOf<String>()
    val scheduled = mutableMapOf<Int, Long>()
    override fun schedule(id: Int, triggerAtMs: Long) {
        calls += "schedule:$id"; scheduled[id] = triggerAtMs
    }
    override fun cancel(id: Int) {
        calls += "cancel:$id"; scheduled.remove(id)
    }
}
