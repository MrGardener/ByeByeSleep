package com.mrgardener.byebyesleep.alarm

import android.content.Context
import org.json.JSONArray

/** Stores alarms as a JSON array in SharedPreferences (readable without Flutter, e.g. at boot). */
class PrefsAlarmRepository(context: Context) : AlarmRepository {
    private val prefs = context.getSharedPreferences("alarms", Context.MODE_PRIVATE)

    override fun all(): List<AlarmSpec> {
        val arr = JSONArray(prefs.getString(KEY, "[]"))
        return (0 until arr.length()).map { AlarmSpec.fromJson(arr.getJSONObject(it)) }
    }

    override fun get(id: Int): AlarmSpec? = all().firstOrNull { it.id == id }

    override fun put(spec: AlarmSpec) = save(all().filter { it.id != spec.id } + spec)

    override fun remove(id: Int) = save(all().filter { it.id != id })

    private fun save(specs: List<AlarmSpec>) {
        val arr = JSONArray()
        specs.forEach { arr.put(it.toJson()) }
        prefs.edit().putString(KEY, arr.toString()).commit()
    }

    private companion object {
        const val KEY = "alarms_json"
    }
}
