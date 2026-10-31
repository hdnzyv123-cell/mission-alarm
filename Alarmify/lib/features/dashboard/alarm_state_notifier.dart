import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/background_alarm_scheduler.dart';
import '../../domain/entities/alarm_entity.dart';

class AlarmDashboardState {
  final List<AlarmEntity> alarms;
  final DateTime? nextScheduledTrigger;
  final Duration? timeUntilNextAlarm;
  final OemPermissionState? oemPermissions;

  const AlarmDashboardState({
    this.alarms = const [],
    this.nextScheduledTrigger,
    this.timeUntilNextAlarm,
    this.oemPermissions,
  });

  AlarmDashboardState copyWith({
    List<AlarmEntity>? alarms,
    DateTime? nextScheduledTrigger,
    Duration? timeUntilNextAlarm,
    OemPermissionState? oemPermissions,
  }) {
    return AlarmDashboardState(
      alarms: alarms ?? this.alarms,
      nextScheduledTrigger: nextScheduledTrigger,
      timeUntilNextAlarm: timeUntilNextAlarm,
      oemPermissions: oemPermissions ?? this.oemPermissions,
    );
  }
}

final alarmSchedulerProvider = Provider<BackgroundAlarmScheduler>((ref) {
  return BackgroundAlarmScheduler();
});

final alarmDashboardProvider =
    StateNotifierProvider<AlarmDashboardNotifier, AlarmDashboardState>((ref) {
  final scheduler = ref.watch(alarmSchedulerProvider);
  return AlarmDashboardNotifier(scheduler);
});

class AlarmDashboardNotifier extends StateNotifier<AlarmDashboardState> {
  final BackgroundAlarmScheduler _scheduler;
  Timer? _countdownTimer;

  AlarmDashboardNotifier(this._scheduler) : super(const AlarmDashboardState()) {
    _init();
  }

  Future<void> _init() async {
    final perms = await _scheduler.checkOemPermissions();
    state = state.copyWith(oemPermissions: perms);
    _startLiveCountdownTicker();
  }

  void _startLiveCountdownTicker() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _recalculateNextCountdown();
    });
  }

  void _recalculateNextCountdown() {
    final now = DateTime.now();
    final activeAlarms = state.alarms.where((a) => a.isEnabled).toList();
    if (activeAlarms.isEmpty) {
      state = state.copyWith(
        nextScheduledTrigger: null,
        timeUntilNextAlarm: null,
      );
      return;
    }

    DateTime? earliest;
    for (final alarm in activeAlarms) {
      final trigger = alarm.computeNextTriggerTime(now);
      if (earliest == null || trigger.isBefore(earliest)) {
        earliest = trigger;
      }
    }

    state = state.copyWith(
      nextScheduledTrigger: earliest,
      timeUntilNextAlarm: earliest?.difference(now),
    );
  }

  Future<void> upsertAlarm(AlarmEntity alarm) async {
    final updatedList = [...state.alarms];
    final idx = updatedList.indexWhere((a) => a.id == alarm.id);
    if (idx >= 0) {
      updatedList[idx] = alarm;
    } else {
      updatedList.add(alarm);
    }

    if (alarm.isEnabled) {
      await _scheduler.scheduleAlarm(alarm);
    } else {
      await _scheduler.cancelAlarm(alarm.id);
    }

    state = state.copyWith(alarms: updatedList);
    _recalculateNextCountdown();
  }

  Future<void> toggleAlarm(int id, bool enabled) async {
    final idx = state.alarms.indexWhere((a) => a.id == id);
    if (idx < 0) return;
    final updated = state.alarms[idx].copyWith(isEnabled: enabled);
    await upsertAlarm(updated);
  }

  Future<void> triggerQuickNap(int minutes) async {
    final napAlarm = await _scheduler.scheduleQuickNap(durationMinutes: minutes);
    final updatedList = [
      ...state.alarms.where((a) => a.id != napAlarm.id),
      napAlarm,
    ];
    state = state.copyWith(alarms: updatedList);
    _recalculateNextCountdown();
  }

  Future<void> refreshPermissions() async {
    final perms = await _scheduler.checkOemPermissions();
    state = state.copyWith(oemPermissions: perms);
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }
}
