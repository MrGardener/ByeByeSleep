package com.mrgardener.byebyesleep.alarm

import org.json.JSONArray
import org.json.JSONObject

/**
 * A stored alarm. Weekdays are ISO-8601 (1 = Monday … 7 = Sunday); empty = one-shot.
 * [snoozeUntilMs] is native-only state so a snooze survives a reboot.
 * [stagesJson] is the Dart stage list, stored and passed through untouched.
 */
data class AlarmSpec(
    val id: Int,
    val hour: Int,
    val minute: Int,
    val repeatDays: Set<Int>,
    val label: String,
    val enabled: Boolean,
    val snoozeUntilMs: Long? = null,
    val stagesJson: String = "",
) {
    fun toJson(): JSONObject = JSONObject()
        .put("id", id)
        .put("hour", hour)
        .put("minute", minute)
        .put("repeatDays", JSONArray(repeatDays.sorted()))
        .put("label", label)
        .put("enabled", enabled)
        .put("stages", stagesJson)
        .apply { if (snoozeUntilMs != null) put("snoozeUntilMs", snoozeUntilMs) }

    /** Map sent over the `byebyesleep/alarm` channel (keys match Dart's Alarm.toMap). */
    fun toChannelMap(): Map<String, Any?> = mapOf(
        "id" to id,
        "hour" to hour,
        "minute" to minute,
        "repeatDays" to repeatDays.sorted(),
        "label" to label,
        "enabled" to enabled,
        "stages" to stagesJson,
    )

    companion object {
        fun fromJson(o: JSONObject): AlarmSpec {
            val days = o.getJSONArray("repeatDays")
            return AlarmSpec(
                id = o.getInt("id"),
                hour = o.getInt("hour"),
                minute = o.getInt("minute"),
                repeatDays = (0 until days.length()).map { days.getInt(it) }.toSet(),
                label = o.optString("label", ""),
                enabled = o.optBoolean("enabled", true),
                snoozeUntilMs = if (o.has("snoozeUntilMs")) o.getLong("snoozeUntilMs") else null,
                stagesJson = o.optString("stages", ""),
            )
        }

        fun fromChannelMap(m: Map<*, *>): AlarmSpec = AlarmSpec(
            id = (m["id"] as Number).toInt(),
            hour = (m["hour"] as Number).toInt(),
            minute = (m["minute"] as Number).toInt(),
            repeatDays = (m["repeatDays"] as? List<*>).orEmpty().map { (it as Number).toInt() }.toSet(),
            label = m["label"] as? String ?: "",
            enabled = m["enabled"] as? Boolean ?: true,
            stagesJson = m["stages"] as? String ?: "",
        )
    }
}
