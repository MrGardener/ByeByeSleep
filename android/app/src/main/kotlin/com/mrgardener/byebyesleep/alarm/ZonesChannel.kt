package com.mrgardener.byebyesleep.alarm

import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/** Native side of `byebyesleep/zones` (lib/tools/world_clock.dart). */
object ZonesChannel {
    fun register(messenger: BinaryMessenger) {
        MethodChannel(messenger, "byebyesleep/zones").setMethodCallHandler { call, result ->
            if (call.method == "all") {
                return@setMethodCallHandler result.success(java.time.ZoneId.getAvailableZoneIds().sorted())
            }
            if (call.method != "offsets") return@setMethodCallHandler result.notImplemented()
            val zones = call.argument<List<String>>("zones").orEmpty()
            val atMs = call.argument<Number>("atMs")?.toLong() ?: System.currentTimeMillis()
            result.success(ZoneOffsets.offsets(zones, atMs))
        }
    }
}
