import 'dart:convert';

enum MissionType { none, math, barcode, shake, typing, memory }

enum MathDifficulty { easy, medium, hard }

class MissionConfig {
  final MissionType type;
  final MathDifficulty mathDifficulty;
  final int problemCount; // 1..5 for Math/Typing
  final String? registeredBarcode; // Target barcode/QR payload
  final int shakeTargetCount; // 30..100 shakes
  final double shakeThresholdG; // Default 2.3G net acceleration
  final int memoryGridRows; // 3 or 4
  final int memoryGridCols; // 4

  const MissionConfig({
    this.type = MissionType.math,
    this.mathDifficulty = MathDifficulty.medium,
    this.problemCount = 3,
    this.registeredBarcode,
    this.shakeTargetCount = 50,
    this.shakeThresholdG = 2.3,
    this.memoryGridRows = 4,
    this.memoryGridCols = 4,
  });

  Map<String, dynamic> toJson() => {
        'type': type.name,
        'mathDifficulty': mathDifficulty.name,
        'problemCount': problemCount,
        'registeredBarcode': registeredBarcode,
        'shakeTargetCount': shakeTargetCount,
        'shakeThresholdG': shakeThresholdG,
        'memoryGridRows': memoryGridRows,
        'memoryGridCols': memoryGridCols,
      };

  factory MissionConfig.fromJson(Map<String, dynamic> json) => MissionConfig(
        type: MissionType.values.byName(json['type'] ?? 'math'),
        mathDifficulty: MathDifficulty.values.byName(json['mathDifficulty'] ?? 'medium'),
        problemCount: json['problemCount'] ?? 3,
        registeredBarcode: json['registeredBarcode'],
        shakeTargetCount: json['shakeTargetCount'] ?? 50,
        shakeThresholdG: (json['shakeThresholdG'] ?? 2.3).toDouble(),
        memoryGridRows: json['memoryGridRows'] ?? 4,
        memoryGridCols: json['memoryGridCols'] ?? 4,
      );
}

class AntiCheatConfig {
  final bool volumeLock;
  final int crescendoSeconds; // 0 = instant 100%, e.g., 30 = 30s ramp
  final int maxSnoozeCount; // 0..3
  final int snoozeDurationMinutes; // e.g., 5m
  final bool wakeUpCheckEnabled;
  final int wakeUpCheckDelayMinutes; // 3..5 minutes after dismissal

  const AntiCheatConfig({
    this.volumeLock = true,
    this.crescendoSeconds = 30,
    this.maxSnoozeCount = 2,
    this.snoozeDurationMinutes = 5,
    this.wakeUpCheckEnabled = true,
    this.wakeUpCheckDelayMinutes = 4,
  });

  Map<String, dynamic> toJson() => {
        'volumeLock': volumeLock,
        'crescendoSeconds': crescendoSeconds,
        'maxSnoozeCount': maxSnoozeCount,
        'snoozeDurationMinutes': snoozeDurationMinutes,
        'wakeUpCheckEnabled': wakeUpCheckEnabled,
        'wakeUpCheckDelayMinutes': wakeUpCheckDelayMinutes,
      };

  factory AntiCheatConfig.fromJson(Map<String, dynamic> json) => AntiCheatConfig(
        volumeLock: json['volumeLock'] ?? true,
        crescendoSeconds: json['crescendoSeconds'] ?? 30,
        maxSnoozeCount: json['maxSnoozeCount'] ?? 2,
        snoozeDurationMinutes: json['snoozeDurationMinutes'] ?? 5,
        wakeUpCheckEnabled: json['wakeUpCheckEnabled'] ?? true,
        wakeUpCheckDelayMinutes: json['wakeUpCheckDelayMinutes'] ?? 4,
      );
}

class AlarmEntity {
  final int id;
  final int hour;
  final int minute;
  final String label;
  final bool isEnabled;
  final List<int> repeatWeekdays; // 1 (Mon) .. 7 (Sun), empty = one-shot
  final String ringtoneUri;
  final MissionConfig mission;
  final AntiCheatConfig antiCheat;
  final int currentSnoozeUsed;
  final bool isQuickNap;

  const AlarmEntity({
    required this.id,
    required this.hour,
    required this.minute,
    this.label = 'Morning Mission',
    this.isEnabled = true,
    this.repeatWeekdays = const [],
    this.ringtoneUri = 'assets/sounds/siren_110db.mp3',
    this.mission = const MissionConfig(),
    this.antiCheat = const AntiCheatConfig(),
    this.currentSnoozeUsed = 0,
    this.isQuickNap = false,
  });

  AlarmEntity copyWith({
    int? hour,
    int? minute,
    String? label,
    bool? isEnabled,
    List<int>? repeatWeekdays,
    String? ringtoneUri,
    MissionConfig? mission,
    AntiCheatConfig? antiCheat,
    int? currentSnoozeUsed,
  }) {
    return AlarmEntity(
      id: id,
      hour: hour ?? this.hour,
      minute: minute ?? this.minute,
      label: label ?? this.label,
      isEnabled: isEnabled ?? this.isEnabled,
      repeatWeekdays: repeatWeekdays ?? this.repeatWeekdays,
      ringtoneUri: ringtoneUri ?? this.ringtoneUri,
      mission: mission ?? this.mission,
      antiCheat: antiCheat ?? this.antiCheat,
      currentSnoozeUsed: currentSnoozeUsed ?? this.currentSnoozeUsed,
      isQuickNap: isQuickNap,
    );
  }

  DateTime computeNextTriggerTime(DateTime from) {
    DateTime candidate = DateTime(from.year, from.month, from.day, hour, minute);
    if (!candidate.isAfter(from)) {
      candidate = candidate.add(const Duration(days: 1));
    }
    if (repeatWeekdays.isEmpty) return candidate;

    while (!repeatWeekdays.contains(candidate.weekday)) {
      candidate = candidate.add(const Duration(days: 1));
    }
    return candidate;
  }

  String toPayloadJson() => jsonEncode({
        'id': id,
        'hour': hour,
        'minute': minute,
        'label': label,
        'ringtoneUri': ringtoneUri,
        'mission': mission.toJson(),
        'antiCheat': antiCheat.toJson(),
        'currentSnoozeUsed': currentSnoozeUsed,
      });
}
