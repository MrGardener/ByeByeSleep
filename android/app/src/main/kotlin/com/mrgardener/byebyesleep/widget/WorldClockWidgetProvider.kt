package com.mrgardener.byebyesleep.widget

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.view.View
import android.widget.RemoteViews
import com.mrgardener.byebyesleep.R
import java.io.File
import java.time.Instant
import java.time.ZoneId
import org.json.JSONArray

/**
 * World clock widget: up to 3 cities picked in [WorldClockConfigureActivity], stored
 * per appWidgetId. Each city's time and weekday are TextClocks in its time zone, so
 * they tick by themselves; only the "+7 h" difference needs the 30-min refresh.
 */
class WorldClockWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        Widgets.refresh(context)
    }

    override fun onDeleted(context: Context, appWidgetIds: IntArray) {
        val edit = prefs(context).edit()
        appWidgetIds.forEach { edit.remove(key(it)) }
        edit.apply()
    }

    companion object {
        private const val PREFS = "world_clock_widgets"
        private val DEFAULT = listOf("Europe/London", "America/New_York", "Asia/Tokyo")

        private val rows = intArrayOf(R.id.world_row_1, R.id.world_row_2, R.id.world_row_3)
        private val cities = intArrayOf(R.id.world_city_1, R.id.world_city_2, R.id.world_city_3)
        private val days = intArrayOf(R.id.world_day_1, R.id.world_day_2, R.id.world_day_3)
        private val diffs = intArrayOf(R.id.world_diff_1, R.id.world_diff_2, R.id.world_diff_3)
        private val times = intArrayOf(R.id.world_time_1, R.id.world_time_2, R.id.world_time_3)

        private fun prefs(context: Context) =
            context.applicationContext.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

        private fun key(id: Int) = "zones_$id"

        /** The stored cities of widget [id], or null if none were picked yet. */
        fun stored(context: Context, id: Int): List<String>? =
            WorldCities.decode(prefs(context).getString(key(id), null)).ifEmpty { null }

        fun save(context: Context, id: Int, zones: List<String>) {
            prefs(context).edit().putString(key(id), WorldCities.encode(zones)).apply()
        }

        /** The cities on the app's own Clock tab (lib/tools/world_clock.dart), to start the picker with. */
        fun appCities(context: Context): List<String> = runCatching {
            // path_provider's documents directory on Android is getDir("flutter").
            val file = File(context.getDir("flutter", Context.MODE_PRIVATE), "world_clocks.json")
            val arr = JSONArray(file.readText())
            WorldCities.decode((0 until arr.length()).joinToString(",") { arr.getString(it) })
        }.getOrDefault(emptyList())

        fun update(context: Context, manager: AppWidgetManager, id: Int) {
            val zones = stored(context, id) ?: DEFAULT
            val here = ZoneId.systemDefault()
            val now = Instant.now()
            val views = RemoteViews(context.packageName, R.layout.widget_world)
            for (i in rows.indices) {
                val zone = zones.getOrNull(i)
                val city = zone?.let { WorldCities.forZone(it) }
                if (zone == null || city == null) {
                    views.setViewVisibility(rows[i], View.GONE)
                    continue
                }
                views.setViewVisibility(rows[i], View.VISIBLE)
                views.setTextViewText(cities[i], city.name)
                views.setString(times[i], "setTimeZone", zone)
                views.setString(days[i], "setTimeZone", zone)
                views.setTextViewText(diffs[i], " · " + WorldCities.difference(zone, here, now))
            }
            views.setOnClickPendingIntent(android.R.id.background, Widgets.openApp(context))
            manager.updateAppWidget(id, views)
        }
    }
}
