import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'domain/entities/alarm_entity.dart';
import 'features/dashboard/alarm_state_notifier.dart';
import 'features/dashboard/home_dashboard_screen.dart';
import 'features/mission_engine/ringing_mission_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: MissionAlarmApp()));
}

class MissionAlarmApp extends ConsumerWidget {
  const MissionAlarmApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'Mission Alarm',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF000000),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00FF9D),
          secondary: Color(0xFF00FF9D),
          surface: Color(0xFF0B0B0B),
        ),
      ),
      home: const HomeDashboardScreen(),
      onGenerateRoute: (settings) {
        if (settings.name == '/ringing') {
          final alarm = settings.arguments as AlarmEntity? ??
              const AlarmEntity(id: 1, hour: 7, minute: 0);
          return MaterialPageRoute(
            builder: (_) => RingingMissionScreen(alarm: alarm),
          );
        }
        return null;
      },
    );
  }
}
