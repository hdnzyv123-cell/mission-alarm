package com.opensource.missionalarm.alarm

import android.app.AlarmManager
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import com.opensource.missionalarm.MainActivity

class AlarmSchedulerModule(private val context: Context) {

    private val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
    private val powerManager = context.getSystemService(Context.POWER_SERVICE) as PowerManager
    private val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

    companion object {
        const val ACTION_TRIGGER_ALARM = "com.opensource.missionalarm.ACTION_TRIGGER_ALARM"
        const val ACTION_WAKEUP_CHECK_PROMPT = "com.opensource.missionalarm.ACTION_WAKEUP_CHECK_PROMPT"
        const val ACTION_WAKEUP_CHECK_TIMEOUT = "com.opensource.missionalarm.ACTION_WAKEUP_CHECK_TIMEOUT"
        const val ACTION_CONFIRM_AWAKE = "com.opensource.missionalarm.ACTION_CONFIRM_AWAKE"

        const val EXTRA_ALARM_ID = "extra_alarm_id"
        const val EXTRA_ALARM_PAYLOAD = "extra_alarm_payload"
    }

    /**
     * Schedules a zero-failure alarm using AlarmManager.setAlarmClock().
     * setAlarmClock() wakes the device from Doze mode ahead of time, grants temporary
     * background launch privileges, and displays the system status-bar alarm icon.
     */
    fun scheduleExactAlarm(alarmId: Int, triggerAtMillis: Long, payloadJson: String) {
        val triggerIntent = Intent(context, AlarmReceiver::class.java).apply {
            action = ACTION_TRIGGER_ALARM
            putExtra(EXTRA_ALARM_ID, alarmId)
            putExtra(EXTRA_ALARM_PAYLOAD, payloadJson)
        }

        val operationPendingIntent = PendingIntent.getBroadcast(
            context,
            alarmId,
            triggerIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val showIntent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra(EXTRA_ALARM_ID, alarmId)
        }
        val showPendingIntent = PendingIntent.getActivity(
            context,
            alarmId,
            showIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val alarmClockInfo = AlarmManager.AlarmClockInfo(triggerAtMillis, showPendingIntent)
        alarmManager.setAlarmClock(alarmClockInfo, operationPendingIntent)
    }

    fun cancelAlarm(alarmId: Int) {
        val triggerIntent = Intent(context, AlarmReceiver::class.java).apply {
            action = ACTION_TRIGGER_ALARM
        }
        val pendingIntent = PendingIntent.getBroadcast(
            context,
            alarmId,
            triggerIntent,
            PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE
        )
        pendingIntent?.let {
            alarmManager.cancel(it)
            it.cancel()
        }
        cancelWakeUpCheck(alarmId)
    }

    /**
     * Schedules the 2-phase Wake-Up Check:
     * Phase 1 (T + delayMinutes): Silent check-in notification asking "Are you awake?"
     * Phase 2 (Phase 1 + 90 seconds): Full-blast alarm re-trigger if user hasn't confirmed.
     */
    fun scheduleWakeUpCheck(alarmId: Int, checkDelayMillis: Long, payloadJson: String) {
        val now = System.currentTimeMillis()
        val promptAt = now + checkDelayMillis
        val retriggerAt = promptAt + 90_000L // 90-second response window

        val promptIntent = Intent(context, AlarmReceiver::class.java).apply {
            action = ACTION_WAKEUP_CHECK_PROMPT
            putExtra(EXTRA_ALARM_ID, alarmId)
            putExtra(EXTRA_ALARM_PAYLOAD, payloadJson)
        }
        val promptPendingIntent = PendingIntent.getBroadcast(
            context,
            alarmId + 100_000,
            promptIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val timeoutIntent = Intent(context, AlarmReceiver::class.java).apply {
            action = ACTION_WAKEUP_CHECK_TIMEOUT
            putExtra(EXTRA_ALARM_ID, alarmId)
            putExtra(EXTRA_ALARM_PAYLOAD, payloadJson)
        }
        val timeoutPendingIntent = PendingIntent.getBroadcast(
            context,
            alarmId + 200_000,
            timeoutIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        alarmManager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, promptAt, promptPendingIntent)
        alarmManager.setAlarmClock(
            AlarmManager.AlarmClockInfo(retriggerAt, timeoutPendingIntent),
            timeoutPendingIntent
        )
    }

    fun cancelWakeUpCheck(alarmId: Int) {
        listOf(
            Pair(alarmId + 100_000, ACTION_WAKEUP_CHECK_PROMPT),
            Pair(alarmId + 200_000, ACTION_WAKEUP_CHECK_TIMEOUT)
        ).forEach { (requestCode, actionName) ->
            val intent = Intent(context, AlarmReceiver::class.java).apply { action = actionName }
            val pi = PendingIntent.getBroadcast(
                context,
                requestCode,
                intent,
                PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE
            )
            pi?.let {
                alarmManager.cancel(it)
                it.cancel()
            }
        }
        notificationManager.cancel(alarmId + 300_000)
    }

    fun getOemPermissionStatus(): Map<String, Boolean> {
        val batteryIgnored = powerManager.isIgnoringBatteryOptimizations(context.packageName)
        val overlayGranted = Settings.canDrawOverlays(context)
        val dndGranted = notificationManager.isNotificationPolicyAccessGranted
        val fullScreenGranted = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            notificationManager.canUseFullScreenIntent()
        } else true
        val exactAlarmGranted = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            alarmManager.canScheduleExactAlarms()
        } else true

        return mapOf(
            "ignoreBatteryOptimizations" to batteryIgnored,
            "systemAlertWindow" to overlayGranted,
            "notificationPolicy" to dndGranted,
            "fullScreenIntent" to fullScreenGranted,
            "exactAlarm" to exactAlarmGranted
        )
    }

    fun requestOemPermission(permissionType: String) {
        val packageUri = Uri.parse("package:${context.packageName}")
        val intent = when (permissionType) {
            "ignoreBatteryOptimizations" -> Intent(
                Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS,
                packageUri
            )
            "systemAlertWindow" -> Intent(
                Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                packageUri
            )
            "notificationPolicy" -> Intent(Settings.ACTION_NOTIFICATION_POLICY_ACCESS_SETTINGS)
            "fullScreenIntent" -> if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                Intent(Settings.ACTION_MANAGE_APP_USE_FULL_SCREEN_INTENT, packageUri)
            } else Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, packageUri)
            else -> Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, packageUri)
        }.apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK
        }
        context.startActivity(intent)
    }
}
