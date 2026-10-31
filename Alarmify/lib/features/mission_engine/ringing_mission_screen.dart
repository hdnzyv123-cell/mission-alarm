import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../domain/entities/alarm_entity.dart';
import '../dashboard/alarm_state_notifier.dart';
import 'mission_execution_handler.dart';

class RingingMissionScreen extends ConsumerStatefulWidget {
  final AlarmEntity alarm;
  const RingingMissionScreen({super.key, required this.alarm});

  @override
  ConsumerState<RingingMissionScreen> createState() =>
      _RingingMissionScreenState();
}

class _RingingMissionScreenState extends ConsumerState<RingingMissionScreen> {
  late final StateNotifierProvider<MissionExecutionHandler, MissionRuntimeState>
      _missionProvider;
  final TextEditingController _inputController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _missionProvider =
        StateNotifierProvider<MissionExecutionHandler, MissionRuntimeState>(
      (ref) => MissionExecutionHandler(widget.alarm.mission),
    );
  }

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final missionState = ref.watch(_missionProvider);
    final handler = ref.read(_missionProvider.notifier);

    ref.listen<MissionRuntimeState>(_missionProvider, (previous, next) async {
      if (next.isCompleted && !(previous?.isCompleted ?? false)) {
        await ref
            .read(alarmSchedulerProvider)
            .completeMissionAndDismiss(widget.alarm);
        if (context.mounted) Navigator.of(context).pop();
      }
    });

    // Block back navigation and standard swipe-to-dismiss gestures
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: const Color(0xFF000000),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LinearProgressIndicator(
                  value: missionState.progressFraction,
                  backgroundColor: const Color(0xFF1A1A1A),
                  color: const Color(0xFF00FF9D),
                  minHeight: 8,
                ),
                const SizedBox(height: 20),
                Text(
                  'MISSION: ${widget.alarm.mission.type.name.toUpperCase()} '
                  '(${missionState.currentStep}/${missionState.totalSteps})',
                  style: const TextStyle(
                    color: Color(0xFF00FF9D),
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
                if (missionState.errorMessage != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    missionState.errorMessage!,
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                ],
                const SizedBox(height: 24),
                Expanded(
                  child: _buildActiveChallengeView(missionState, handler),
                ),
                if (widget.alarm.currentSnoozeUsed <
                    widget.alarm.antiCheat.maxSnoozeCount)
                  TextButton(
                    onPressed: () async {
                      final ok = await ref
                          .read(alarmSchedulerProvider)
                          .triggerSnooze(widget.alarm);
                      if (ok && context.mounted) Navigator.of(context).pop();
                    },
                    child: Text(
                      'Snooze (${widget.alarm.antiCheat.maxSnoozeCount - widget.alarm.currentSnoozeUsed} left)',
                      style: const TextStyle(color: Color(0xFF757575)),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActiveChallengeView(
    MissionRuntimeState state,
    MissionExecutionHandler handler,
  ) {
    switch (state.config.type) {
      case MissionType.math:
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              state.currentMathProblem?.expression ?? '',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 44,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _inputController,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white, fontSize: 28),
              textAlign: TextAlign.center,
              decoration: const InputDecoration(
                hintText: 'Enter solution',
                hintStyle: TextStyle(color: Color(0xFF444444)),
              ),
              onSubmitted: (val) {
                handler.submitMathAnswer(val);
                _inputController.clear();
              },
            ),
          ],
        );

      case MissionType.barcode:
        return ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: MobileScanner(
            onDetect: (capture) {
              for (final barcode in capture.barcodes) {
                final raw = barcode.rawValue;
                if (raw != null) handler.verifyScannedBarcode(raw);
              }
            },
          ),
        );

      case MissionType.shake:
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${state.shakesCompleted} / ${state.config.shakeTargetCount}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 56,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Current Force: ${state.currentGForce.toStringAsFixed(1)} G '
              '(Target ≥ ${state.config.shakeThresholdG} G)',
              style: const TextStyle(color: Color(0xFF888888)),
            ),
          ],
        );

      case MissionType.typing:
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              state.targetSentence,
              style: const TextStyle(color: Colors.white, fontSize: 20),
            ),
            const SizedBox(height: 16),
            TextField(
              style: const TextStyle(color: Color(0xFF00FF9D), fontSize: 18),
              onChanged: handler.updateTypingProgress,
              decoration: const InputDecoration(
                hintText: 'Type the exact sentence above with zero typos...',
                hintStyle: TextStyle(color: Color(0xFF444444)),
              ),
            ),
          ],
        );

      case MissionType.memory:
        return GridView.builder(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: state.config.memoryGridCols,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
          ),
          itemCount: state.memoryCards.length,
          itemBuilder: (context, idx) {
            final card = state.memoryCards[idx];
            final revealed = card.isFlipped || card.isMatched;
            return GestureDetector(
              onTap: () => handler.flipMemoryCard(idx),
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: revealed
                      ? const Color(0xFF00FF9D).withOpacity(0.18)
                      : const Color(0xFF121212),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: revealed
                        ? const Color(0xFF00FF9D)
                        : const Color(0xFF262626),
                  ),
                ),
                child: Text(
                  revealed ? card.symbol : '?',
                  style: const TextStyle(fontSize: 28, color: Colors.white),
                ),
              ),
            );
          },
        );

      case MissionType.none:
        return const SizedBox.shrink();
    }
  }
}
