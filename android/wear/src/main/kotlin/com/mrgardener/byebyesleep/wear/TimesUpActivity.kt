package com.mrgardener.byebyesleep.wear

import android.app.Activity
import android.graphics.Color
import android.media.AudioAttributes
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.view.Gravity
import android.view.ViewGroup
import android.view.WindowManager
import android.widget.LinearLayout
import java.lang.ref.WeakReference
import kotlin.math.roundToInt

/**
 * "Time's up": opened by the timer notification's full-screen intent, also
 * over the lock screen and with the screen off. Vibrates in a repeating
 * pattern until Stop (or [TimerAlarm.RING_LIMIT_MS]). "+1 min" stops it and
 * starts a one-minute timer.
 */
class TimesUpActivity : Activity() {
    private val main = Handler(Looper.getMainLooper())
    private var vibrator: Vibrator? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        open += WeakReference(this)
        setShowWhenLocked(true)
        setTurnScreenOn(true)
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)

        val label = intent?.getStringExtra(TimerAlarm.EXTRA_LABEL) ?: "Timer"
        val pad = (resources.displayMetrics.widthPixels * 0.14).roundToInt()
        val column = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setBackgroundColor(Color.BLACK)
            setPadding(pad, pad / 2, pad, pad / 2)
        }
        column.addView(WatchUi.text(this, 28f, WatchUi.AMBER).apply { text = "Time's up" })
        column.addView(
            WatchUi.text(this, 14f, WatchUi.SECONDARY).apply { text = label },
            WatchUi.matchWidth(this, 4f),
        )
        column.addView(
            WatchUi.pill(this, "Stop", WatchUi.CORAL, filled = true) { stop() },
            WatchUi.matchWidth(this, 14f),
        )
        column.addView(
            WatchUi.pill(this, "+1 min", WatchUi.SECONDARY, filled = false) {
                val now = System.currentTimeMillis()
                TimerAlarm.apply(this, TimerLogic.start(TimerState(durationMs = TimerLogic.MINUTE), now))
                stop()
            },
            WatchUi.matchWidth(this, 8f),
        )
        setContentView(column, ViewGroup.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT))

        vibrate()
        main.postDelayed({ stop() }, TimerAlarm.RING_LIMIT_MS)
    }

    @Suppress("DEPRECATION")
    private fun vibrate() {
        val v = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            getSystemService(VibratorManager::class.java)?.defaultVibrator
        } else {
            getSystemService(Vibrator::class.java)
        }
        vibrator = v
        if (v == null || !v.hasVibrator()) return
        val attrs = AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_ALARM)
            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
            .build()
        v.vibrate(VibrationEffect.createWaveform(TimerAlarm.PATTERN, 0), attrs)
    }

    private var stopped = false

    private fun stop() {
        if (stopped) return
        stopped = true
        vibrator?.cancel()
        finish()
        TimerAlarm.stopRinging(this)
    }

    override fun onDestroy() {
        main.removeCallbacksAndMessages(null)
        vibrator?.cancel()
        open.removeAll { it.get() == null || it.get() === this }
        // Swiped away (Wear's back gesture) counts as Stop.
        if (isFinishing && !stopped) {
            stopped = true
            TimerAlarm.stopRinging(this)
        }
        super.onDestroy()
    }

    companion object {
        private val open = mutableListOf<WeakReference<TimesUpActivity>>()

        /** Closes any "Time's up" screen (the notification's Stop was used). */
        fun closeAll() {
            open.toList().forEach { ref -> ref.get()?.let { if (!it.isFinishing) it.stop() } }
        }
    }
}
