package com.mrgardener.byebyesleep.alarm

/**
 * The ring screen opens first and the sound follows once the challenges are
 * on screen, so you never hunt for a notification while the alarm blares.
 */
object RingStart {
    /** Longest the sound waits for the ring screen: it always rings. */
    const val SCREEN_WAIT_MS = 4_000L

    /**
     * Whether the ring screen opens by itself: with "Display over other apps"
     * it opens even while the phone is in use; otherwise only when locked or
     * the screen is off (Android shows the full-screen intent then).
     */
    fun canOpenScreen(canDrawOverlays: Boolean, interactive: Boolean, keyguardLocked: Boolean): Boolean =
        canDrawOverlays || !interactive || keyguardLocked

    fun soundDelayMs(canOpenScreen: Boolean, userUnlocked: Boolean, redelivered: Boolean): Long =
        if (canOpenScreen && userUnlocked && !redelivered) SCREEN_WAIT_MS else 0L
}
