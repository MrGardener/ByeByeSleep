package com.mrgardener.byebyesleep.alarm

import android.content.Context
import android.os.UserManager
import org.json.JSONArray

/**
 * Stores alarms as a JSON array in device-protected SharedPreferences, so they are
 * readable at boot before the user first unlocks the phone (direct boot).
 */
class PrefsAlarmRepository(context: Context) : AlarmRepository {
    private val prefs = deviceProtected(context).getSharedPreferences(FILE, Context.MODE_PRIVATE)

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

    companion object {
        private const val FILE = "alarms"
        private const val KEY = "alarms_json"

        /** Device-protected storage; migrates the old credential-protected file once. */
        fun deviceProtected(context: Context): Context {
            val storage = context.createDeviceProtectedStorageContext()
            if (context.getSystemService(UserManager::class.java).isUserUnlocked) {
                storage.moveSharedPreferencesFrom(context, FILE)
            }
            return storage
        }
    }
}
