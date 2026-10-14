package com.mrgardener.byebyesleep.alarm

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class RingStartTest {
    @Test fun screenOpensByItself_withOverlayPermission_evenWhileInUse() {
        assertTrue(RingStart.canOpenScreen(canDrawOverlays = true, interactive = true, keyguardLocked = false))
    }

    @Test fun screenOpensByItself_whenLockedOrOff() {
        assertTrue(RingStart.canOpenScreen(canDrawOverlays = false, interactive = false, keyguardLocked = false))
        assertTrue(RingStart.canOpenScreen(canDrawOverlays = false, interactive = true, keyguardLocked = true))
    }

    @Test fun inUseWithoutOverlay_onlyANotification() {
        assertFalse(RingStart.canOpenScreen(canDrawOverlays = false, interactive = true, keyguardLocked = false))
    }

    @Test fun soundWaitsForTheScreen_onlyWhenItWillOpen() {
        assertEquals(RingStart.SCREEN_WAIT_MS, RingStart.soundDelayMs(canOpenScreen = true, userUnlocked = true, redelivered = false))
        // No screen coming: ring at once.
        assertEquals(0L, RingStart.soundDelayMs(canOpenScreen = false, userUnlocked = true, redelivered = false))
        // Before the first unlock the Flutter screen cannot start.
        assertEquals(0L, RingStart.soundDelayMs(canOpenScreen = true, userUnlocked = false, redelivered = false))
        // Restarted while ringing: it was already ringing, keep ringing.
        assertEquals(0L, RingStart.soundDelayMs(canOpenScreen = true, userUnlocked = true, redelivered = true))
    }

    @Test fun waitIsShort() {
        assertTrue(RingStart.SCREEN_WAIT_MS <= 5_000L)
    }
}
