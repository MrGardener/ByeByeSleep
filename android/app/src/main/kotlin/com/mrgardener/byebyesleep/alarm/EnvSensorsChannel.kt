package com.mrgardener.byebyesleep.alarm

import android.Manifest
import android.app.Activity
import android.content.pm.PackageManager
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

/**
 * Native side of lib/challenges/core/env_sensors.dart: ambient light (lux),
 * the step detector (one event per step, carrying its timestamp in ns), air
 * pressure (hPa), proximity (true while covered), and the
 * "physical activity" permission the step detector needs. One instance per
 * activity, which forwards onRequestPermissionsResult here.
 */
class EnvSensorsChannel(private val activity: Activity) {
    private var pendingPermission: MethodChannel.Result? = null

    fun register(messenger: BinaryMessenger) {
        val sensors = activity.getSystemService(SensorManager::class.java)
        val light = sensors.getDefaultSensor(Sensor.TYPE_LIGHT)
        val steps = sensors.getDefaultSensor(Sensor.TYPE_STEP_DETECTOR)
        val pressure = sensors.getDefaultSensor(Sensor.TYPE_PRESSURE)
        val proximity = sensors.getDefaultSensor(Sensor.TYPE_PROXIMITY)

        MethodChannel(messenger, "byebyesleep/sensors").setMethodCallHandler { call, result ->
            when (call.method) {
                "available" -> result.success(
                    listOfNotNull(
                        light?.let { "light" },
                        steps?.let { "stepDetector" },
                        pressure?.let { "barometer" },
                        proximity?.let { "proximity" },
                    ),
                )
                "requestActivityPermission" -> requestActivityPermission(result)
                else -> result.notImplemented()
            }
        }
        EventChannel(messenger, "byebyesleep/light").setStreamHandler(
            SensorStream(sensors, light, SensorManager.SENSOR_DELAY_NORMAL) { it.values[0].toDouble() },
        )
        EventChannel(messenger, "byebyesleep/steps").setStreamHandler(
            SensorStream(sensors, steps, SensorManager.SENSOR_DELAY_FASTEST) { it.timestamp },
        )
        EventChannel(messenger, "byebyesleep/pressure").setStreamHandler(
            SensorStream(sensors, pressure, SensorManager.SENSOR_DELAY_UI) { it.values[0].toDouble() },
        )
        // Many phones (Pixel included) only report 0 or maximumRange: near or far.
        EventChannel(messenger, "byebyesleep/proximity").setStreamHandler(
            SensorStream(sensors, proximity, SensorManager.SENSOR_DELAY_NORMAL) {
                it.values[0] < it.sensor.maximumRange
            },
        )
    }

    private fun requestActivityPermission(result: MethodChannel.Result) {
        val permission = Manifest.permission.ACTIVITY_RECOGNITION
        if (activity.checkSelfPermission(permission) == PackageManager.PERMISSION_GRANTED) {
            result.success(true)
            return
        }
        pendingPermission?.success(false)
        pendingPermission = result
        activity.requestPermissions(arrayOf(permission), REQUEST_CODE)
    }

    /** Call from the activity's onRequestPermissionsResult. */
    fun onPermissionResult(requestCode: Int, grantResults: IntArray) {
        if (requestCode != REQUEST_CODE) return
        pendingPermission?.success(grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED)
        pendingPermission = null
    }

    private companion object {
        const val REQUEST_CODE = 4711
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
