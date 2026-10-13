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
}
