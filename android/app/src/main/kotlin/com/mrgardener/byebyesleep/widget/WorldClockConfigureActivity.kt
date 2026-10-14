package com.mrgardener.byebyesleep.widget

import android.app.Activity
import android.appwidget.AppWidgetManager
import android.content.Intent
import android.os.Bundle
import android.text.Editable
import android.text.TextWatcher
import android.widget.ArrayAdapter
import android.widget.Button
import android.widget.EditText
import android.widget.ListView
import android.widget.TextView
import android.widget.Toast
import com.mrgardener.byebyesleep.R

/** Picks up to 3 cities for one world clock widget (on add, and again via "reconfigure"). */
class WorldClockConfigureActivity : Activity() {
    private var widgetId = AppWidgetManager.INVALID_APPWIDGET_ID
    private val picked = mutableListOf<String>()
    private var shown: List<WorldCities.City> = WorldCities.all
    private lateinit var list: ListView
    private lateinit var adapter: ArrayAdapter<String>
    private lateinit var hint: TextView
    private lateinit var done: Button

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Backing out must not leave an empty widget behind.
        setResult(RESULT_CANCELED)
        widgetId = intent?.extras?.getInt(AppWidgetManager.EXTRA_APPWIDGET_ID, AppWidgetManager.INVALID_APPWIDGET_ID)
            ?: AppWidgetManager.INVALID_APPWIDGET_ID
        if (widgetId == AppWidgetManager.INVALID_APPWIDGET_ID) {
            finish()
            return
        }
        setContentView(R.layout.world_clock_configure)
        findViewById<android.view.View>(R.id.config_root).padForSystemBars()

        picked += savedInstanceState?.getStringArrayList(STATE_PICKED)
            ?: WorldClockWidgetProvider.stored(this, widgetId)
            ?: WorldClockWidgetProvider.appCities(this)

        hint = findViewById(R.id.config_hint)
        done = findViewById(R.id.config_done)
        list = findViewById(R.id.config_list)
        adapter = ArrayAdapter(this, android.R.layout.simple_list_item_multiple_choice, mutableListOf<String>())
        list.adapter = adapter
        list.setOnItemClickListener { _, _, position, _ -> toggle(position) }

        findViewById<EditText>(R.id.config_search).addTextChangedListener(object : TextWatcher {
            override fun beforeTextChanged(s: CharSequence?, start: Int, count: Int, after: Int) = Unit
            override fun onTextChanged(s: CharSequence?, start: Int, before: Int, count: Int) = Unit
            override fun afterTextChanged(s: Editable?) = show(s?.toString().orEmpty())
        })
        findViewById<Button>(R.id.config_cancel).setOnClickListener { finish() }
        done.setOnClickListener { finishWithChoice() }
        show("")
    }

    override fun onSaveInstanceState(outState: Bundle) {
        super.onSaveInstanceState(outState)
        outState.putStringArrayList(STATE_PICKED, ArrayList(picked))
    }

    /** Lists the cities matching [query]: the picked ones first, in their order. */
    private fun show(query: String) {
        val matches = WorldCities.search(query)
        shown = picked.mapNotNull { z -> matches.firstOrNull { it.zone == z } } +
            matches.filter { it.zone !in picked }
        adapter.clear()
        adapter.addAll(shown.map { "${it.name}, ${it.country}" })
        adapter.notifyDataSetChanged()
        shown.forEachIndexed { i, city -> list.setItemChecked(i, city.zone in picked) }
        updateHint()
    }

    private fun toggle(position: Int) {
        val zone = shown.getOrNull(position)?.zone ?: return
        when {
            zone in picked -> picked.remove(zone)
            picked.size >= WorldCities.MAX -> {
                Toast.makeText(this, R.string.world_config_limit, Toast.LENGTH_SHORT).show()
            }
            else -> picked.add(zone)
        }
        list.setItemChecked(position, zone in picked)
        updateHint()
    }

    private fun updateHint() {
        val names = picked.mapNotNull { WorldCities.forZone(it)?.name }
        hint.text = if (names.isEmpty()) getString(R.string.world_config_hint) else names.joinToString(" · ")
        done.isEnabled = names.isNotEmpty()
    }

    private fun finishWithChoice() {
        if (picked.isEmpty()) return
        WorldClockWidgetProvider.save(this, widgetId, picked)
        WorldClockWidgetProvider.update(this, AppWidgetManager.getInstance(this), widgetId)
        setResult(RESULT_OK, Intent().putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId))
        finish()
    }

    private companion object {
        const val STATE_PICKED = "picked"
    }
}
