package com.mrgardener.byebyesleep.wear

import android.app.Activity
import android.content.Context
import android.content.res.ColorStateList
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.RectF
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.graphics.drawable.RippleDrawable
import android.util.TypedValue
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.view.WindowManager
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView
import kotlin.math.cos
import kotlin.math.min
import kotlin.math.roundToInt
import kotlin.math.sin

/**
 * Shared look of the watch tools: "Sunrise" colours on true black (OLED),
 * big pill buttons, and padding that keeps content inside a round screen
 * (Pixel Watch 3: 456 px). Plain Android views; the watch app has no Compose.
 */
object WatchUi {
    val NIGHT = Color.parseColor("#120E24")
    val TEXT = Color.parseColor("#F5F0FF")
    val SECONDARY = Color.parseColor("#BDB3DA")
    val CORAL = Color.parseColor("#FF8A65")
    val AMBER = Color.parseColor("#FFC155")
    val FAINT = Color.parseColor("#2A2346")

    fun dp(context: Context, value: Float): Int =
        TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, value, context.resources.displayMetrics).roundToInt()

    fun text(context: Context, sizeSp: Float, color: Int = TEXT, light: Boolean = false) = TextView(context).apply {
        setTextSize(TypedValue.COMPLEX_UNIT_SP, sizeSp)
        setTextColor(color)
        gravity = Gravity.CENTER
        includeFontPadding = false
        if (light) typeface = Typeface.create("sans-serif-light", Typeface.NORMAL)
        // Same-width digits, so running numbers do not wobble.
        fontFeatureSettings = "tnum"
    }

    /**
     * A rounded button. [filled]: solid [color] with night text; otherwise an
     * outline in [color] (the secondary action).
     */
    fun pill(context: Context, label: String, color: Int, filled: Boolean, onClick: () -> Unit) =
        TextView(context).apply {
            text = label
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 16f)
            typeface = Typeface.create("sans-serif-medium", Typeface.NORMAL)
            gravity = Gravity.CENTER
            minHeight = dp(context, 48f)
            setPadding(dp(context, 12f), dp(context, 6f), dp(context, 12f), dp(context, 6f))
            style(this, color, filled)
            isClickable = true
            isFocusable = true
            setOnClickListener { onClick() }
        }

    fun style(view: TextView, color: Int, filled: Boolean) {
        val shape = GradientDrawable().apply {
            cornerRadius = 999f
            if (filled) setColor(color) else {
                setColor(Color.BLACK)
                setStroke(dp(view.context, 2f), color)
            }
        }
        val mask = GradientDrawable().apply { cornerRadius = 999f; setColor(Color.WHITE) }
        view.background = RippleDrawable(ColorStateList.valueOf(0x40FFFFFF), shape, mask)
        view.setTextColor(if (filled) NIGHT else color)
    }

    fun matchWidth(context: Context, topMarginDp: Float = 6f) = LinearLayout.LayoutParams(
        ViewGroup.LayoutParams.MATCH_PARENT,
        ViewGroup.LayoutParams.WRAP_CONTENT,
    ).apply { topMargin = dp(context, topMarginDp) }

    fun weighted(context: Context, startMarginDp: Float = 0f) =
        LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f).apply {
            marginStart = dp(context, startMarginDp)
        }

    /**
     * A vertical, scrollable column for a round screen, inside a black frame.
     * The rotary crown scrolls it (the framework ScrollView reads
     * AXIS_SCROLL from the rotary encoder once it has focus). Returns the
     * frame (to set as content, and to add overlays such as [EdgeRing]) and
     * the column (to add rows to).
     */
    fun roundScreen(activity: Activity): Pair<FrameLayout, LinearLayout> {
        val metrics = activity.resources.displayMetrics
        val side = (metrics.widthPixels * 0.11).roundToInt()
        val top = (metrics.heightPixels * 0.13).roundToInt()
        val bottom = (metrics.heightPixels * 0.22).roundToInt()
        val column = LinearLayout(activity).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER_HORIZONTAL
            setPadding(side, top, side, bottom)
        }
        val scroll = ScrollView(activity).apply {
            isFillViewport = true
            isVerticalScrollBarEnabled = false
            isFocusable = true
            isFocusableInTouchMode = true
            addView(column, ViewGroup.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT))
        }
        val frame = FrameLayout(activity).apply {
            setBackgroundColor(Color.BLACK)
            addView(scroll, FrameLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT))
        }
        scroll.post { scroll.requestFocus() }
        return frame to column
    }

    /** Keeps the screen on only while something is counting. */
    fun keepScreenOn(activity: Activity, on: Boolean) {
        if (on) {
            activity.window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        } else {
            activity.window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        }
    }
}

/**
 * A ring along the round screen's edge: a faint track, an arc from 12 o'clock
 * clockwise to [fraction] (0..1) and a dot at its tip. Used as the clock's
 * sweep seconds, the timer's time left and the stopwatch's seconds.
 */
class EdgeRing(context: Context) : View(context) {
    var fraction = 0f
        set(value) {
            val v = value.coerceIn(0f, 1f)
            if (v != field) {
                field = v
                invalidate()
            }
        }
    var color = WatchUi.CORAL
        set(value) {
            field = value
            invalidate()
        }

    /** False: only the dot moves (a seconds hand); true: the arc fills too. */
    var showArc = true

    private val stroke = WatchUi.dp(context, 4f).toFloat()
    private val oval = RectF()
    private val track = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE
        strokeWidth = stroke
        color = WatchUi.FAINT
    }
    private val arc = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE
        strokeWidth = stroke
        strokeCap = Paint.Cap.ROUND
    }
    private val dot = Paint(Paint.ANTI_ALIAS_FLAG).apply { style = Paint.Style.FILL }

    init {
        isClickable = false
        isFocusable = false
        importantForAccessibility = IMPORTANT_FOR_ACCESSIBILITY_NO
    }

    override fun onDraw(canvas: Canvas) {
        val size = min(width, height).toFloat()
        val inset = stroke * 1.5f
        val r = size / 2f - inset
        val cx = width / 2f
        val cy = height / 2f
        oval.set(cx - r, cy - r, cx + r, cy + r)
        canvas.drawOval(oval, track)
        arc.color = color
        dot.color = color
        val sweep = fraction * 360f
        if (showArc && sweep > 0f) canvas.drawArc(oval, -90f, sweep, false, arc)
        val angle = Math.toRadians((sweep - 90f).toDouble())
        canvas.drawCircle(cx + r * cos(angle).toFloat(), cy + r * sin(angle).toFloat(), stroke * 1.4f, dot)
    }
}
