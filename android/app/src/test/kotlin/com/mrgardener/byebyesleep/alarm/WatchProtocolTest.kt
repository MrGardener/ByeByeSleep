package com.mrgardener.byebyesleep.alarm

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class WatchProtocolTest {
    @Test fun bpm_roundTrips() = assertEquals(72, WatchProtocol.decodeBpm(WatchProtocol.encodeBpm(72)))

    @Test fun bpm_rejectsGarbageAndImpossibleValues() {
        assertNull(WatchProtocol.decodeBpm("x".toByteArray()))
        assertNull(WatchProtocol.decodeBpm("0".toByteArray()))
        assertNull(WatchProtocol.decodeBpm("400".toByteArray()))
    }

    @Test fun motion_roundTripsAtOneDecimal() {
        val back = WatchProtocol.decodeMotion(WatchProtocol.encodeMotion(listOf(0.04, 12.345, 3.0)))
        assertEquals(listOf(0.0, 12.3, 3.0), back)
    }

    @Test fun motion_dropsGarbage() {
        assertEquals(listOf(1.5), WatchProtocol.decodeMotion("x,1.5,".toByteArray()))
    }

    @Test fun steps_roundTrip() {
        assertEquals(42, WatchProtocol.decodeCount(WatchProtocol.encodeCount(42)))
        assertNull(WatchProtocol.decodeCount("-1".toByteArray()))
    }

    @Test fun readings_becomeChannelEvents() {
        assertEquals(mapOf("type" to "hr", "value" to 70), WatchProtocol.toEvent(WatchProtocol.PATH_BPM, "70".toByteArray()))
        assertEquals(mapOf("type" to "steps", "value" to 9), WatchProtocol.toEvent(WatchProtocol.PATH_STEPS, "9".toByteArray()))
        assertEquals(
            mapOf("type" to "motion", "value" to listOf(1.0, 2.5)),
            WatchProtocol.toEvent(WatchProtocol.PATH_MOTION, "1,2.5".toByteArray()),
        )
        assertNull(WatchProtocol.toEvent("/other", ByteArray(0)))
    }

    @Test fun session_travelsInTheStartLinkAndTheStop() {
        val uri = WatchProtocol.startUri(7)
        assertEquals("byebyesleep://heart-rate?s=7", uri)
        assertEquals(7, WatchProtocol.sessionOf(uri))
        assertNull(WatchProtocol.sessionOf("byebyesleep://heart-rate"))
        assertEquals(7, WatchProtocol.decodeCount(WatchProtocol.encodeCount(7)))
    }

    @Test fun stop_onlyForTheCurrentSession() {
        assertEquals(true, WatchProtocol.stopApplies(stopSession = 2, current = 2))
        assertEquals(false, WatchProtocol.stopApplies(stopSession = 1, current = 2))
        // Opened by hand on the watch, or an old phone app: any stop closes it.
        assertEquals(true, WatchProtocol.stopApplies(stopSession = 1, current = null))
        assertEquals(true, WatchProtocol.stopApplies(stopSession = null, current = 2))
    }
}
