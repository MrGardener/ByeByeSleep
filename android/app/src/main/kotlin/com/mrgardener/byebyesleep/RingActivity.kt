package com.mrgardener.byebyesleep

import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.view.KeyEvent
import com.mrgardener.byebyesleep.alarm.AlarmChannel
import com.mrgardener.byebyesleep.alarm.EmergencyChannel
import com.mrgardener.byebyesleep.alarm.EnvSensorsChannel
import com.mrgardener.byebyesleep.alarm.WatchChannel
import com.mrgardener.byebyesleep.alarm.AlarmService
import com.mrgardener.byebyesleep.alarm.EXTRA_ALARM_ID
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

/** Shows the Flutter ring screen over the lock screen. */
class RingActivity : FlutterActivity() {
    private val alarmId get() = intent.getIntExtra(EXTRA_ALARM_ID, -1)

    override fun onCreate(savedInstanceState: Bundle?) {
        showing = java.lang.ref.WeakReference(this)
        setShowWhenLocked(true)
        setTurnScreenOn(true)
        super.onCreate(savedInstanceState)
    }

    override fun getInitialRoute(): String = "/ring/$alarmId"

    // A new ring while this screen is still open (e.g. on the reminder after
    // Stop): keep its intent, so a recreated screen shows the new alarm. The
    // Flutter side notices the new ring itself (lib/ringing/after_stop.dart).
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
    }

    private val envSensors = EnvSensorsChannel(this)
    private val watch = WatchChannel(this)
    private val emergency = EmergencyChannel(this)

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        envSensors.onPermissionResult(requestCode, grantResults)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        AlarmChannel.register(flutterEngine.dartExecutor.binaryMessenger, this)
        envSensors.register(flutterEngine.dartExecutor.binaryMessenger)
        watch.register(flutterEngine.dartExecutor.binaryMessenger)
        emergency.register(flutterEngine.dartExecutor.binaryMessenger)
    }

    // Volume keys must not silence or turn down the alarm; a press counts as
    // a step of the emergency protocol.
    override fun dispatchKeyEvent(event: KeyEvent): Boolean = when (event.keyCode) {
        KeyEvent.KEYCODE_VOLUME_UP, KeyEvent.KEYCODE_VOLUME_DOWN, KeyEvent.KEYCODE_VOLUME_MUTE -> {
            if (event.action == KeyEvent.ACTION_DOWN && event.repeatCount == 0) emergency.volumeKeyPressed()
            true
        }
        else -> super.dispatchKeyEvent(event)
    }

    override fun onDestroy() {
        if (showing?.get() === this) showing = null
        AlarmService.ringActivityGone(this)
        super.onDestroy()
    }

    companion object {
        @Volatile private var showing: java.lang.ref.WeakReference<RingActivity>? = null

        /** The alarm stopped by itself (ring limit): close the ring screen. */
        fun closeIfShowing() {
            showing?.get()?.let { activity -> activity.runOnUiThread { activity.finish() } }
        }

        fun intent(context: Context, id: Int): Intent =
            Intent(context, RingActivity::class.java)
                .putExtra(EXTRA_ALARM_ID, id)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_NO_USER_ACTION)
    }
}
