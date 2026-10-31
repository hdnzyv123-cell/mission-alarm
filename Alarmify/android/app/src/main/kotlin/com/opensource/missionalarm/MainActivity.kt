package com.opensource.missionalarm

import android.app.KeyguardManager
import android.content.Context
import android.content.Intent
import android.media.AudioManager
import android.os.Build
import android.os.Bundle
import android.view.KeyEvent
import android.view.WindowManager
import com.opensource.missionalarm.alarm.AlarmRingingService
import com.opensource.missionalarm.alarm.AlarmSchedulerModule
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val CHANNEL = "com.opensource.missionalarm/scheduler"
    private lateinit var schedulerModule: AlarmSchedulerModule
    private lateinit var audioManager: AudioManager

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableLockScreenBypassFlags()
        audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
        schedulerModule = AlarmSchedulerModule(applicationContext)
    }

    private fun enableLockScreenBypassFlags() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
            val keyguardManager = getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
            keyguardManager.requestDismissKeyguard(this, null)
        } else {
            @Suppress("DEPRECATION")
            window.addFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
                WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON or
                WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD
            )
        }
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
    }

    /**
     * Hardware Volume Key Lock:
     * Intercepts physical Volume Down / Mute key presses while an alarm is ringing
     * and forces STREAM_ALARM to stay clamped at 100%.
     */
    override fun dispatchKeyEvent(event: KeyEvent): Boolean {
        if (AlarmRingingService.isRinging) {
            when (event.keyCode) {
                KeyEvent.KEYCODE_VOLUME_DOWN,
                KeyEvent.KEYCODE_VOLUME_UP,
                KeyEvent.KEYCODE_VOLUME_MUTE -> {
                    val maxVol = audioManager.getStreamMaxVolume(AudioManager.STREAM_ALARM)
                    audioManager.setStreamVolume(AudioManager.STREAM_ALARM, maxVol, 0)
                    return true // Consume hardware key event
                }
            }
        }
        return super.dispatchKeyEvent(event)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "scheduleExactAlarm" -> {
                    val alarmId = call.argument<Int>("alarmId")!!
                    val triggerAtMillis = call.argument<Number>("triggerAtMillis")!!.toLong()
                    val payloadJson = call.argument<String>("payloadJson") ?: "{}"
                    schedulerModule.scheduleExactAlarm(alarmId, triggerAtMillis, payloadJson)
                    result.success(true)
                }
                "cancelAlarm" -> {
                    val alarmId = call.argument<Int>("alarmId")!!
                    schedulerModule.cancelAlarm(alarmId)
                    result.success(true)
                }
                "stopRingingService" -> {
                    stopService(Intent(applicationContext, AlarmRingingService::class.java))
                    result.success(true)
                }
                "scheduleWakeUpCheck" -> {
                    val alarmId = call.argument<Int>("alarmId")!!
                    val delayMillis = call.argument<Number>("delayMillis")!!.toLong()
                    val payloadJson = call.argument<String>("payloadJson") ?: "{}"
                    schedulerModule.scheduleWakeUpCheck(alarmId, delayMillis, payloadJson)
                    result.success(true)
                }
                "confirmAwake" -> {
                    val alarmId = call.argument<Int>("alarmId")!!
                    schedulerModule.cancelWakeUpCheck(alarmId)
                    result.success(true)
                }
                "getOemPermissionStatus" -> {
                    result.success(schedulerModule.getOemPermissionStatus())
                }
                "requestOemPermission" -> {
                    val permissionType = call.argument<String>("permissionType")!!
                    schedulerModule.requestOemPermission(permissionType)
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }
}
