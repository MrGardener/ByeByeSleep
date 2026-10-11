package com.mrgardener.byebyesleep.alarm

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.media.AudioAttributes
import android.media.AudioManager
import android.media.MediaPlayer
import android.media.RingtoneManager
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import android.os.UserManager
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.util.Log
import com.mrgardener.byebyesleep.RingActivity

/** Foreground service that makes the noise and keeps the ring screen up. */
class AlarmService : Service() {
    private var player: MediaPlayer? = null
    private var vibrator: Vibrator? = null
    private var wakeLock: PowerManager.WakeLock? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_RING -> {
                ring(intent.getIntExtra(EXTRA_ALARM_ID, -1))
                // If the process is killed while ringing, Android restarts us with this intent.
                return START_REDELIVER_INTENT
            }
            ACTION_RING_ACTIVITY_GONE -> ringingAlarmId?.let { postNotification(it, repost = true) }
            ACTION_STOP -> stopRinging()
        }
        return START_NOT_STICKY
    }

    private fun ring(id: Int) {
        val alreadyRinging = player != null
        if (ringingAlarmId == null) ringingAlarmId = id
        ringingAlarmIds = ringingAlarmIds + id
        val notification = postNotification(id, repost = false)
        if (Build.VERSION.SDK_INT >= 34) {
            startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_SYSTEM_EXEMPTED)
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
        if (alreadyRinging) return

        wakeLock = getSystemService(PowerManager::class.java)
            .newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "byebyesleep:ring")
            .apply { acquire(30 * 60 * 1000L) }

        // Remember the user's volume once (survives a process restart while ringing).
        runCatching {
            val audio = getSystemService(AudioManager::class.java)
            val state = ringingState()
            if (!state.contains(KEY_PREVIOUS_VOLUME)) {
                val current = audio.getStreamVolume(AudioManager.STREAM_ALARM)
                state.edit().putInt(KEY_PREVIOUS_VOLUME, current).commit()
                Log.i(TAG, "saved alarm volume $current")
            }
            audio.setStreamVolume(AudioManager.STREAM_ALARM, audio.getStreamMaxVolume(AudioManager.STREAM_ALARM), 0)
        }

        val attrs = AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_ALARM)
            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
            .build()
        val uri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
            ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_RINGTONE)
        player = runCatching {
            MediaPlayer().apply {
                setAudioAttributes(attrs)
                setDataSource(this@AlarmService, uri)
                isLooping = true
                prepare()
                start()
            }
        }.getOrNull()

        vibrator = (if (Build.VERSION.SDK_INT >= 31) {
            getSystemService(VibratorManager::class.java).defaultVibrator
        } else {
            @Suppress("DEPRECATION")
            getSystemService(Vibrator::class.java)
        }).also {
            @Suppress("DEPRECATION")
            it.vibrate(VibrationEffect.createWaveform(longArrayOf(0, 800, 600), 0), attrs)
        }
    }

    private fun postNotification(id: Int, repost: Boolean): Notification {
        val nm = getSystemService(NotificationManager::class.java)
        nm.createNotificationChannel(
            NotificationChannel(CHANNEL_ID, "Ringing alarms", NotificationManager.IMPORTANCE_HIGH).apply {
                setSound(null, null)
                enableVibration(false)
            },
        )
        val open = PendingIntent.getActivity(
            this, id, RingActivity.intent(this, id),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        val builder = Notification.Builder(this, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
            .setContentTitle("ByeByeSleep")
            .setContentText("Alarm ringing — open to stop it")
            .setCategory(Notification.CATEGORY_ALARM)
            .setOngoing(true)
            .setContentIntent(open)
            .setFullScreenIntent(open, true)
        if (!getSystemService(UserManager::class.java).isUserUnlocked) {
            // Before the first unlock after a reboot the Flutter ring screen cannot start,
            // so offer a native Stop instead of an alarm nobody can silence.
            val stop = PendingIntent.getService(
                this, 0, Intent(this, AlarmService::class.java).setAction(ACTION_STOP),
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
            )
            builder.addAction(Notification.Action.Builder(null, "Stop", stop).build())
        }
        val notification = builder.build()
        if (repost) {
            // Cancel first so the system shows the full-screen intent again.
            nm.cancel(NOTIFICATION_ID)
            nm.notify(NOTIFICATION_ID, notification)
        }
        return notification
    }

    private fun stopRinging() {
        ringingAlarmId = null
        ringingAlarmIds = emptySet()
        player?.run { runCatching { stop() }; release() }
        player = null
        vibrator?.cancel()
        vibrator = null
        val state = ringingState()
        if (state.contains(KEY_PREVIOUS_VOLUME)) {
            runCatching {
                val previous = state.getInt(KEY_PREVIOUS_VOLUME, 0)
                getSystemService(AudioManager::class.java).setStreamVolume(AudioManager.STREAM_ALARM, previous, 0)
                Log.i(TAG, "restored alarm volume $previous")
            }
            state.edit().remove(KEY_PREVIOUS_VOLUME).commit()
        }
        wakeLock?.takeIf { it.isHeld }?.release()
        wakeLock = null
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    private fun ringingState() = createDeviceProtectedStorageContext()
        .getSharedPreferences("ringing", MODE_PRIVATE)

    override fun onDestroy() {
        if (player != null) stopRinging()
        super.onDestroy()
    }

    companion object {
        private const val ACTION_RING = "com.mrgardener.byebyesleep.RING"
        private const val ACTION_STOP = "com.mrgardener.byebyesleep.STOP"
        private const val ACTION_RING_ACTIVITY_GONE = "com.mrgardener.byebyesleep.RING_ACTIVITY_GONE"
        private const val CHANNEL_ID = "alarm_ringing"
        private const val NOTIFICATION_ID = 4242
        private const val KEY_PREVIOUS_VOLUME = "previous_alarm_volume"
        private const val TAG = "ByeByeSleep"

        /** Id of the alarm shown on the ring screen (the first one that rang), or null. */
        @Volatile var ringingAlarmId: Int? = null
            private set

        /** Every alarm ringing right now; Snooze applies to all of them. */
        @Volatile var ringingAlarmIds: Set<Int> = emptySet()
            private set

        fun ringIntent(context: Context, id: Int): Intent =
            Intent(context, AlarmService::class.java).setAction(ACTION_RING).putExtra(EXTRA_ALARM_ID, id)

        /** Marks ringing as stopped immediately, then lets the service clean up. */
        fun stop(context: Context) {
            ringingAlarmId = null
            ringingAlarmIds = emptySet()
            context.startService(Intent(context, AlarmService::class.java).setAction(ACTION_STOP))
        }

        fun ringActivityGone(context: Context) {
            if (ringingAlarmId == null) return
            context.startService(Intent(context, AlarmService::class.java).setAction(ACTION_RING_ACTIVITY_GONE))
        }
    }
}
