package com.mrgardener.byebyesleep

import android.Manifest
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import com.mrgardener.byebyesleep.alarm.AlarmChannel
import com.mrgardener.byebyesleep.alarm.AlarmSpec
import com.mrgardener.byebyesleep.alarm.AndroidAlarmClockScheduler
import com.mrgardener.byebyesleep.alarm.PrefsAlarmRepository
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (Build.VERSION.SDK_INT >= 33 &&
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED
        ) {
            requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 1)
        }
        scheduleDebugRingIfRequested()
    }

    /** Debug builds only: `--ei debug_ring_in_seconds N` rings alarm 9999 in N seconds (emulator smoke test). */
    private fun scheduleDebugRingIfRequested() {
        val debuggable = applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE != 0
        val seconds = intent.getIntExtra("debug_ring_in_seconds", -1)
        if (!debuggable || seconds <= 0) return
        PrefsAlarmRepository(this).put(AlarmSpec(9999, 0, 0, emptySet(), "smoke", true))
        AndroidAlarmClockScheduler(this).schedule(9999, System.currentTimeMillis() + seconds * 1000L)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        AlarmChannel.register(flutterEngine.dartExecutor.binaryMessenger, this)
    }
}
