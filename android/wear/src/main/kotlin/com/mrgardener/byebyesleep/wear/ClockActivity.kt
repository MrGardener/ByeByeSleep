package com.mrgardener.byebyesleep.wear

import android.app.Activity
import android.graphics.Color
import android.graphics.Typeface
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.text.format.DateFormat
import android.util.TypedValue
import android.view.Gravity
import android.view.ViewGroup
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.TextClock
import java.util.Locale

/**
 * A big digital clock: time (12/24 h as the watch is set), date, and a coral
 * seconds arc sweeping round the edge of the screen.
 */
class ClockActivity : Activity() {
    private val main = Handler(Looper.getMainLooper())
    private lateinit var ring: EdgeRing

    private val sweep = object : Runnable {
        override fun run() {
            val now = System.currentTimeMillis()
            ring.fraction = (now % 60_000) / 60_000f
            main.postDelayed(this, 66)
        }
    }

    private fun clock(sizeSp: Float, color: Int, format12: String, format24: String) = TextClock(this).apply {
        setTextSize(TypedValue.COMPLEX_UNIT_SP, sizeSp)
        setTextColor(color)
        gravity = Gravity.CENTER
        includeFontPadding = false
        fontFeatureSettings = "tnum"
        // TextClock picks the 12 h or 24 h format from the watch's setting.
        this.format12Hour = format12
        this.format24Hour = format24
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        ring = EdgeRing(this).apply { color = WatchUi.CORAL }
        val datePattern = DateFormat.getBestDateTimePattern(Locale.getDefault(), "EEEdMMM")
        val time = clock(56f, WatchUi.TEXT, "h:mm", "HH:mm").apply {
            typeface = Typeface.create("sans-serif-light", Typeface.NORMAL)
        }
        val amPm = clock(14f, WatchUi.SECONDARY, "a", "")
        val date = clock(16f, WatchUi.AMBER, datePattern, datePattern)
        val column = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            addView(time)
            addView(amPm, WatchUi.matchWidth(this@ClockActivity, 2f))
            addView(date, WatchUi.matchWidth(this@ClockActivity, 8f))
        }
        setContentView(
            FrameLayout(this).apply {
                setBackgroundColor(Color.BLACK)
                addView(ring, FrameLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT))
                addView(
                    column,
                    FrameLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT, Gravity.CENTER),
                )
            },
        )
    }

    override fun onResume() {
        super.onResume()
        main.post(sweep)
    }

    override fun onPause() {
        main.removeCallbacks(sweep)
        super.onPause()
    }
}
