package com.mrgardener.byebyesleep.wear

import android.Manifest
import android.app.Activity
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.util.TypedValue
import android.view.InputDevice
import android.view.MotionEvent
import android.view.ViewConfiguration
import android.view.ViewGroup
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.TextView

/**
 * The watch timer: presets (1–30 min), −/+ a minute (or turn the crown),
 * Start / Pause / Reset. The countdown runs in AlarmManager, so it rings with
 * the screen off and the app closed ([TimerAlarm], [TimesUpActivity]).
 */
class TimerActivity : Activity() {
    private val main = Handler(Looper.getMainLooper())
    private lateinit var ring: EdgeRing
    private lateinit var timeText: TextView
    private lateinit var stateText: TextView
    private lateinit var startButton: TextView
    private lateinit var resetButton: TextView
    private lateinit var minus: TextView
    private lateinit var plus: TextView
    private lateinit var hint: TextView
    private lateinit var crown: RotaryStepper
    private var state = TimerState()

    private val ticker = object : Runnable {
        override fun run() {
            render()
            main.postDelayed(this, 200)
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        crown = RotaryStepper(ViewConfiguration.get(this).scaledTouchSlop * 3f)
        val (frame, column) = WatchUi.roundScreen(this)
        ring = EdgeRing(this).apply { color = WatchUi.CORAL }
        frame.addView(ring, 0, FrameLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT))

        column.addView(WatchUi.text(this, 14f, WatchUi.AMBER).apply { text = "Timer" })

        minus = round("−") { change(-1) }
        plus = round("+") { change(+1) }
        timeText = WatchUi.text(this, 40f, WatchUi.TEXT, light = true).apply {
            maxLines = 1
            setAutoSizeTextTypeUniformWithConfiguration(18, 40, 1, TypedValue.COMPLEX_UNIT_SP)
        }
        column.addView(
            LinearLayout(this).apply {
                orientation = LinearLayout.HORIZONTAL
                gravity = android.view.Gravity.CENTER_VERTICAL
                addView(minus)
                addView(timeText, WatchUi.weighted(this@TimerActivity))
                addView(plus)
            },
            WatchUi.matchWidth(this, 6f),
        )
        stateText = WatchUi.text(this, 12f, WatchUi.SECONDARY)
        column.addView(stateText, WatchUi.matchWidth(this, 2f))

        startButton = WatchUi.pill(this, "Start", WatchUi.CORAL, filled = true) { startOrPause() }
        resetButton = WatchUi.pill(this, "Reset", WatchUi.SECONDARY, filled = false) { update(TimerLogic.reset(state)) }
        column.addView(
            LinearLayout(this).apply {
                orientation = LinearLayout.HORIZONTAL
                addView(resetButton, WatchUi.weighted(this@TimerActivity))
                addView(startButton, WatchUi.weighted(this@TimerActivity, 6f))
            },
            WatchUi.matchWidth(this, 10f),
        )

        hint = WatchUi.text(this, 12f, WatchUi.AMBER).apply {
            text = "Allow full-screen alerts so Time's up can open by itself. Tap to open settings."
            setOnClickListener { openAlertSettings() }
        }
        column.addView(hint, WatchUi.matchWidth(this, 8f))

        column.addView(WatchUi.text(this, 12f, WatchUi.SECONDARY).apply { text = "Presets (minutes)" }, WatchUi.matchWidth(this, 12f))
        TimerLogic.PRESETS.chunked(3).forEach { row ->
            column.addView(
                LinearLayout(this).apply {
                    orientation = LinearLayout.HORIZONTAL
                    row.forEachIndexed { i, minutes ->
                        val chip = WatchUi.pill(this@TimerActivity, "$minutes", WatchUi.AMBER, filled = false) {
                            preset(minutes)
                        }.apply { contentDescription = "$minutes minutes" }
                        addView(chip, WatchUi.weighted(this@TimerActivity, if (i == 0) 0f else 6f))
                    }
                },
                WatchUi.matchWidth(this, 6f),
            )
        }
        setContentView(frame)
    }

