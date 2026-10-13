package com.mrgardener.byebyesleep.alarm

import org.junit.Assert.assertEquals
import org.junit.Test

class PreflightTest {
    private val now = at(2026, 10, 12, 21, 0)
    private val photoNoSetup = """[{"challenge":"stroopTap"},{"challenge":"photoMatch"}]"""
    private val photoSetUp = """[{"challenge":"photoMatch","params":{"photos":["a","b"],"threshold":0.9}}]"""

    @Test fun problems_flagsPhotoWithoutSetup() {
        val spec = spec(7, 0).copy(stagesJson = photoNoSetup)
        assertEquals(listOf("The 07:00 alarm: Photo match needs setup."), Preflight.problems(listOf(spec), true, now))
    }

    @Test fun problems_ignoresAlarmsBeyond24h() {
        val spec = spec(7, 0, setOf(5)).copy(stagesJson = photoNoSetup) // next Friday
        assertEquals(emptyList<String>(), Preflight.problems(listOf(spec), true, now))
    }

    @Test fun problems_ignoresDisabledAlarms() {
        val spec = spec(7, 0, enabled = false).copy(stagesJson = photoNoSetup)
        assertEquals(emptyList<String>(), Preflight.problems(listOf(spec), true, now))
    }

    @Test fun problems_emptyWhenAllGood() {
        val spec = spec(7, 0).copy(stagesJson = photoSetUp)
        assertEquals(emptyList<String>(), Preflight.problems(listOf(spec), true, now))
    }

    @Test fun problems_permissionsOff() {
        assertEquals(
            listOf("Some permissions the alarm needs are off."),
            Preflight.problems(listOf(spec(7, 0)), false, now),
        )
    }

    @Test fun nextCheck_isNext2100() {
        assertEquals(at(2026, 10, 12, 21, 0), Preflight.nextCheck(at(2026, 10, 12, 20, 59)))
        assertEquals(at(2026, 10, 13, 21, 0), Preflight.nextCheck(at(2026, 10, 12, 21, 0)))
    }

    @Test fun problems_reportsASeriesOnceForItsMainAlarm() {
        val main = spec(7, 0).copy(stagesJson = photoNoSetup, extrasJson = """{"series":{"count":3}}""")
        val child = spec(7, 5).copy(id = 101, stagesJson = photoNoSetup, extrasJson = """{"parent":1}""")
        assertEquals(
            listOf("The 07:00 alarm: Photo match needs setup."),
            Preflight.problems(listOf(main, child), true, now),
        )
    }
}
