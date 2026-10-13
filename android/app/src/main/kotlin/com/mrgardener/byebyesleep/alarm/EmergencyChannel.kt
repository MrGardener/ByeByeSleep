package com.mrgardener.byebyesleep.alarm

import android.bluetooth.BluetoothManager
import android.content.Context
import android.net.wifi.WifiManager
import android.provider.Settings
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

/**
 * Native side of lib/ringing/emergency.dart: the emergency protocol watches
 * volume key presses on the ring screen (forwarded by RingActivity) and the
 * Wi-Fi, Bluetooth and airplane-mode switches.
 */
class EmergencyChannel(private val context: Context) {
    private var keys: EventChannel.EventSink? = null

    fun register(messenger: BinaryMessenger) {
        MethodChannel(messenger, "byebyesleep/emergency").setMethodCallHandler { call, result ->
            when (call.method) {
                "radios" -> result.success(radios())
                else -> result.notImplemented()
            }
        }
        EventChannel(messenger, "byebyesleep/volume_keys").setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
                    keys = events
                }

                override fun onCancel(arguments: Any?) {
                    keys = null
                }
            },
        )
    }

    fun volumeKeyPressed() {
        keys?.success(true)
    }

    private fun radios(): Map<String, Boolean> {
        // A phone without the radio, or one that refuses to say, counts as off.
        val wifi = runCatching {
            context.getSystemService(WifiManager::class.java)?.isWifiEnabled
        }.getOrNull() ?: false
        val bluetooth = runCatching {
            context.getSystemService(BluetoothManager::class.java)?.adapter?.isEnabled
        }.getOrNull() ?: false
        val airplane = Settings.Global.getInt(context.contentResolver, Settings.Global.AIRPLANE_MODE_ON, 0) != 0
        return mapOf("wifi" to wifi, "bluetooth" to bluetooth, "airplane" to airplane)
    }
}
