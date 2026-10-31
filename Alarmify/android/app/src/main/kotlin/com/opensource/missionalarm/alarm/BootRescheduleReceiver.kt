package com.opensource.missionalarm.alarm

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class BootRescheduleReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_LOCKED_BOOT_COMPLETED,
            "android.intent.action.QUICKBOOT_POWERON",
            Intent.ACTION_TIME_SET,
            Intent.ACTION_TIMEZONE_CHANGED,
            Intent.ACTION_MY_PACKAGE_REPLACED -> {
                // Reads persisted active alarms from local storage / SharedPreferences mirror
                // and immediately re-registers them with AlarmManager.setAlarmClock().
                val prefs = context.getSharedPreferences("mission_alarm_boot_cache", Context.MODE_PRIVATE)
                val scheduler = AlarmSchedulerModule(context)
                val activeEntries = prefs.all
                for ((key, value) in activeEntries) {
                    val alarmId = key.toIntOrNull() ?: continue
                    val raw = value as? String ?: continue
                    val parts = raw.split("|", limit = 2)
                    if (parts.size == 2) {
                        val triggerMillis = parts[0].toLongOrNull() ?: continue
                        if (triggerMillis > System.currentTimeMillis()) {
                            scheduler.scheduleExactAlarm(alarmId, triggerMillis, parts[1])
                        }
                    }
                }
            }
        }
    }
}