    private fun round(label: String, onClick: () -> Unit) =
        WatchUi.pill(this, label, WatchUi.SECONDARY, filled = false, onClick = onClick).apply {
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 22f)
            val size = WatchUi.dp(this@TimerActivity, 44f)
            minWidth = size
            minHeight = size
            setPadding(0, 0, 0, 0)
            layoutParams = LinearLayout.LayoutParams(size, size)
            contentDescription = if (label == "+") "One minute more" else "One minute less"
        }

    override fun onResume() {
        super.onResume()
        state = TimerAlarm.loadTimer(this)
        main.post(ticker)
    }

    override fun onPause() {
        main.removeCallbacks(ticker)
        WatchUi.keepScreenOn(this, false)
        super.onPause()
    }

    /** The crown sets the minutes while the timer is idle; otherwise it scrolls. */
    override fun dispatchGenericMotionEvent(event: MotionEvent): Boolean {
        if (event.action == MotionEvent.ACTION_SCROLL &&
            event.isFromSource(InputDevice.SOURCE_ROTARY_ENCODER) &&
            state.idle
        ) {
            val pixels = -event.getAxisValue(MotionEvent.AXIS_SCROLL) *
                ViewConfiguration.get(this).scaledVerticalScrollFactor
            val steps = crown.add(pixels)
            if (steps != 0) change(steps)
            return true
        }
        return super.dispatchGenericMotionEvent(event)
    }

    private fun change(minutes: Int) = update(TimerLogic.adjustMinutes(state, minutes))

    private fun preset(minutes: Int) {
        // One tap: a preset replaces the current timer and starts right away.
        val now = System.currentTimeMillis()
        update(TimerLogic.start(TimerLogic.setMinutes(TimerState(), minutes), now))
        askForNotifications()
    }

    private fun startOrPause() {
        val now = System.currentTimeMillis()
        if (state.running) {
            update(TimerLogic.pause(state, now))
        } else {
            update(TimerLogic.start(state, now))
            askForNotifications()
        }
    }

    private fun update(next: TimerState) {
        if (next != state) TimerAlarm.apply(this, next)
        state = next
        render()
    }

    private fun render() {
        // The receiver resets the timer when it rings; follow it.
        val stored = TimerAlarm.loadTimer(this)
        val now = System.currentTimeMillis()
        if (stored != state) {
            // Rang while this screen was open: the system may only show a
            // heads-up, so open "Time's up" from here.
            if (state.running && stored.idle && now >= state.endAtMs) showTimesUp(state)
            state = stored
        }
        timeText.text = TimerLogic.format(TimerLogic.remaining(state, now))
        ring.fraction = if (state.idle) 1f else TimerLogic.fractionLeft(state, now)
        ring.color = if (state.paused) WatchUi.SECONDARY else WatchUi.CORAL
        stateText.text = when {
            state.running -> "of ${TimerLogic.label(state.durationMs)}"
            state.paused -> "Paused · ${TimerLogic.label(state.durationMs)}"
            else -> "Turn the crown or tap − +"
        }
        startButton.text = when {
            state.running -> "Pause"
            state.paused -> "Resume"
            else -> "Start"
        }
        resetButton.isEnabled = !state.idle
        resetButton.alpha = if (state.idle) 0.4f else 1f
        val editable = state.idle
        minus.isEnabled = editable
        plus.isEnabled = editable
        minus.alpha = if (editable) 1f else 0.3f
        plus.alpha = if (editable) 1f else 0.3f
        hint.visibility = if (!state.idle && !TimerAlarm.canAlertFullScreen(this)) android.view.View.VISIBLE else android.view.View.GONE
        WatchUi.keepScreenOn(this, state.running)
    }

    private fun showTimesUp(ended: TimerState) {
        val intent = Intent(this, TimesUpActivity::class.java)
            .putExtra(TimerAlarm.EXTRA_LABEL, "${TimerLogic.label(ended.durationMs)} timer")
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        runCatching { startActivity(intent) }
    }

    private fun askForNotifications() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED
        ) {
            requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), REQUEST_NOTIFICATIONS)
        }
    }

    private fun openAlertSettings() {
        val intent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            Intent(Settings.ACTION_MANAGE_APP_USE_FULL_SCREEN_INTENT, Uri.parse("package:$packageName"))
        } else {
            Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
        }
        runCatching { startActivity(intent) }.onFailure {
            runCatching {
                startActivity(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:$packageName")))
            }
        }
    }

    private companion object {
        const val REQUEST_NOTIFICATIONS = 7
    }
}
