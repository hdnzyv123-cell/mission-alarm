import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/alarm_entity.dart';
import '../mission_engine/ringing_mission_screen.dart';
import 'alarm_edit_sheet.dart';
import 'alarm_state_notifier.dart';

class HomeDashboardScreen extends ConsumerWidget {
  const HomeDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboard = ref.watch(alarmDashboardProvider);
    final notifier = ref.read(alarmDashboardProvider.notifier);

    return Scaffold(
      backgroundColor: const Color(0xFF000000), // True AMOLED Black
      appBar: AppBar(
        backgroundColor: const Color(0xFF000000),
        elevation: 0,
        title: const Text(
          'MISSION ALARM',
          style: TextStyle(
            color: Color(0xFF00FF9D),
            fontWeight: FontWeight.w900,
            letterSpacing: 2.0,
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF00FF9D),
        foregroundColor: Colors.black,
        onPressed: () async {
          final created = await showModalBottomSheet<AlarmEntity>(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (_) => const AlarmEditSheet(),
          );
          if (created != null) {
            await notifier.upsertAlarm(created);
          }
        },
        icon: const Icon(Icons.add_alarm),
        label: const Text(
          'YENİ ALARM',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: Column(
        children: [
          if (dashboard.oemPermissions != null &&
              !dashboard.oemPermissions!.allCriticalGranted)
            _OemPermissionBanner(
              onFixTap: () => ref
                  .read(alarmSchedulerProvider)
                  .requestOemPermission('ignoreBatteryOptimizations'),
            ),
          _LiveCountdownHeader(remaining: dashboard.timeUntilNextAlarm),
          _QuickNapPresetBar(onSelectMinutes: notifier.triggerQuickNap),
          const Divider(color: Color(0xFF1A1A1A), height: 24),
          Expanded(
            child: dashboard.alarms.isEmpty
                ? const Center(
                    child: Text(
                      'Henüz alarm yok.\nSağ alttaki "YENİ ALARM" butonuna dokunun.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Color(0xFF666666)),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: dashboard.alarms.length,
                    itemBuilder: (context, index) {
                      final alarm = dashboard.alarms[index];
                      return _AlarmCard(
                        alarm: alarm,
                        onToggle: (val) => notifier.toggleAlarm(alarm.id, val),
                        onTestMission: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => RingingMissionScreen(alarm: alarm),
                            ),
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _LiveCountdownHeader extends StatelessWidget {
  final Duration? remaining;
  const _LiveCountdownHeader({required this.remaining});

  @override
  Widget build(BuildContext context) {
    final text = remaining == null
        ? 'Aktif alarm planlanmadı'
        : '${remaining!.inHours}s '
            '${remaining!.inMinutes.remainder(60)}dk '
            '${remaining!.inSeconds.remainder(60)}sn sonra çalacak';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'SONRAKİ GÖREV ALARMI',
            style: TextStyle(
              color: Color(0xFF757575),
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickNapPresetBar extends StatelessWidget {
  final ValueChanged<int> onSelectMinutes;
  const _QuickNapPresetBar({required this.onSelectMinutes});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [15, 30, 45].map((mins) {
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF00FF9D),
                  side: const BorderSide(color: Color(0xFF222222)),
                  backgroundColor: const Color(0xFF0B0B0B),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: () => onSelectMinutes(mins),
                icon: const Icon(Icons.bolt, size: 16),
                label: Text('+${mins}dk Şekerleme'),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _AlarmCard extends StatelessWidget {
  final AlarmEntity alarm;
  final ValueChanged<bool> onToggle;
  final VoidCallback onTestMission;

  const _AlarmCard({
    required this.alarm,
    required this.onToggle,
    required this.onTestMission,
  });

  @override
  Widget build(BuildContext context) {
    final timeStr =
        '${alarm.hour.toString().padLeft(2, '0')}:${alarm.minute.toString().padLeft(2, '0')}';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF0B0B0B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: alarm.isEnabled
              ? const Color(0xFF00FF9D).withOpacity(0.35)
              : const Color(0xFF1A1A1A),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                timeStr,
                style: TextStyle(
                  color:
                      alarm.isEnabled ? Colors.white : const Color(0xFF555555),
                  fontSize: 38,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${alarm.label} • Görev: ${alarm.mission.type.name.toUpperCase()}',
                style: const TextStyle(color: Color(0xFF888888), fontSize: 13),
              ),
              TextButton.icon(
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  foregroundColor: const Color(0xFF00FF9D),
                ),
                onPressed: onTestMission,
                icon: const Icon(Icons.play_arrow, size: 16),
                label: const Text('Görevi Şimdi Test Et'),
              ),
            ],
          ),
          Switch.adaptive(
            value: alarm.isEnabled,
            activeColor: const Color(0xFF00FF9D),
            onChanged: onToggle,
          ),
        ],
      ),
    );
  }
}

class _OemPermissionBanner extends StatelessWidget {
  final VoidCallback onFixTap;
  const _OemPermissionBanner({required this.onFixTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF2B1111),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.redAccent),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Kritik arka plan ve kilit ekranı izinleri eksik. Onaylamak için dokunun.',
              style: TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
          TextButton(
            onPressed: onFixTap,
            child:
                const Text('İZİN VER', style: TextStyle(color: Color(0xFF00FF9D))),
          ),
        ],
      ),
    );
  }
}
