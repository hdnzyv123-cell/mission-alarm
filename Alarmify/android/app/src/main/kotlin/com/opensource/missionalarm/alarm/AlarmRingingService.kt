package com.opensource.missionalarm.alarm

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.database.ContentObserver
import android.media.AudioAttributes
import android.media.AudioManager
import android.media.MediaPlayer
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.provider.Settings
import androidx.core.app.NotificationCompat
import com.opensource.missionalarm.MainActivity
import kotlin.math.min

class AlarmRingingService : Service() {

    companion object {
        const val CHANNEL_ID = "mission_alarm_critical_channel"
        const val NOTIFICATION_ID = 9001
        const val EXTRA_CRESCENDO_SECONDS = "extra_crescendo_seconds"
        const val EXTRA_RINGTONE_URI = "extra_ringtone_uri"
        const val EXTRA_VOLUME_LOCK = "extra_volume_lock"
        var isRinging: Boolean = false
            private set
    }

    private var wakeLock: PowerManager.WakeLock? = null
    private var mediaPlayer: MediaPlayer? = null
    private var vibrator: Vibrator? = null
    private lateinit var audioManager: AudioManager
    private val mainHandler = Handler(Looper.getMainLooper())
    private var volumeObserver: ContentObserver? = null

    private var targetMaxVolume: Int = 15
    private var currentAllowedVolume: Int = 15
    private var volumeLockEnabled: Boolean = true

    private val crescendoRunnable = object : Runnable {
        var elapsedTicks = 0
        var totalTicks = 1
        override fun run() {
            elapsedTicks++
            val fraction = min(1.0f, elapsedTicks.toFloat() / totalTicks.toFloat())
            currentAllowedVolume = (targetMaxVolume * fraction).toInt().coerceAtLeast(1)
            audioManager.setStreamVolume(AudioManager.STREAM_ALARM, currentAllowedVolume, 0)
            mediaPlayer?.setVolume(fraction, fraction)

            if (elapsedTicks < totalTicks) {
                mainHandler.postDelayed(this, 1000L)
            }
        }
    }

    override fun onCreate() {
        super.onCreate()
        audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
        targetMaxVolume = audioManager.getStreamMaxVolume(AudioManager.STREAM_ALARM)
        createCriticalNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val alarmId = intent?.getIntExtra(AlarmSchedulerModule.EXTRA_ALARM_ID, -1) ?: -1
        val payloadJson = intent?.getStringExtra(AlarmSchedulerModule.EXTRA_ALARM_PAYLOAD) ?: "{}"
        val crescendoSeconds = intent?.getIntExtra(EXTRA_CRESCENDO_SECONDS, 0) ?: 0
        val ringtoneUri = intent?.getStringExtra(EXTRA_RINGTONE_URI)
        volumeLockEnabled = intent?.getBooleanExtra(EXTRA_VOLUME_LOCK, true) ?: true

        acquireWakeLock()
        startForeground(NOTIFICATION_ID, buildFullScreenNotification(alarmId, payloadJson))
        isRinging = true

        enforceVolumeAndStartPlayback(ringtoneUri, crescendoSeconds)
        startVibration()
        registerVolumeGuardObserver()

        return START_STICKY
    }

    private fun acquireWakeLock() {
        val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
        wakeLock = powerManager.newWakeLock(
            PowerManager.PARTIAL_WAKE_LOCK or PowerManager.ACQUIRE_CAUSES_WAKEUP,
            "MissionAlarm::CriticalRingingWakeLock"
        ).apply {
            acquire(30 * 60 * 1000L) // 30-minute safety cap
        }
    }

