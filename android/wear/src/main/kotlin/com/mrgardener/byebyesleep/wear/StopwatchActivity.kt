package com.mrgardener.byebyesleep.wear

import android.app.Activity
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.text.SpannableString
import android.text.Spanned
import android.text.style.RelativeSizeSpan
import android.util.TypedValue
import android.view.ViewGroup
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.TextView

/**
 * The watch stopwatch: Start / Pause, Lap / Reset and a lap list (newest
 * first, fastest in amber, slowest in coral). The state lives in
 * SharedPreferences as start instant + time so far, so it keeps counting
 * when the screen goes off or the app is closed. The crown scrolls the laps.
 */
class StopwatchActivity : Activity() {
    private val main = Handler(Looper.getMainLooper())
    private lateinit var ring: EdgeRing
    private lateinit var timeText: TextView
    private lateinit var startButton: TextView
    private lateinit var lapButton: TextView
    private lateinit var laps: LinearLayout
    private var state = StopwatchState()
    private var shownLaps = -1

    private val ticker = object : Runnable {
        override fun run() {
            renderTime()
            if (state.running) main.postDelayed(this, 50)
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val (frame, column) = WatchUi.roundScreen(this)
        ring = EdgeRing(this).apply {
            color = WatchUi.AMBER
            showArc = false
        }
        frame.addView(ring, 0, FrameLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT))

        column.addView(WatchUi.text(this, 14f, WatchUi.AMBER).apply { text = "Stopwatch" })
        // Thin white digits on black: easy to read, light on the OLED.
        timeText = WatchUi.text(this, 40f, WatchUi.TEXT, light = true).apply {
            maxLines = 1
            setAutoSizeTextTypeUniformWithConfiguration(20, 40, 1, TypedValue.COMPLEX_UNIT_SP)
        }
        column.addView(timeText, WatchUi.matchWidth(this, 6f))

        lapButton = WatchUi.pill(this, "Lap", WatchUi.SECONDARY, filled = false) { lapOrReset() }
        startButton = WatchUi.pill(this, "Start", WatchUi.CORAL, filled = true) { startOrPause() }
        column.addView(
            LinearLayout(this).apply {
                orientation = LinearLayout.HORIZONTAL
                addView(lapButton, WatchUi.weighted(this@StopwatchActivity))
                addView(startButton, WatchUi.weighted(this@StopwatchActivity, 6f))
            },
            WatchUi.matchWidth(this, 12f),
        )
        laps = LinearLayout(this).apply { orientation = LinearLayout.VERTICAL }
        column.addView(laps, WatchUi.matchWidth(this, 10f))
        setContentView(frame)
    }

    override fun onResume() {
        super.onResume()
        state = TimerAlarm.loadStopwatch(this)
        shownLaps = -1
        render()
    }

    override fun onPause() {
        main.removeCallbacks(ticker)
        WatchUi.keepScreenOn(this, false)
        super.onPause()
    }

    private fun startOrPause() {
        val now = System.currentTimeMillis()
        update(if (state.running) StopwatchLogic.pause(state, now) else StopwatchLogic.start(state, now))
    }

    private fun lapOrReset() {
        update(if (state.running) StopwatchLogic.lap(state, System.currentTimeMillis()) else StopwatchLogic.reset())
    }

    private fun update(next: StopwatchState) {
        state = next
        TimerAlarm.saveStopwatch(this, next)
        render()
    }

    private fun render() {
        startButton.text = when {
            state.running -> "Pause"
            state.clear -> "Start"
            else -> "Resume"
        }
        lapButton.text = if (state.running) "Lap" else "Reset"
        val lapEnabled = if (state.running) StopwatchLogic.canLap(state) else !state.clear
        lapButton.isEnabled = lapEnabled
        lapButton.alpha = if (lapEnabled) 1f else 0.4f
        WatchUi.keepScreenOn(this, state.running)
        if (state.laps.size != shownLaps) renderLaps()
        main.removeCallbacks(ticker)
        main.post(ticker)
    }

    private fun renderTime() {
        val ms = StopwatchLogic.elapsed(state, System.currentTimeMillis())
        val text = StopwatchLogic.format(ms)
        // Hundredths smaller, so the seconds stand out.
        timeText.text = SpannableString(text).apply {
            setSpan(RelativeSizeSpan(0.55f), text.length - 3, text.length, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
        }
        ring.fraction = (ms % 60_000) / 60_000f
    }

    private fun renderLaps() {
        shownLaps = state.laps.size
        laps.removeAllViews()
        for (row in StopwatchLogic.rows(state)) {
            val color = when {
                row.fastest -> WatchUi.AMBER
                row.slowest -> WatchUi.CORAL
                else -> WatchUi.TEXT
            }
            val line = LinearLayout(this).apply {
                orientation = LinearLayout.HORIZONTAL
                addView(WatchUi.text(this@StopwatchActivity, 13f, WatchUi.SECONDARY).apply {
                    text = "${row.number}"
                    gravity = android.view.Gravity.START
                }, LinearLayout.LayoutParams(WatchUi.dp(this@StopwatchActivity, 26f), ViewGroup.LayoutParams.WRAP_CONTENT))
                addView(WatchUi.text(this@StopwatchActivity, 14f, color).apply {
                    text = StopwatchLogic.format(row.lapMs)
                }, WatchUi.weighted(this@StopwatchActivity))
                addView(WatchUi.text(this@StopwatchActivity, 12f, WatchUi.SECONDARY).apply {
                    text = StopwatchLogic.format(row.splitMs)
                    gravity = android.view.Gravity.END
                }, WatchUi.weighted(this@StopwatchActivity))
                contentDescription = "Lap ${row.number}, ${StopwatchLogic.format(row.lapMs)}" +
                    when {
                        row.fastest -> ", fastest"
                        row.slowest -> ", slowest"
                        else -> ""
                    }
            }
            laps.addView(line, WatchUi.matchWidth(this, 6f))
        }
    }
}
