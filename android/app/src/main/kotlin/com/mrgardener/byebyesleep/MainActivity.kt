package com.mrgardener.byebyesleep

import android.Manifest
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import com.mrgardener.byebyesleep.alarm.AlarmChannel
import com.mrgardener.byebyesleep.alarm.AlarmGraph
import com.mrgardener.byebyesleep.alarm.AlarmService
import com.mrgardener.byebyesleep.alarm.AndroidAlarmClockScheduler
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Force-stop clears AlarmManager; opening the app restores every alarm.
        AlarmGraph.lifecycle(this).rescheduleAll()
        if (Build.VERSION.SDK_INT >= 33 &&
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED
        ) {
            requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 1)
        }
        scheduleDebugRingIfRequested()
    }

    override fun onResume() {
        super.onResume()
        // If notifications are blocked the ring screen never pops up by itself;
        // opening the app while an alarm rings must lead to it.
        AlarmService.ringingAlarmId?.let { startActivity(RingActivity.intent(this, it)) }
    }

    /** Debug builds only: `--ei debug_ring_in_seconds N` rings alarm 9999 in N seconds (emulator smoke test). It is not stored, so it never shows up in the list. */
    private fun scheduleDebugRingIfRequested() {
        val debuggable = applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE != 0
        val seconds = intent.getIntExtra("debug_ring_in_seconds", -1)
        if (!debuggable || seconds <= 0) return
        AndroidAlarmClockScheduler(this).schedule(9999, System.currentTimeMillis() + seconds * 1000L)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        AlarmChannel.register(flutterEngine.dartExecutor.binaryMessenger, this)
    }
}
