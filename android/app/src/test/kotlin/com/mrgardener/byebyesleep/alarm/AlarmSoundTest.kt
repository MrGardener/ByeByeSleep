package com.mrgardener.byebyesleep.alarm

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class AlarmSoundTest {
    @Test fun defaults_alarmSoundFullVolumeVibrate() {
        val s = AlarmSound.parse("")
        assertNull(s.uri)
        assertEquals(0, s.rampSeconds)
        assertTrue(s.vibrate)
        assertEquals(s, AlarmSound.parse("not json"))
    }

    @Test fun parse_readsTheAlarmsChoice() {
        val s = AlarmSound.parse("""{"sound":"content://media/internal/audio/media/12","ramp":60,"vibrate":false}""")
        assertEquals("content://media/internal/audio/media/12", s.uri)
        assertEquals(60, s.rampSeconds)
        assertFalse(s.vibrate)
    }

    @Test fun ramp_isClampedTo10Minutes() {
        assertEquals(600, AlarmSound.parse("""{"ramp":9999}""").rampSeconds)
        assertEquals(0, AlarmSound.parse("""{"ramp":-5}""").rampSeconds)
    }

    @Test fun rampFactor_startsSoftAndReachesFullVolume() {
        assertEquals(1f, AlarmSound.rampFactor(0, 0), 0.001f)
        assertEquals(AlarmSound.RAMP_START, AlarmSound.rampFactor(0, 60), 0.001f)
        val half = AlarmSound.rampFactor(30_000, 60)
        assertTrue(half > AlarmSound.RAMP_START && half < 1f)
        assertEquals(1f, AlarmSound.rampFactor(60_000, 60), 0.001f)
        assertEquals(1f, AlarmSound.rampFactor(600_000, 60), 0.001f)
    }
}
