package com.opensource.missionalarm.alarm

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat

class AlarmReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        val alarmId = intent.getIntExtra(AlarmSchedulerModule.EXTRA_ALARM_ID, -1)
        val payloadJson = intent.getStringExtra(AlarmSchedulerModule.EXTRA_ALARM_PAYLOAD) ?: "{}"

        when (intent.action) {
            AlarmSchedulerModule.ACTION_TRIGGER_ALARM,
            AlarmSchedulerModule.ACTION_WAKEUP_CHECK_TIMEOUT -> {
                // Cancel any lingering wake-up check notification and trigger full-blast alarm
                val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                nm.cancel(alarmId + 300_000)

                val serviceIntent = Intent(context, AlarmRingingService::class.java).apply {
                    putExtra(AlarmSchedulerModule.EXTRA_ALARM_ID, alarmId)
                    putExtra(AlarmSchedulerModule.EXTRA_ALARM_PAYLOAD, payloadJson)
                    // If triggered by Wake-Up Check Timeout, force 0s crescendo (instant 100% blast)
                    if (intent.action == AlarmSchedulerModule.ACTION_WAKEUP_CHECK_TIMEOUT) {
                        putExtra(AlarmRingingService.EXTRA_CRESCENDO_SECONDS, 0)
                    }
                }
                ContextCompat.startForegroundService(context, serviceIntent)
            }

            AlarmSchedulerModule.ACTION_WAKEUP_CHECK_PROMPT -> {
                showWakeUpCheckNotification(context, alarmId)
            }

            AlarmSchedulerModule.ACTION_CONFIRM_AWAKE -> {
                AlarmSchedulerModule(context).cancelWakeUpCheck(alarmId)
            }
        }
    }

    private fun showWakeUpCheckNotification(context: Context, alarmId: Int) {
        val channelId = "wakeup_check_channel"
        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                channelId,
                "Wake-Up Check Verification",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                setSound(null, null)
                enableVibration(true)
            }
            nm.createNotificationChannel(channel)
        }

        val confirmIntent = Intent(context, AlarmReceiver::class.java).apply {
            action = AlarmSchedulerModule.ACTION_CONFIRM_AWAKE
            putExtra(AlarmSchedulerModule.EXTRA_ALARM_ID, alarmId)
        }
        val confirmPendingIntent = PendingIntent.getBroadcast(
            context,
            alarmId + 400_000,
            confirmIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val notification = NotificationCompat.Builder(context, channelId)
            .setSmallIcon(android.R.drawable.ic_Dialog_info)
            .setContentTitle("Wake-Up Check: Are you still awake?")
            .setContentText("Tap 'I am awake' within 90s or the alarm will re-trigger at full blast.")
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setOngoing(true)
            .addAction(
                android.R.drawable.checkbox_on_background,
                "I AM AWAKE",
                confirmPendingIntent
            )
            .build()

        nm.notify(alarmId + 300_000, notification)
    }
}
