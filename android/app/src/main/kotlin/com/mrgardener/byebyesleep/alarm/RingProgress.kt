package com.mrgardener.byebyesleep.alarm

import org.json.JSONObject

/** How far the user got through a ringing alarm's stages (survives ring-screen recreation). */
data class RingProgress(val alarmId: Int, val stageIndex: Int, val startedAtMs: Long) {
    fun toJson(): JSONObject = JSONObject()
        .put("alarmId", alarmId)
        .put("stageIndex", stageIndex)
        .put("startedAtMs", startedAtMs)

    fun toChannelMap(): Map<String, Any> =
        mapOf("alarmId" to alarmId, "stageIndex" to stageIndex, "startedAtMs" to startedAtMs)

    companion object {
        fun fromJson(o: JSONObject) =
            RingProgress(o.getInt("alarmId"), o.getInt("stageIndex"), o.getLong("startedAtMs"))

        fun fromChannelMap(m: Map<*, *>) = RingProgress(
            (m["alarmId"] as Number).toInt(),
            (m["stageIndex"] as Number).toInt(),
            (m["startedAtMs"] as Number).toLong(),
        )
    }
}