    private fun enforceVolumeAndStartPlayback(ringtonePath: String?, crescendoSeconds: Int) {
        mainHandler.removeCallbacks(crescendoRunnable)

        if (crescendoSeconds > 0) {
            currentAllowedVolume = 1
            audioManager.setStreamVolume(AudioManager.STREAM_ALARM, currentAllowedVolume, 0)
        } else {
            currentAllowedVolume = targetMaxVolume
            audioManager.setStreamVolume(AudioManager.STREAM_ALARM, targetMaxVolume, 0)
        }

        mediaPlayer?.release()
        mediaPlayer = MediaPlayer().apply {
            setAudioAttributes(
                AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_ALARM)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .build()
            )
            val uri = if (!ringtonePath.isNullOrBlank()) {
                Uri.parse(ringtonePath)
            } else {
                Settings.System.DEFAULT_ALARM_ALERT_URI
            }
            setDataSource(applicationContext, uri)
            isLooping = true
            prepare()
            val initialVol = if (crescendoSeconds > 0) 0.05f else 1.0f
            setVolume(initialVol, initialVol)
            start()
        }

        if (crescendoSeconds > 0) {
            crescendoRunnable.elapsedTicks = 0
            crescendoRunnable.totalTicks = crescendoSeconds
            mainHandler.postDelayed(crescendoRunnable, 1000L)
        }
    }

    /**
     * Watches Settings.System.CONTENT_URI for any attempt to lower STREAM_ALARM via
     * system sliders, Bluetooth controls, or hardware keys, immediately clamping it back.
     */
    private fun registerVolumeGuardObserver() {
        if (!volumeLockEnabled) return
        volumeObserver = object : ContentObserver(mainHandler) {
            override fun onChange(selfChange: Boolean) {
                val current = audioManager.getStreamVolume(AudioManager.STREAM_ALARM)
                if (current < currentAllowedVolume) {
                    audioManager.setStreamVolume(AudioManager.STREAM_ALARM, currentAllowedVolume, 0)
                }
            }
        }
        contentResolver.registerContentObserver(
            Settings.System.CONTENT_URI,
            true,
            volumeObserver!!
        )
    }

    private fun startVibration() {
        vibrator = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val vm = getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager
            vm.defaultVibrator
        } else {
            @Suppress("DEPRECATION")
            getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
        }
        val timings = longArrayOf(0, 600, 400, 600)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            vibrator?.vibrate(VibrationEffect.createWaveform(timings, 0))
        } else {
            @Suppress("DEPRECATION")
            vibrator?.vibrate(timings, 0)
        }
    }

    private fun buildFullScreenNotification(alarmId: Int, payloadJson: String): Notification {
        val fullScreenIntent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                    Intent.FLAG_ACTIVITY_CLEAR_TOP or
                    Intent.FLAG_ACTIVITY_SINGLE_TOP
            putExtra(AlarmSchedulerModule.EXTRA_ALARM_ID, alarmId)
            putExtra(AlarmSchedulerModule.EXTRA_ALARM_PAYLOAD, payloadJson)
            putExtra("route", "/ringing")
        }

        val fullScreenPendingIntent = PendingIntent.getActivity(
            this,
            alarmId,
            fullScreenIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
            .setContentTitle("MISSION ALARM ACTIVE")
            .setContentText("Complete your mission to dismiss the alarm.")
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setOngoing(true)
            .setAutoCancel(false)
            .setFullScreenIntent(fullScreenPendingIntent, true)
            .build()
    }

    private fun createCriticalNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Critical Mission Alarms",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Full-screen lockscreen bypass channel for Mission Alarm"
                setBypassDnd(true)
                lockscreenVisibility = Notification.VISIBILITY_PUBLIC
                setSound(null, null) // Handled directly by MediaPlayer in Service
            }
            val nm = getSystemService(NotificationManager::class.java)
            nm.createNotificationChannel(channel)
        }
    }

    override fun onDestroy() {
        isRinging = false
        mainHandler.removeCallbacks(crescendoRunnable)
        volumeObserver?.let { contentResolver.unregisterContentObserver(it) }
        mediaPlayer?.stop()
        mediaPlayer?.release()
        mediaPlayer = null
        vibrator?.cancel()
        if (wakeLock?.isHeld == true) {
            wakeLock?.release()
        }
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null
}
