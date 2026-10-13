package com.mrgardener.byebyesleep.alarm

import org.json.JSONObject

/**
 * How far the user got through a ringing alarm's stages (survives ring-screen
 * recreation). [followUp]: this ring is the "check I'm awake" ring after a Stop.
 */
data class RingProgress(
    val alarmId: Int,
    val stageIndex: Int,
    val startedAtMs: Long,
    val followUp: Boolean = false,
) {
    fun toJson(): JSONObject = JSONObject()
        .put("alarmId", alarmId)
        .put("stageIndex", stageIndex)
        .put("startedAtMs", startedAtMs)
        .put("followUp", followUp)

    fun toChannelMap(): Map<String, Any> =
        mapOf("alarmId" to alarmId, "stageIndex" to stageIndex, "startedAtMs" to startedAtMs, "followUp" to followUp)

    companion object {
        /** Progress older than this belongs to a ring that ended uncleanly. */
        const val MAX_AGE_MS = 30 * 60_000L

        /**
         * Progress to keep when a ring starts: only a redelivered ring (process
         * restarted mid-ring) continues; any new ring starts at stage 0.
         */
        fun onRing(
            stored: RingProgress?,
            alarmId: Int,
            nowMs: Long,
            redelivered: Boolean,
            followUp: Boolean = false,
        ): RingProgress =
            if (redelivered && stored != null && stored.alarmId == alarmId) stored
            else RingProgress(alarmId, 0, nowMs, followUp)

        /** Stored progress if an alarm is ringing and it is not stale. */
        fun current(stored: RingProgress?, nowMs: Long, ringing: Boolean): RingProgress? =
            stored?.takeIf { ringing && nowMs - it.startedAtMs <= MAX_AGE_MS }

        fun fromJson(o: JSONObject) = RingProgress(
            o.getInt("alarmId"),
            o.getInt("stageIndex"),
            o.getLong("startedAtMs"),
            o.optBoolean("followUp", false),
        )

        fun fromChannelMap(m: Map<*, *>) = RingProgress(
            (m["alarmId"] as Number).toInt(),
            (m["stageIndex"] as Number).toInt(),
            (m["startedAtMs"] as Number).toLong(),
            m["followUp"] as? Boolean ?: false,
        )
    }
}
