package com.mrgardener.byebyesleep.wear

import android.Manifest
import android.app.Activity
import android.content.pm.PackageManager
import android.graphics.Color
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.util.TypedValue
import android.view.Gravity
import android.view.WindowManager
import android.widget.LinearLayout
import android.widget.TextView
import com.google.android.gms.wearable.MessageClient
import com.google.android.gms.wearable.Wearable
import kotlin.math.roundToInt

/**
 * Shows the heart rate and sends each reading (at most one per second) to the
 * phone. The phone opens this screen when its heart-rate challenge starts and
 * closes it with [WatchProtocol.PATH_STOP]. The screen stays on meanwhile,
 * because Android stops sensor readings for apps in the background.
 */
class HeartRateActivity : Activity(), SensorEventListener {
    private val main = Handler(Looper.getMainLooper())
    private lateinit var bpmText: TextView
    private lateinit var hintText: TextView
    private var phones: List<String> = emptyList()
    private var lastSentMs = 0L
    private var sensors: SensorManager? = null

    private val stop = MessageClient.OnMessageReceivedListener {
        if (it.path == WatchProtocol.PATH_STOP) main.post { finish() }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        bpmText = TextView(this).apply {
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 40f)
            setTextColor(Color.WHITE)
            gravity = Gravity.CENTER
            text = "…"
        }
        hintText = TextView(this).apply {
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 14f)
            gravity = Gravity.CENTER
            text = "Heart rate for ByeByeSleep"
        }
        setContentView(
            LinearLayout(this).apply {
                orientation = LinearLayout.VERTICAL
                gravity = Gravity.CENTER
                setBackgroundColor(Color.BLACK)
                addView(bpmText)
                addView(hintText)
            },
        )
        Wearable.getNodeClient(this).connectedNodes
            .addOnSuccessListener { nodes -> phones = nodes.map { it.id } }
        Wearable.getMessageClient(this).addListener(stop)
        // Never measure for ever if the phone does not say stop.
        main.postDelayed({ finish() }, 15 * 60 * 1000L)

        if (checkSelfPermission(Manifest.permission.BODY_SENSORS) == PackageManager.PERMISSION_GRANTED) {
            startSensor()
        } else {
            requestPermissions(arrayOf(Manifest.permission.BODY_SENSORS), REQUEST_SENSORS)
        }
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != REQUEST_SENSORS) return
        if (grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED) {
            startSensor()
        } else {
            hintText.text = "Allow body sensors for ByeByeSleep in the watch settings"
        }
    }

    private fun startSensor() {
        val manager = getSystemService(SensorManager::class.java)
        val heart = manager?.getDefaultSensor(Sensor.TYPE_HEART_RATE)
        if (heart == null) {
            hintText.text = "This watch has no heart-rate sensor"
            return
        }
        sensors = manager
        manager.registerListener(this, heart, SensorManager.SENSOR_DELAY_NORMAL)
    }

    override fun onSensorChanged(event: SensorEvent) {
        val bpm = event.values.firstOrNull()?.roundToInt() ?: return
        if (bpm <= 0 || event.accuracy <= SensorManager.SENSOR_STATUS_UNRELIABLE) {
            hintText.text = "Wear the watch snugly"
            return
        }
        bpmText.text = "$bpm bpm"
        hintText.text = "Sending to your phone"
        val now = SystemClock.elapsedRealtime()
        if (now - lastSentMs < 1000) return
        lastSentMs = now
        val client = Wearable.getMessageClient(this)
        for (phone in phones) {
            client.sendMessage(phone, WatchProtocol.PATH_BPM, WatchProtocol.encodeBpm(bpm))
        }
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) = Unit

    override fun onDestroy() {
        sensors?.unregisterListener(this)
        Wearable.getMessageClient(this).removeListener(stop)
        main.removeCallbacksAndMessages(null)
        super.onDestroy()
    }

    private companion object {
        const val REQUEST_SENSORS = 1
    }
}
