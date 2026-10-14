package com.mrgardener.byebyesleep.widget

import android.app.Activity
import android.content.Context
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.service.dreams.DreamService
import android.text.format.DateFormat
import android.view.View
import android.widget.Switch
import android.widget.TextClock
import android.widget.TextView
import com.mrgardener.byebyesleep.R
import java.time.ZonedDateTime
import kotlin.random.Random

/**
 * "ByeByeSleep clock" screen saver (Settings → Display → Screen saver): a big
 * bedside clock with the date and the next alarm. Night colours (default) are dim
 * amber on black at the lowest brightness; the clock drifts a little every minute
 * so no pixel stays lit in the same place (burn-in).
 */
class ClockDreamService : DreamService() {
    private val handler = Handler(Looper.getMainLooper())
    private var clock: View? = null
    private var alarm: TextView? = null
    private var showAlarm = true

    private val tick = object : Runnable {
        override fun run() {
            updateAlarm()
            drift()
            val now = System.currentTimeMillis()
            handler.postDelayed(this, MINUTE_MS - now % MINUTE_MS + 500)
        }
    }

    override fun onAttachedToWindow() {
        super.onAttachedToWindow()
        val night = ClockDreamSettings.night(this)
        showAlarm = ClockDreamSettings.showAlarm(this)
        isInteractive = false
        isFullscreen = true
        // Let the system dim the screen; in night mode also ask for the lowest level.
        isScreenBright = !night
        setContentView(R.layout.dream_clock)
        if (night) {
            window?.let { w ->
                val attrs = w.attributes
                attrs.screenBrightness = NIGHT_BRIGHTNESS
                w.attributes = attrs
            }
        }

        val root = findViewById<View>(R.id.dream_root)
        val time = findViewById<TextClock>(R.id.dream_time)
        val date = findViewById<TextClock>(R.id.dream_date)
        clock = findViewById(R.id.dream_clock)
        alarm = findViewById(R.id.dream_alarm)
        if (night) {
            val amber = getColor(R.color.dream_night_text)
            root.setBackgroundColor(getColor(R.color.dream_black))
            time.setTextColor(amber)
            date.setTextColor(amber)
            alarm?.setTextColor(amber)
            clock?.alpha = NIGHT_ALPHA
        } else {
            root.setBackgroundColor(getColor(R.color.dream_full_bg))
            time.setTextColor(getColor(R.color.dream_full_text))
            date.setTextColor(getColor(R.color.dream_full_secondary))
            alarm?.setTextColor(getColor(R.color.dream_full_accent))
            clock?.alpha = 1f
        }
        updateAlarm()
    }

    override fun onDreamingStarted() {
        super.onDreamingStarted()
        handler.removeCallbacks(tick)
        handler.post(tick)
    }

    override fun onDreamingStopped() {
        handler.removeCallbacks(tick)
        super.onDreamingStopped()
    }

    override fun onDetachedFromWindow() {
        handler.removeCallbacksAndMessages(null)
        clock = null
        alarm = null
        super.onDetachedFromWindow()
    }

    private fun updateAlarm() {
        val view = alarm ?: return
        val next = if (showAlarm) Widgets.nextAlarm(this) else null
        if (next == null) {
            view.visibility = View.GONE
            return
        }
        view.visibility = View.VISIBLE
        view.text = NextAlarm.summary(next, ZonedDateTime.now(), DateFormat.is24HourFormat(this))
    }

    /** Moves the clock to a random spot near the centre (burn-in protection). */
    private fun drift() {
        val block = clock ?: return
        val parent = block.parent as? View ?: return
        if (parent.width == 0 || block.width == 0) return
        val maxX = ((parent.width - block.width) / 2f * DRIFT_SHARE).coerceAtLeast(0f)
        val maxY = ((parent.height - block.height) / 2f * DRIFT_SHARE).coerceAtLeast(0f)
        block.animate()
            .translationX(if (maxX > 0f) Random.nextFloat() * 2 * maxX - maxX else 0f)
            .translationY(if (maxY > 0f) Random.nextFloat() * 2 * maxY - maxY else 0f)
            .setDuration(DRIFT_MS)
            .start()
    }

    private companion object {
        const val MINUTE_MS = 60_000L
        const val DRIFT_MS = 2_000L
        /** Share of the free space the clock may drift into. */
        const val DRIFT_SHARE = 0.6f
        const val NIGHT_BRIGHTNESS = 0.01f
        const val NIGHT_ALPHA = 0.55f
    }
}

/** Screen saver options, in the app's own prefs. */
object ClockDreamSettings {
    private const val PREFS = "screen_saver"
    private const val KEY_NIGHT = "night_colours"
    private const val KEY_ALARM = "show_alarm"

    private fun prefs(context: Context) =
        context.applicationContext.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    fun night(context: Context) = prefs(context).getBoolean(KEY_NIGHT, true)

    fun showAlarm(context: Context) = prefs(context).getBoolean(KEY_ALARM, true)

    fun setNight(context: Context, on: Boolean) = prefs(context).edit().putBoolean(KEY_NIGHT, on).apply()

    fun setShowAlarm(context: Context, on: Boolean) = prefs(context).edit().putBoolean(KEY_ALARM, on).apply()
}

/** Opened from Settings → Display → Screen saver → ByeByeSleep clock → settings. */
class ClockDreamSettingsActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.dream_settings)
        findViewById<View>(R.id.dream_settings_root).padForSystemBars()
        findViewById<Switch>(R.id.dream_night_switch).apply {
            isChecked = ClockDreamSettings.night(context)
            setOnCheckedChangeListener { _, on -> ClockDreamSettings.setNight(context, on) }
        }
        findViewById<Switch>(R.id.dream_alarm_switch).apply {
            isChecked = ClockDreamSettings.showAlarm(context)
            setOnCheckedChangeListener { _, on -> ClockDreamSettings.setShowAlarm(context, on) }
        }
    }
}
