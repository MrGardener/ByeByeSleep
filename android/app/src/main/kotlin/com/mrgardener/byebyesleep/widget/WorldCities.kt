package com.mrgardener.byebyesleep.widget

import java.time.Instant
import java.time.ZoneId

/** Cities for the world clock widget (the same list as lib/tools/world_clock.dart). Pure, JVM-tested. */
object WorldCities {
    data class City(val name: String, val country: String, val zone: String)

    /** Most cities a world clock widget shows. */
    const val MAX = 3

    val all = listOf(
        City("Honolulu", "USA", "Pacific/Honolulu"),
        City("Anchorage", "USA", "America/Anchorage"),
        City("Los Angeles", "USA", "America/Los_Angeles"),
        City("Vancouver", "Canada", "America/Vancouver"),
        City("Denver", "USA", "America/Denver"),
        City("Mexico City", "Mexico", "America/Mexico_City"),
        City("Chicago", "USA", "America/Chicago"),
        City("New York", "USA", "America/New_York"),
        City("Toronto", "Canada", "America/Toronto"),
        City("Bogotá", "Colombia", "America/Bogota"),
        City("Lima", "Peru", "America/Lima"),
        City("Caracas", "Venezuela", "America/Caracas"),
        City("Santiago", "Chile", "America/Santiago"),
        City("Buenos Aires", "Argentina", "America/Argentina/Buenos_Aires"),
        City("São Paulo", "Brazil", "America/Sao_Paulo"),
        City("Reykjavík", "Iceland", "Atlantic/Reykjavik"),
        City("London", "UK", "Europe/London"),
        City("Lisbon", "Portugal", "Europe/Lisbon"),
        City("Madrid", "Spain", "Europe/Madrid"),
        City("Paris", "France", "Europe/Paris"),
        City("Amsterdam", "Netherlands", "Europe/Amsterdam"),
        City("Berlin", "Germany", "Europe/Berlin"),
        City("Rome", "Italy", "Europe/Rome"),
        City("Stockholm", "Sweden", "Europe/Stockholm"),
        City("Athens", "Greece", "Europe/Athens"),
        City("Istanbul", "Türkiye", "Europe/Istanbul"),
        City("Cairo", "Egypt", "Africa/Cairo"),
        City("Lagos", "Nigeria", "Africa/Lagos"),
        City("Johannesburg", "South Africa", "Africa/Johannesburg"),
        City("Nairobi", "Kenya", "Africa/Nairobi"),
        City("Moscow", "Russia", "Europe/Moscow"),
        City("Dubai", "UAE", "Asia/Dubai"),
        City("Karachi", "Pakistan", "Asia/Karachi"),
        City("Delhi", "India", "Asia/Kolkata"),
        City("Kathmandu", "Nepal", "Asia/Kathmandu"),
        City("Dhaka", "Bangladesh", "Asia/Dhaka"),
        City("Bangkok", "Thailand", "Asia/Bangkok"),
        City("Jakarta", "Indonesia", "Asia/Jakarta"),
        City("Singapore", "Singapore", "Asia/Singapore"),
        City("Hong Kong", "China", "Asia/Hong_Kong"),
        City("Shanghai", "China", "Asia/Shanghai"),
        City("Manila", "Philippines", "Asia/Manila"),
        City("Seoul", "South Korea", "Asia/Seoul"),
        City("Tokyo", "Japan", "Asia/Tokyo"),
        City("Perth", "Australia", "Australia/Perth"),
        City("Sydney", "Australia", "Australia/Sydney"),
        City("Auckland", "New Zealand", "Pacific/Auckland"),
    )

    fun forZone(zone: String): City? = all.firstOrNull { it.zone == zone }

    /** Cities whose name or country contains [query], ignoring case and accents. */
    fun search(query: String): List<City> {
        val q = fold(query.trim())
        return all.filter { fold(it.name).contains(q) || fold(it.country).contains(q) }
    }

    private fun fold(s: String): String = java.text.Normalizer.normalize(s.lowercase(), java.text.Normalizer.Form.NFD)
        .replace(Regex("\\p{M}+"), "")

    /** Stored choice ("Asia/Tokyo,Europe/London") back to known zones, at most [MAX]. */
    fun decode(stored: String?): List<String> =
        stored.orEmpty().split(',').map { it.trim() }.filter { forZone(it) != null }.distinct().take(MAX)

    fun encode(zones: List<String>): String = zones.distinct().take(MAX).joinToString(",")

    /** "+7 h", "−5 h 30 min", "Same time": the city's offset from [here] at [at]. */
    fun difference(zone: String, here: ZoneId, at: Instant): String {
        val diff = ZoneId.of(zone).rules.getOffset(at).totalSeconds - here.rules.getOffset(at).totalSeconds
        if (diff == 0) return "Same time"
        val mins = Math.abs(diff) / 60
        val h = mins / 60
        val m = mins % 60
        val amount = when {
            m == 0 -> "$h h"
            h == 0 -> "$m min"
            else -> "$h h $m min"
        }
        return (if (diff < 0) "−" else "+") + amount
    }
}
