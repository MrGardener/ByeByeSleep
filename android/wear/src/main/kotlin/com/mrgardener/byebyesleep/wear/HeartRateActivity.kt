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
import kotlin.math.abs
import kotlin.math.max
import kotlin.math.roundToInt
import kotlin.math.sqrt

/**
 * The watch's sensor screen for ByeByeSleep challenges. Sends to the phone:
 * heart rate (at most once a second), wrist motion (the strongest movement of
 * every 100 ms, five at a time) and steps since the screen opened. The phone
 * opens this screen when a watch challenge starts and closes it with
 * [WatchProtocol.PATH_STOP]. The screen stays on meanwhile, because Android
 * stops sensor readings for apps in the background. Laid out for round
 * screens (Pixel Watch 3); works on any Wear OS watch.
 */
class HeartRateActivity : Activity(), SensorEventListener {
    private val main = Handler(Looper.getMainLooper())
    private lateinit var bpmText: TextView
    private lateinit var stepsText: TextView
    private lateinit var hintText: TextView
    private var phones: List<String> = emptyList()
    private var sensors: SensorManager? = null
    private var lastBpmSentMs = 0L
    private var steps = 0
    private var windowPeak = 0.0
    private val motion = mutableListOf<Double>()
    private var linear = true

    /** The phone's session that opened this screen (null: opened by hand). */
    private var session: Int? = null
    private var announceSteps = false

    private val stop = MessageClient.OnMessageReceivedListener {
        if (it.path != WatchProtocol.PATH_STOP) return@OnMessageReceivedListener
        val ended = WatchProtocol.decodeCount(it.data)
        main.post { if (WatchProtocol.stopApplies(ended, session)) finish() }
    }

    // Every 100 ms: keep the strongest movement; every 5 of them, send.
    private val sampler = object : Runnable {
        override fun run() {
            if (phones.isEmpty()) {
                windowPeak = 0.0
                main.postDelayed(this, 100)
                return
            }
            motion += windowPeak
            windowPeak = 0.0
            if (motion.size >= 5) {
                send(WatchProtocol.PATH_MOTION, WatchProtocol.encodeMotion(motion.toList()))
                motion.clear()
            }
            main.postDelayed(this, 100)
        }
    }

    private fun text(sizeSp: Float) = TextView(this).apply {
        setTextSize(TypedValue.COMPLEX_UNIT_SP, sizeSp)
        setTextColor(Color.WHITE)
        gravity = Gravity.CENTER
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        session = WatchProtocol.sessionOf(intent?.dataString)
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        bpmText = text(34f).apply { text = "♥ …" }
        stepsText = text(18f).apply { text = "0 steps" }
        hintText = text(13f).apply {
            text = "ByeByeSleep challenge"
            setTextColor(Color.LTGRAY)
        }
        // Round screen: keep the text away from the edge.
        val pad = (resources.displayMetrics.widthPixels * 0.12).roundToInt()
        setContentView(
            LinearLayout(this).apply {
                orientation = LinearLayout.VERTICAL
                gravity = Gravity.CENTER
                setBackgroundColor(Color.BLACK)
                setPadding(pad, pad, pad, pad)
                addView(bpmText)
                addView(stepsText)
                addView(hintText)
            },
        )
        Wearable.getNodeClient(this).connectedNodes
            .addOnSuccessListener { nodes ->
                phones = nodes.map { it.id }
                // Phones may be found after the step sensor started.
                if (announceSteps) send(WatchProtocol.PATH_STEPS, WatchProtocol.encodeCount(steps))
            }
        Wearable.getMessageClient(this).addListener(stop)
        // Never measure for ever if the phone does not say stop.
        main.postDelayed({ finish() }, 15 * 60 * 1000L)

        sensors = getSystemService(SensorManager::class.java)
        startMotion() // needs no permission
        val missing = arrayOf(Manifest.permission.BODY_SENSORS, Manifest.permission.ACTIVITY_RECOGNITION)
            .filter { checkSelfPermission(it) != PackageManager.PERMISSION_GRANTED }
        if (missing.isEmpty()) startGuarded() else requestPermissions(missing.toTypedArray(), REQUEST_SENSORS)
    }

    // The phone started the next watch challenge while this screen is open.
    override fun onNewIntent(intent: android.content.Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        session = WatchProtocol.sessionOf(intent.dataString)
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == REQUEST_SENSORS) startGuarded()
    }

    /** Heart rate and steps, each if its permission was granted. */
    private fun startGuarded() {
        val manager = sensors ?: return
        if (checkSelfPermission(Manifest.permission.BODY_SENSORS) == PackageManager.PERMISSION_GRANTED) {
            val heart = manager.getDefaultSensor(Sensor.TYPE_HEART_RATE)
            if (heart != null) {
                manager.registerListener(this, heart, SensorManager.SENSOR_DELAY_NORMAL)
            } else {
                bpmText.text = "♥ –"
            }
        } else {
            hintText.text = "Allow body sensors for ByeByeSleep in the watch settings"
        }
        if (checkSelfPermission(Manifest.permission.ACTIVITY_RECOGNITION) == PackageManager.PERMISSION_GRANTED) {
            manager.getDefaultSensor(Sensor.TYPE_STEP_DETECTOR)?.let {
                manager.registerListener(this, it, SensorManager.SENSOR_DELAY_FASTEST)
                // Announce 0, so the phone counts from here and knows steps work.
                announceSteps = true
                send(WatchProtocol.PATH_STEPS, WatchProtocol.encodeCount(0))
            }
        }
    }

    private fun startMotion() {
        val manager = sensors ?: return
        val sensor = manager.getDefaultSensor(Sensor.TYPE_LINEAR_ACCELERATION)
            ?: manager.getDefaultSensor(Sensor.TYPE_ACCELEROMETER).also { linear = false }
            ?: return
        manager.registerListener(this, sensor, SensorManager.SENSOR_DELAY_GAME)
        main.postDelayed(sampler, 100)
    }

    override fun onSensorChanged(event: SensorEvent) {
        when (event.sensor.type) {
            Sensor.TYPE_HEART_RATE -> onHeartRate(event)
            Sensor.TYPE_STEP_DETECTOR -> {
                steps++
                stepsText.text = "$steps steps"
                send(WatchProtocol.PATH_STEPS, WatchProtocol.encodeCount(steps))
            }
            Sensor.TYPE_LINEAR_ACCELERATION, Sensor.TYPE_ACCELEROMETER -> {
                val (x, y, z) = Triple(event.values[0], event.values[1], event.values[2])
                val magnitude = sqrt((x * x + y * y + z * z).toDouble())
                // Without a linear-acceleration sensor, remove gravity roughly.
                val moving = if (linear) magnitude else abs(magnitude - SensorManager.GRAVITY_EARTH)
                windowPeak = max(windowPeak, moving)
            }
        }
    }

    private fun onHeartRate(event: SensorEvent) {
        val bpm = event.values.firstOrNull()?.roundToInt() ?: return
        if (bpm <= 0 || event.accuracy <= SensorManager.SENSOR_STATUS_UNRELIABLE) {
            hintText.text = "Wear the watch snugly"
            return
        }
        bpmText.text = "♥ $bpm"
        hintText.text = "Sending to your phone"
        val now = SystemClock.elapsedRealtime()
        if (now - lastBpmSentMs < 1000) return
        lastBpmSentMs = now
        send(WatchProtocol.PATH_BPM, WatchProtocol.encodeBpm(bpm))
    }

    private fun send(path: String, data: ByteArray) {
        val client = Wearable.getMessageClient(this)
        for (phone in phones) client.sendMessage(phone, path, data)
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
