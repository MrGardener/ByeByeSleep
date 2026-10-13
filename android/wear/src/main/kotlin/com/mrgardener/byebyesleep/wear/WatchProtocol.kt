package com.mrgardener.byebyesleep.wear

import java.util.Locale

/**
 * Messages between the phone and the ByeByeSleep watch app (android/app keeps
 * an identical copy). Pure, JVM-tested.
 */
object WatchProtocol {
    /** Declared by the watch app (res/values/wear.xml). */
    const val CAPABILITY = "byebyesleep_heart_rate"

    /** Opens the watch app's sensor screen. */
    const val START_URI = "byebyesleep://heart-rate"

    /** Watch → phone: one heart-rate reading, as decimal text. */
    const val PATH_BPM = "/hr/bpm"

    /** Watch → phone: wrist acceleration (gravity removed, m/s², ~10 Hz), comma-separated. */
    const val PATH_MOTION = "/motion/batch"

    /** Watch → phone: steps counted since the sensor screen opened. */
    const val PATH_STEPS = "/steps/count"

    /** Phone → watch: close the sensor screen. */
    const val PATH_STOP = "/hr/stop"

    fun encodeBpm(bpm: Int): ByteArray = bpm.toString().toByteArray(Charsets.UTF_8)

    fun decodeBpm(data: ByteArray): Int? =
        String(data, Charsets.UTF_8).trim().toIntOrNull()?.takeIf { it in 1..300 }

    fun encodeMotion(values: List<Double>): ByteArray =
        values.joinToString(",") { String.format(Locale.ROOT, "%.1f", it) }.toByteArray(Charsets.UTF_8)

    fun decodeMotion(data: ByteArray): List<Double> =
        String(data, Charsets.UTF_8).split(',').mapNotNull { it.trim().toDoubleOrNull() }

    fun encodeCount(count: Int): ByteArray = count.toString().toByteArray(Charsets.UTF_8)

    fun decodeCount(data: ByteArray): Int? =
        String(data, Charsets.UTF_8).trim().toIntOrNull()?.takeIf { it >= 0 }

    /** The event sent to Dart (lib/challenges/core/watch.dart), or null. */
    fun toEvent(path: String, data: ByteArray): Map<String, Any>? = when (path) {
        PATH_BPM -> decodeBpm(data)?.let { mapOf("type" to "hr", "value" to it) }
        PATH_STEPS -> decodeCount(data)?.let { mapOf("type" to "steps", "value" to it) }
        PATH_MOTION -> decodeMotion(data).takeIf { it.isNotEmpty() }?.let { mapOf("type" to "motion", "value" to it) }
        else -> null
    }
}
