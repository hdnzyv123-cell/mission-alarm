import 'dart:io';
import 'package:flutter/services.dart';
import '../../domain/entities/alarm_entity.dart';

class OemPermissionState {
  final bool ignoreBatteryOptimizations;
  final bool systemAlertWindow;
  final bool notificationPolicy;
  final bool fullScreenIntent;
  final bool exactAlarm;

  const OemPermissionState({
    required this.ignoreBatteryOptimizations,
    required this.systemAlertWindow,
    required this.notificationPolicy,
    required this.fullScreenIntent,
    required this.exactAlarm,
  });

  bool get allCriticalGranted =>
      ignoreBatteryOptimizations &&
      systemAlertWindow &&
      notificationPolicy &&
      fullScreenIntent &&
      exactAlarm;

  factory OemPermissionState.fromMap(Map<dynamic, dynamic> map) {
    return OemPermissionState(
      ignoreBatteryOptimizations: map['ignoreBatteryOptimizations'] ?? false,
      systemAlertWindow: map['systemAlertWindow'] ?? false,
      notificationPolicy: map['notificationPolicy'] ?? false,
      fullScreenIntent: map['fullScreenIntent'] ?? true,
      exactAlarm: map['exactAlarm'] ?? true,
    );
  }
}

class BackgroundAlarmScheduler {
  static const MethodChannel _channel =
      MethodChannel('com.opensource.missionalarm/scheduler');

  /// Schedules the next exact alarm execution using Android's AlarmManager.setAlarmClock()
  /// or iOS UNNotificationSound.criticalSoundNamed().
  Future<DateTime> scheduleAlarm(AlarmEntity alarm) async {
    final now = DateTime.now();
    final nextTrigger = alarm.computeNextTriggerTime(now);

    if (Platform.isAndroid) {
      await _channel.invokeMethod('scheduleExactAlarm', {
        'alarmId': alarm.id,
        'triggerAtMillis': nextTrigger.millisecondsSinceEpoch,
        'payloadJson': alarm.toPayloadJson(),
      });
    } else if (Platform.isIOS) {
      await _channel.invokeMethod('scheduleIosCriticalAlarm', {
        'alarmId': alarm.id,
        'hour': alarm.hour,
        'minute': alarm.minute,
        'soundFile': alarm.ringtoneUri.split('/').last,
      });
    }

    return nextTrigger;
  }

  /// Schedules a 1-tap Quick Nap / Power Nap (e.g., 15m, 30m, 45m from now).
  Future<AlarmEntity> scheduleQuickNap({
    required int durationMinutes,
    MissionConfig mission = const MissionConfig(type: MissionType.math),
  }) async {
    final target = DateTime.now().add(Duration(minutes: durationMinutes));
    final napAlarm = AlarmEntity(
      id: 900000 + durationMinutes,
      hour: target.hour,
      minute: target.minute,
      label: 'Power Nap ($durationMinutes min)',
      isQuickNap: true,
      mission: mission,
    );
    await scheduleAlarm(napAlarm);
    return napAlarm;
  }

  /// Enforces Snooze Guardrails: rejects snooze if currentSnoozeUsed >= maxSnoozeCount.
  Future<bool> triggerSnooze(AlarmEntity alarm) async {
    if (alarm.currentSnoozeUsed >= alarm.antiCheat.maxSnoozeCount) {
      return false;
    }

    await stopRingingService();

    final snoozeTarget = DateTime.now().add(
      Duration(minutes: alarm.antiCheat.snoozeDurationMinutes),
    );
    final updatedAlarm = alarm.copyWith(
      currentSnoozeUsed: alarm.currentSnoozeUsed + 1,
    );

    if (Platform.isAndroid) {
      await _channel.invokeMethod('scheduleExactAlarm', {
        'alarmId': updatedAlarm.id,
        'triggerAtMillis': snoozeTarget.millisecondsSinceEpoch,
        'payloadJson': updatedAlarm.toPayloadJson(),
      });
    }
    return true;
  }

  /// Finalizes alarm dismissal ONLY after MissionExecutionHandler verifies completion.
  /// Automatically arms the Wake-Up Check (3-5 min silent prompt + 90s full-blast fallback).
  Future<void> completeMissionAndDismiss(AlarmEntity alarm) async {
    await stopRingingService();

    if (alarm.antiCheat.wakeUpCheckEnabled && Platform.isAndroid) {
      final delayMillis =
          alarm.antiCheat.wakeUpCheckDelayMinutes * 60 * 1000;
      await _channel.invokeMethod('scheduleWakeUpCheck', {
        'alarmId': alarm.id,
        'delayMillis': delayMillis,
        'payloadJson': alarm.toPayloadJson(),
      });
    }

    // If recurring weekday alarm, immediately schedule the next occurrence
    if (alarm.repeatWeekdays.isNotEmpty && !alarm.isQuickNap) {
      await scheduleAlarm(alarm.copyWith(currentSnoozeUsed: 0));
    }
  }

  Future<void> cancelAlarm(int alarmId) async {
    await _channel.invokeMethod('cancelAlarm', {'alarmId': alarmId});
  }

  Future<void> stopRingingService() async {
    await _channel.invokeMethod('stopRingingService');
  }

  Future<OemPermissionState> checkOemPermissions() async {
    if (!Platform.isAndroid) {
      return const OemPermissionState(
        ignoreBatteryOptimizations: true,
        systemAlertWindow: true,
        notificationPolicy: true,
        fullScreenIntent: true,
        exactAlarm: true,
      );
    }
    final raw = await _channel.invokeMethod<Map<dynamic, dynamic>>(
      'getOemPermissionStatus',
    );
    return OemPermissionState.fromMap(raw ?? {});
  }

  Future<void> requestOemPermission(String permissionType) async {
    if (Platform.isAndroid) {
      await _channel.invokeMethod('requestOemPermission', {
        'permissionType': permissionType,
      });
    } else if (Platform.isIOS) {
      await _channel.invokeMethod('requestCriticalAlertPermission');
    }
  }
}
