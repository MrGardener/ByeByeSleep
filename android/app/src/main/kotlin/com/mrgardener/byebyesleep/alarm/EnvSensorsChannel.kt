package com.mrgardener.byebyesleep.alarm

import android.content.Context
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

/**
 * Native side of lib/challenges/core/env_sensors.dart: ambient light (lux) and
 * the step detector (one event per step, carrying its timestamp in ns).
 */
object EnvSensorsChannel {
    fun register(messenger: BinaryMessenger, context: Context) {
        val sensors = context.getSystemService(SensorManager::class.java)
        val light = sensors.getDefaultSensor(Sensor.TYPE_LIGHT)
        val steps = sensors.getDefaultSensor(Sensor.TYPE_STEP_DETECTOR)

        MethodChannel(messenger, "byebyesleep/sensors").setMethodCallHandler { call, result ->
            when (call.method) {
                "available" -> result.success(
                    listOfNotNull(light?.let { "light" }, steps?.let { "stepDetector" }),
                )
                else -> result.notImplemented()
            }
        }
        EventChannel(messenger, "byebyesleep/light").setStreamHandler(
            SensorStream(sensors, light, SensorManager.SENSOR_DELAY_NORMAL) { it.values[0].toDouble() },
        )
        EventChannel(messenger, "byebyesleep/steps").setStreamHandler(
            SensorStream(sensors, steps, SensorManager.SENSOR_DELAY_FASTEST) { it.timestamp },
        )
    }

    private class SensorStream(
        private val sensors: SensorManager,
        private val sensor: Sensor?,
        private val delay: Int,
        private val value: (SensorEvent) -> Any,
    ) : EventChannel.StreamHandler {
        private var listener: SensorEventListener? = null

        override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
            if (sensor == null) {
                events.endOfStream()
                return
            }
            listener = object : SensorEventListener {
                override fun onSensorChanged(event: SensorEvent) = events.success(value(event))
                override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) = Unit
            }.also { sensors.registerListener(it, sensor, delay) }
        }

        override fun onCancel(arguments: Any?) {
            listener?.let { sensors.unregisterListener(it) }
            listener = null
        }
    }
}
