package com.mrgardener.byebyesleep.wear

/**
 * Messages between the phone and the ByeByeSleep watch app (android/app keeps
 * an identical copy). Pure, JVM-tested.
 */
object WatchProtocol {
    /** Declared by the watch app (res/values/wear.xml). */
    const val CAPABILITY = "byebyesleep_heart_rate"

    /** Opens the watch app's heart-rate screen. */
    const val START_URI = "byebyesleep://heart-rate"

    /** Watch → phone: one heart-rate reading, as decimal text. */
    const val PATH_BPM = "/hr/bpm"

    /** Phone → watch: close the heart-rate screen. */
    const val PATH_STOP = "/hr/stop"

    fun encodeBpm(bpm: Int): ByteArray = bpm.toString().toByteArray(Charsets.UTF_8)

    fun decodeBpm(data: ByteArray): Int? =
        String(data, Charsets.UTF_8).trim().toIntOrNull()?.takeIf { it in 1..300 }
}
