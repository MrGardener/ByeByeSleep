package com.mrgardener.byebyesleep.alarm

import org.json.JSONArray
import org.json.JSONObject

/**
 * A stored alarm. Weekdays are ISO-8601 (1 = Monday … 7 = Sunday); empty = one-shot.
 * [snoozeUntilMs] is native-only state so a snooze survives a reboot.
 * [stagesJson] is the Dart stage list, stored and passed through untouched.
 * [pauseSeconds] is the quieter pause between stages (0 = none), used by Dart.
 * [extrasJson] holds Dart-only options (reminder, series), passed through untouched.
 * [skipUntilMs] is native-only: the ring at that instant is skipped ("skip the rest
 * of the series today"), surviving a reboot.
 * [atMs] pins a one-shot alarm (one of a series) to an exact instant, date included.
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
    val pauseSeconds: Int = 0,
    val extrasJson: String = "",
    val skipUntilMs: Long? = null,
    val atMs: Long? = null,
) {
    fun toJson(): JSONObject = JSONObject()
        .put("id", id)
        .put("hour", hour)
        .put("minute", minute)
        .put("repeatDays", JSONArray(repeatDays.sorted()))
        .put("label", label)
        .put("enabled", enabled)
        .put("stages", stagesJson)
        .put("pauseSeconds", pauseSeconds)
        .put("extras", extrasJson)
        .apply { if (skipUntilMs != null) put("skipUntilMs", skipUntilMs) }
        .apply { if (atMs != null) put("atMs", atMs) }
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
        "pauseSeconds" to pauseSeconds,
        "extras" to extrasJson,
    ) + (if (atMs != null) mapOf("atMs" to atMs) else emptyMap())

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
                pauseSeconds = o.optInt("pauseSeconds", 0),
                extrasJson = o.optString("extras", ""),
                skipUntilMs = if (o.has("skipUntilMs")) o.getLong("skipUntilMs") else null,
                atMs = if (o.has("atMs")) o.getLong("atMs") else null,
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
            pauseSeconds = (m["pauseSeconds"] as? Number)?.toInt() ?: 0,
            extrasJson = m["extras"] as? String ?: "",
            atMs = (m["atMs"] as? Number)?.toLong(),
        )
    }
}
