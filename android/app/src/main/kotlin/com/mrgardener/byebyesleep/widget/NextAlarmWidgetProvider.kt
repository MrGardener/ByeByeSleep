package com.mrgardener.byebyesleep.widget

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.text.format.DateFormat
import android.util.TypedValue
import android.widget.RemoteViews
import com.mrgardener.byebyesleep.R
import java.time.ZonedDateTime

/** Compact next-alarm widget on the Sunrise gradient: time, then day and label. */
class NextAlarmWidgetProvider : AppWidgetProvider() {
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
            val views = RemoteViews(context.packageName, R.layout.widget_next_alarm)
            if (next == null) {
                views.setTextViewText(R.id.next_time, context.getString(R.string.widget_no_alarm))
                views.setTextViewTextSize(R.id.next_time, TypedValue.COMPLEX_UNIT_SP, 20f)
                views.setTextViewText(R.id.next_detail, context.getString(R.string.widget_no_alarm_hint))
            } else {
                views.setTextViewText(R.id.next_time, NextAlarm.time(next.at, DateFormat.is24HourFormat(context)))
                views.setTextViewTextSize(R.id.next_time, TypedValue.COMPLEX_UNIT_SP, 28f)
                views.setTextViewText(R.id.next_detail, NextAlarm.detail(next, now))
            }
            views.setOnClickPendingIntent(android.R.id.background, Widgets.openApp(context))
            manager.updateAppWidget(id, views)
        }
    }
}
