package com.mrgardener.byebyesleep.alarm

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Handler
import android.os.Looper
import androidx.wear.remote.interactions.RemoteActivityHelper
import com.google.android.gms.wearable.CapabilityClient
import com.google.android.gms.wearable.MessageClient
import com.google.android.gms.wearable.Node
import com.google.android.gms.wearable.Wearable
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

/**
 * Native side of lib/challenges/core/watch.dart: finds a watch with the
 * ByeByeSleep watch app, opens its sensor screen, and streams its readings
 * (heart rate, wrist motion, steps) to Dart as {type, value} maps.
 * A phone without Google Play services or without a watch simply has none.
 */
class WatchChannel(private val context: Context) {
    private val main = Handler(Looper.getMainLooper())
    private var sink: EventChannel.EventSink? = null
    private val readings = MessageClient.OnMessageReceivedListener { event ->
        val reading = WatchProtocol.toEvent(event.path, event.data) ?: return@OnMessageReceivedListener
        main.post { sink?.success(reading) }
    }

    fun register(messenger: BinaryMessenger) {
        MethodChannel(messenger, "byebyesleep/watch").setMethodCallHandler { call, result ->
            when (call.method) {
                "available" -> watches { result.success(it.isNotEmpty()) }
                "start" -> watches { nodes ->
                    nodes.forEach { open(it.id) }
                    result.success(null)
                }
                "stop" -> watches { nodes ->
                    nodes.forEach {
                        runCatching {
                            Wearable.getMessageClient(context).sendMessage(it.id, WatchProtocol.PATH_STOP, ByteArray(0))
                        }
                    }
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
        EventChannel(messenger, "byebyesleep/watch_readings").setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
                    sink = events
                    runCatching { Wearable.getMessageClient(context).addListener(readings) }
                }

                override fun onCancel(arguments: Any?) {
                    runCatching { Wearable.getMessageClient(context).removeListener(readings) }
                    sink = null
                }
            },
        )
    }

    /** Reachable watches with the watch app installed (none on any failure). */
    private fun watches(done: (Set<Node>) -> Unit) {
        try {
            Wearable.getCapabilityClient(context)
                .getCapability(WatchProtocol.CAPABILITY, CapabilityClient.FILTER_REACHABLE)
                .addOnSuccessListener { done(it.nodes) }
                .addOnFailureListener { done(emptySet()) }
        } catch (e: Exception) {
            done(emptySet())
        }
    }

    private fun open(nodeId: String) {
        val intent = Intent(Intent.ACTION_VIEW)
            .addCategory(Intent.CATEGORY_BROWSABLE)
            .setData(Uri.parse(WatchProtocol.START_URI))
        runCatching { RemoteActivityHelper(context).startRemoteActivity(intent, nodeId) }
    }
}
