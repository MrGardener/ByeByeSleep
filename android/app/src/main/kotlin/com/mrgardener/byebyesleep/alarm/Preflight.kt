package com.mrgardener.byebyesleep.alarm

import java.time.Duration
import java.time.LocalTime
import java.time.ZonedDateTime
import org.json.JSONArray
import org.json.JSONObject

/** Evening check (spec §6.1): will tomorrow's alarms work? Pure, JVM-tested. */
object Preflight {
    /** Challenges that cannot run without setup, and the param key they need. */
    private val requiredParam = mapOf(
        "photoMatch" to ("photos" to "Photo match"),
        "nfcTag" to ("tagId" to "NFC sticker"),
        "barcode" to ("code" to "Barcode"),
    )

    fun problems(specs: List<AlarmSpec>, permissionsOk: Boolean, now: ZonedDateTime): List<String> {
        val problems = mutableListOf<String>()
        if (!permissionsOk) problems += "Some permissions the alarm needs are off."
        // A series shares its main alarm's setup: report it once, for the main alarm.
        val isSeriesChild = { s: AlarmSpec ->
            runCatching { JSONObject(s.extrasJson).has("parent") }.getOrDefault(false)
        }
        for (spec in specs.filter { it.enabled && !isSeriesChild(it) }) {
            if (Duration.between(now, NextTrigger.compute(spec, now)) > Duration.ofHours(24)) continue
            val stages = runCatching { JSONArray(spec.stagesJson) }.getOrNull() ?: continue
            for (i in 0 until stages.length()) {
                val stage = stages.optJSONObject(i) ?: continue
                val (key, title) = requiredParam[stage.optString("challenge")] ?: continue
                if (stage.optJSONObject("params")?.has(key) != true) {
                    problems += "The %02d:%02d alarm: %s needs setup.".format(spec.hour, spec.minute, title)
                }
            }
        }
        return problems
    }

    /** The next 21:00 strictly after [now]. */
    fun nextCheck(now: ZonedDateTime): ZonedDateTime {
        val today = ZonedDateTime.of(now.toLocalDate(), LocalTime.of(21, 0), now.zone)
        return if (today.isAfter(now)) today else today.plusDays(1)
    }
}
