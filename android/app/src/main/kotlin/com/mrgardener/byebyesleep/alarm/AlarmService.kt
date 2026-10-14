package com.mrgardener.byebyesleep.alarm

import android.app.KeyguardManager
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
import android.provider.Settings
import android.util.Log
import com.mrgardener.byebyesleep.RingActivity

/** Foreground service that makes the noise and keeps the ring screen up. */
class AlarmService : Service() {
    private var player: MediaPlayer? = null
    private var vibrator: Vibrator? = null
    private var wakeLock: PowerManager.WakeLock? = null
    private var ringing = false
    private var soundPending = false
    private var level = 1f
    private val soundFallback = Runnable { startSound() }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_RING -> {
                ring(
                    intent.getIntExtra(EXTRA_ALARM_ID, -1),
                    redelivered = flags and START_FLAG_REDELIVERY != 0,
                    followUp = intent.getBooleanExtra(EXTRA_FOLLOW_UP, false),
                )
                // If the process is killed while ringing, Android restarts us with this intent.
                return START_REDELIVER_INTENT
            }
            ACTION_RING_ACTIVITY_GONE -> ringingAlarmId?.let { postNotification(it, repost = true) }
            ACTION_SET_LEVEL -> intent.getFloatExtra(EXTRA_LEVEL, 1f).coerceIn(0f, 1f).let {
                level = it
                player?.setVolume(it, it)
            }
            ACTION_SCREEN_READY -> startSound()
            ACTION_STOP -> stopRinging()
        }
        return START_NOT_STICKY
    }

    private fun ring(id: Int, redelivered: Boolean, followUp: Boolean) {
        val alreadyRinging = ringing
        if (ringingAlarmId == null) ringingAlarmId = id
        ringingAlarmIds = ringingAlarmIds + id
        val notification = postNotification(id, repost = false)
        if (Build.VERSION.SDK_INT >= 34) {
            startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_SYSTEM_EXEMPTED)
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
        if (alreadyRinging) return
        ringing = true
        level = 1f

        // A new ring starts at stage 0; a redelivered one (process restarted) continues.
        val progress = RingProgress.onRing(storedProgress(this), id, System.currentTimeMillis(), redelivered, followUp)
        ringingState().edit().putString(KEY_PROGRESS, progress.toJson().toString()).commit()

        // Nobody there (owner away, phone forgotten): stop by itself after
        // the alarm's limit, counted from when this ring started.
        val limit = runCatching {
            PrefsAlarmRepository(applicationContext).get(id)?.let { RingLimit.minutes(it.extrasJson) }
        }.getOrNull() ?: RingLimit.DEFAULT_MINUTES
        val left = RingLimit.remainingMs(limit, progress.startedAtMs, System.currentTimeMillis())
        timeout.postDelayed({ ringTimedOut(id, limit) }, left)

        wakeLock = getSystemService(PowerManager::class.java)
            .newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "byebyesleep:ring")
            .apply { acquire(left + 60_000L) }

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

        // The challenges first, then the sound: open the ring screen now and
        // start the sound once it is showing (at most RingStart.SCREEN_WAIT_MS).
        val userUnlocked = getSystemService(UserManager::class.java).isUserUnlocked
        val overlay = Settings.canDrawOverlays(this)
        if (userUnlocked && overlay) {
            runCatching { startActivity(RingActivity.intent(this, id)) }
                .onFailure { Log.w(TAG, "could not open the ring screen", it) }
        }
        val canOpen = RingStart.canOpenScreen(
            canDrawOverlays = overlay,
            interactive = getSystemService(PowerManager::class.java).isInteractive,
            keyguardLocked = getSystemService(KeyguardManager::class.java).isKeyguardLocked,
        )
        val delay = RingStart.soundDelayMs(canOpen, userUnlocked, redelivered)
        if (delay == 0L) {
            startSound()
        } else {
            soundPending = true
            timeout.postDelayed(soundFallback, delay)
        }
    }

    /** Starts the sound and vibration (once): the ring screen is up, or it took too long. */
    private fun startSound() {
        if (!ringing || player != null || vibrator != null) return
        soundPending = false
        timeout.removeCallbacks(soundFallback)
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
                setVolume(level, level)
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

    private val timeout = android.os.Handler(android.os.Looper.getMainLooper())

    /** The ring limit passed with nobody stopping it: silence, and say so. */
    private fun ringTimedOut(id: Int, minutes: Int) {
        if (!ringing) return
        val nm = getSystemService(NotificationManager::class.java)
        nm.createNotificationChannel(
            NotificationChannel(MISSED_CHANNEL_ID, "Missed alarms", NotificationManager.IMPORTANCE_DEFAULT),
        )
        val time = PrefsAlarmRepository(applicationContext).get(id)
            ?.let { "%02d:%02d ".format(it.hour, it.minute) } ?: ""
        nm.notify(
            MISSED_NOTIFICATION_ID,
            Notification.Builder(this, MISSED_CHANNEL_ID)
                .setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
                .setContentTitle("Missed alarm")
                .setContentText("The ${time}alarm rang for $minutes min and nobody stopped it, so it stopped itself.")
                .setAutoCancel(true)
                .build(),
        )
        RingActivity.closeIfShowing()
        stopRinging()
    }

    private fun stopRinging() {
        timeout.removeCallbacksAndMessages(null)
        ringingAlarmId = null
        ringingAlarmIds = emptySet()
        ringing = false
        soundPending = false
        player?.run { runCatching { stop() }; release() }
        player = null
        vibrator?.cancel()
        vibrator = null
        val state = ringingState()
        state.edit().remove(KEY_PROGRESS).commit()
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

    private fun ringingState() = ringingState(this)

    override fun onDestroy() {
        if (ringing) stopRinging()
        super.onDestroy()
    }

    companion object {
        private const val ACTION_RING = "com.mrgardener.byebyesleep.RING"
        private const val ACTION_STOP = "com.mrgardener.byebyesleep.STOP"
        private const val ACTION_RING_ACTIVITY_GONE = "com.mrgardener.byebyesleep.RING_ACTIVITY_GONE"
        private const val CHANNEL_ID = "alarm_ringing"
        private const val NOTIFICATION_ID = 4242
        private const val KEY_PREVIOUS_VOLUME = "previous_alarm_volume"
        private const val KEY_PROGRESS = "ring_progress"
        private const val ACTION_SET_LEVEL = "com.mrgardener.byebyesleep.SET_LEVEL"
        private const val ACTION_SCREEN_READY = "com.mrgardener.byebyesleep.SCREEN_READY"
        private const val EXTRA_LEVEL = "level"
        private const val TAG = "ByeByeSleep"

        /** Id of the alarm shown on the ring screen (the first one that rang), or null. */
        @Volatile var ringingAlarmId: Int? = null
            private set

        /** Every alarm ringing right now; Snooze applies to all of them. */
        @Volatile var ringingAlarmIds: Set<Int> = emptySet()
            private set

        private const val MISSED_CHANNEL_ID = "missed"
        private const val MISSED_NOTIFICATION_ID = 4712
        private const val EXTRA_FOLLOW_UP = "follow_up"

        fun ringIntent(context: Context, id: Int, followUp: Boolean = false): Intent =
            Intent(context, AlarmService::class.java)
                .setAction(ACTION_RING)
                .putExtra(EXTRA_ALARM_ID, id)
                .putExtra(EXTRA_FOLLOW_UP, followUp)

        /** Marks ringing as stopped immediately, then lets the service clean up. */
        fun stop(context: Context) {
            ringingAlarmId = null
            ringingAlarmIds = emptySet()
            context.startService(Intent(context, AlarmService::class.java).setAction(ACTION_STOP))
        }

        private fun ringingState(context: Context) = context.createDeviceProtectedStorageContext()
            .getSharedPreferences("ringing", MODE_PRIVATE)

        private fun storedProgress(context: Context): RingProgress? =
            ringingState(context).getString(KEY_PROGRESS, null)?.let {
                runCatching { RingProgress.fromJson(org.json.JSONObject(it)) }.getOrNull()
            }

        /** Progress of the alarm ringing now; null when nothing rings or it is stale. */
        fun ringProgress(context: Context): RingProgress? =
            RingProgress.current(storedProgress(context), System.currentTimeMillis(), ringingAlarmId != null)

        fun saveRingProgress(context: Context, progress: RingProgress) {
            if (ringingAlarmId == null) return
            ringingState(context).edit().putString(KEY_PROGRESS, progress.toJson().toString()).commit()
        }

        /** 0.0–1.0 of full alarm volume (quieter during breathers between stages). */
        fun setRingLevel(context: Context, level: Float) {
            if (ringingAlarmId == null) return
            context.startService(
                Intent(context, AlarmService::class.java).setAction(ACTION_SET_LEVEL).putExtra(EXTRA_LEVEL, level),
            )
        }

        /** The ring screen shows the challenges: the sound may start. */
        fun screenReady(context: Context) {
            if (ringingAlarmId == null) return
            context.startService(Intent(context, AlarmService::class.java).setAction(ACTION_SCREEN_READY))
        }

        fun ringActivityGone(context: Context) {
            if (ringingAlarmId == null) return
            context.startService(Intent(context, AlarmService::class.java).setAction(ACTION_RING_ACTIVITY_GONE))
        }
    }
}
