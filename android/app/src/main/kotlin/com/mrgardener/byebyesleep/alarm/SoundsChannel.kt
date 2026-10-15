package com.mrgardener.byebyesleep.alarm

import android.content.Context
import android.media.AudioAttributes
import android.media.Ringtone
import android.media.RingtoneManager
import android.net.Uri
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/** The phone's own alarm, ringtone and notification sounds for the alarm editor (offline). */
class SoundsChannel(private val context: Context) {
    private var preview: Ringtone? = null

    fun register(messenger: BinaryMessenger) {
        MethodChannel(messenger, "byebyesleep/sounds").setMethodCallHandler { call, result ->
            runCatching {
                when (call.method) {
                    "list" -> result.success(list())
                    "preview" -> {
                        play(call.argument<String>("uri"))
                        result.success(null)
                    }
                    "stopPreview" -> {
                        stop()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }.onFailure { result.error("sounds_error", it.message, null) }
        }
    }

    private fun list(): List<Map<String, String>> {
        val out = mutableListOf<Map<String, String>>()
        val seen = mutableSetOf<String>()
        for ((type, kind) in listOf(
            RingtoneManager.TYPE_ALARM to "Alarm",
            RingtoneManager.TYPE_RINGTONE to "Ringtone",
            RingtoneManager.TYPE_NOTIFICATION to "Notification",
        )) {
            val manager = RingtoneManager(context).apply { setType(type) }
            val cursor = runCatching { manager.cursor }.getOrNull() ?: continue
            while (cursor.moveToNext()) {
                val title = cursor.getString(RingtoneManager.TITLE_COLUMN_INDEX) ?: continue
                val uri = manager.getRingtoneUri(cursor.position)?.toString() ?: continue
                if (seen.add(uri)) out += mapOf("uri" to uri, "title" to title, "kind" to kind)
            }
        }
        return out
    }

    /** Plays a sound briefly at alarm volume; null = the default alarm sound. */
    private fun play(uri: String?) {
        stop()
        val u = uri?.let(Uri::parse) ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM) ?: return
        preview = RingtoneManager.getRingtone(context, u)?.apply {
            audioAttributes = AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_ALARM).build()
            play()
        }
    }

    fun stop() {
        preview?.stop()
        preview = null
    }
}
