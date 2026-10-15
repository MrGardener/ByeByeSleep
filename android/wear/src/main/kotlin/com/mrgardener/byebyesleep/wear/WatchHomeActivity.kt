package com.mrgardener.byebyesleep.wear

import android.app.Activity
import android.content.Intent
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.text.SpannableStringBuilder
import android.text.Spanned
import android.text.style.ForegroundColorSpan
import android.text.style.RelativeSizeSpan
import android.widget.TextClock
import android.widget.TextView

/**
 * The watch app's home (launcher): Clock, Timer, Stopwatch and Heart rate as
 * big buttons for a round screen. Timer and Stopwatch show what is running.
 * Works on the watch alone; only Heart rate talks to the phone.
 */
class WatchHomeActivity : Activity() {
    private val main = Handler(Looper.getMainLooper())
    private lateinit var timerButton: TextView
    private lateinit var stopwatchButton: TextView

    private val ticker = object : Runnable {
        override fun run() {
            renderStatus()
            main.postDelayed(this, 1000)
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val (frame, column) = WatchUi.roundScreen(this)
        column.addView(
            TextClock(this).apply {
                textSize = 15f
                setTextColor(WatchUi.AMBER)
                gravity = android.view.Gravity.CENTER
                format12Hour = "h:mm a"
                format24Hour = "HH:mm"
            },
        )
        column.addView(WatchUi.text(this, 12f, WatchUi.SECONDARY).apply { text = "ByeByeSleep" }, WatchUi.matchWidth(this, 2f))

        column.addView(button("Clock", WatchUi.AMBER, ClockActivity::class.java), WatchUi.matchWidth(this, 10f))
        timerButton = button("Timer", WatchUi.CORAL, TimerActivity::class.java)
        column.addView(timerButton, WatchUi.matchWidth(this, 8f))
        stopwatchButton = button("Stopwatch", WatchUi.CORAL, StopwatchActivity::class.java)
        column.addView(stopwatchButton, WatchUi.matchWidth(this, 8f))
        column.addView(button("♥ Heart rate", WatchUi.SECONDARY, HeartRateActivity::class.java), WatchUi.matchWidth(this, 8f))
        setContentView(frame)
    }

    private fun button(label: String, color: Int, target: Class<out Activity>) =
        WatchUi.pill(this, label, color, filled = false) { startActivity(Intent(this, target)) }.apply {
            minHeight = WatchUi.dp(this@WatchHomeActivity, 56f)
            textSize = 17f
        }

    override fun onResume() {
        super.onResume()
        main.post(ticker)
    }

    override fun onPause() {
        main.removeCallbacks(ticker)
        super.onPause()
    }

    private fun renderStatus() {
        val now = System.currentTimeMillis()
        val timer = TimerAlarm.loadTimer(this)
        timerButton.text = withStatus(
            "Timer",
            when {
                timer.running -> "${TimerLogic.format(TimerLogic.remaining(timer, now))} left"
                timer.paused -> "Paused ${TimerLogic.format(timer.pausedRemainingMs)}"
                else -> null
            },
        )
        val watch = TimerAlarm.loadStopwatch(this)
        stopwatchButton.text = withStatus(
            "Stopwatch",
            when {
                watch.running -> StopwatchLogic.format(StopwatchLogic.elapsed(watch, now)).substringBeforeLast('.')
                !watch.clear -> "Paused"
                else -> null
            },
        )
    }

    /** "Timer" plus, on a second smaller line, what it is doing. */
    private fun withStatus(label: String, status: String?): CharSequence {
        if (status == null) return label
        val text = SpannableStringBuilder(label).append('\n')
        val start = text.length
        text.append(status)
        text.setSpan(RelativeSizeSpan(0.75f), start, text.length, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
        text.setSpan(ForegroundColorSpan(WatchUi.SECONDARY), start, text.length, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
        return text
    }
}
