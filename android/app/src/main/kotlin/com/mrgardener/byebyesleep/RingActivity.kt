package com.mrgardener.byebyesleep

import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.view.KeyEvent
import com.mrgardener.byebyesleep.alarm.AlarmChannel
import com.mrgardener.byebyesleep.alarm.EnvSensorsChannel
import com.mrgardener.byebyesleep.alarm.AlarmService
import com.mrgardener.byebyesleep.alarm.EXTRA_ALARM_ID
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

/** Shows the Flutter ring screen over the lock screen. */
class RingActivity : FlutterActivity() {
    private val alarmId get() = intent.getIntExtra(EXTRA_ALARM_ID, -1)

    override fun onCreate(savedInstanceState: Bundle?) {
        setShowWhenLocked(true)
        setTurnScreenOn(true)
        super.onCreate(savedInstanceState)
    }

    override fun getInitialRoute(): String = "/ring/$alarmId"

    private val envSensors = EnvSensorsChannel(this)

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        envSensors.onPermissionResult(requestCode, grantResults)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        AlarmChannel.register(flutterEngine.dartExecutor.binaryMessenger, this)
        envSensors.register(flutterEngine.dartExecutor.binaryMessenger)
    }

    // Volume keys must not silence or turn down the alarm.
    override fun dispatchKeyEvent(event: KeyEvent): Boolean = when (event.keyCode) {
        KeyEvent.KEYCODE_VOLUME_UP, KeyEvent.KEYCODE_VOLUME_DOWN, KeyEvent.KEYCODE_VOLUME_MUTE -> true
        else -> super.dispatchKeyEvent(event)
    }

    override fun onDestroy() {
        AlarmService.ringActivityGone(this)
        super.onDestroy()
    }

    companion object {
        fun intent(context: Context, id: Int): Intent =
            Intent(context, RingActivity::class.java)
                .putExtra(EXTRA_ALARM_ID, id)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_NO_USER_ACTION)
    }
}
