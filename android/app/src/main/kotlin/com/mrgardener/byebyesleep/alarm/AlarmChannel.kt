package com.mrgardener.byebyesleep.alarm

import android.app.Activity
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/** Native side of the `byebyesleep/alarm` channel (see lib/alarm/alarm_platform.dart). */
object AlarmChannel {
    fun register(messenger: BinaryMessenger, activity: Activity) {
        val lifecycle = AlarmGraph.lifecycle(activity)
        val repo = PrefsAlarmRepository(activity.applicationContext)
        MethodChannel(messenger, "byebyesleep/alarm").setMethodCallHandler { call, result ->
            runCatching {
                when (call.method) {
                    "list" -> result.success(repo.all().map { it.toChannelMap() })
                    "upsert" -> result.success(
                        lifecycle.upsert(AlarmSpec.fromChannelMap(call.arguments as Map<*, *>)),
                    )
                    "delete" -> {
                        lifecycle.delete(call.argument<Number>("id")!!.toInt())
                        result.success(null)
                    }
                    "stopRinging" -> {
                        AlarmService.stop(activity)
                        result.success(null)
                    }
                    "snooze" -> result.success(
                        lifecycle.snooze(
                            call.argument<Number>("id")!!.toInt(),
                            call.argument<Number>("minutes")!!.toInt(),
                        ),
                    )
                    "permissions" -> result.success(Permissions.status(activity))
                    "openSettings" -> {
                        Permissions.openSettings(activity, call.argument<String>("kind")!!)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }.onFailure { result.error("alarm_error", it.message, null) }
        }
    }
}
