package com.mrgardener.byebyesleep.widget

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.text.format.DateFormat
import android.widget.RemoteViews
import com.mrgardener.byebyesleep.R
import java.time.ZonedDateTime

/** Clock widget: a self-updating TextClock, the date and "Next alarm 06:30 · Tomorrow". */
class ClockWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        Widgets.refresh(context)
    }

    companion object {
        fun update(
            context: Context,
            manager: AppWidgetManager,
            id: Int,
            next: NextAlarm.Upcoming?,
            now: ZonedDateTime,
        ) {
            val views = RemoteViews(context.packageName, R.layout.widget_clock)
            views.setTextViewText(
                R.id.clock_alarm_text,
                NextAlarm.summary(next, now, DateFormat.is24HourFormat(context)),
            )
            views.setOnClickPendingIntent(android.R.id.background, Widgets.openApp(context))
            manager.updateAppWidget(id, views)
        }
    }
}
