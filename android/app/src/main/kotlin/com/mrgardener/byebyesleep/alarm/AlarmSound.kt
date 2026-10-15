package com.mrgardener.byebyesleep.alarm

import org.json.JSONObject

/**
 * The alarm's sound settings from its Dart extras: "sound" (a content URI of
 * a phone sound; none = the default alarm sound), "ramp" (seconds to rise
 * from soft to full volume; 0 = full at once) and "vibrate". Pure, JVM-tested.
 */
object AlarmSound {
    data class Settings(val uri: String?, val rampSeconds: Int, val vibrate: Boolean)

    /** Where a gradual alarm starts, as a fraction of full volume. */
    const val RAMP_START = 0.1f

    fun parse(extrasJson: String): Settings = runCatching {
        val o = JSONObject(extrasJson)
        Settings(
            uri = o.optString("sound").ifEmpty { null },
            rampSeconds = o.optInt("ramp", 0).coerceIn(0, 600),
            vibrate = o.optBoolean("vibrate", true),
        )
    }.getOrDefault(Settings(null, 0, true))

    /** Volume factor [elapsedMs] into the ring: from [RAMP_START] up to 1 over the ramp. */
    fun rampFactor(elapsedMs: Long, rampSeconds: Int): Float {
        if (rampSeconds <= 0) return 1f
        val t = (elapsedMs / (rampSeconds * 1000f)).coerceIn(0f, 1f)
        return RAMP_START + (1f - RAMP_START) * t
    }
}
