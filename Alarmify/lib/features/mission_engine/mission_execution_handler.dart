import 'dart:async';
import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sensors_plus/sensors_plus.dart';
import '../../domain/entities/alarm_entity.dart';

class MathProblem {
  final String expression;
  final int answer;
  const MathProblem({required this.expression, required this.answer});
}

class MemoryCardItem {
  final int id;
  final String symbol;
  final bool isFlipped;
  final bool isMatched;

  const MemoryCardItem({
    required this.id,
    required this.symbol,
    this.isFlipped = false,
    this.isMatched = false,
  });

  MemoryCardItem copyWith({bool? isFlipped, bool? isMatched}) => MemoryCardItem(
        id: id,
        symbol: symbol,
        isFlipped: isFlipped ?? this.isFlipped,
        isMatched: isMatched ?? this.isMatched,
      );
}

class MissionRuntimeState {
  final MissionConfig config;
  final bool isCompleted;
  final int currentStep;
  final int totalSteps;
  final String? errorMessage;

  // Math State
  final MathProblem? currentMathProblem;

  // Shake State
  final int shakesCompleted;
  final double currentGForce;

  // Typing State
  final String targetSentence;
  final String currentTypedInput;

  // Memory Tile State
  final List<MemoryCardItem> memoryCards;
  final List<int> selectedCardIndices;
  final bool isBoardLocked;

  const MissionRuntimeState({
    required this.config,
    this.isCompleted = false,
    this.currentStep = 1,
    this.totalSteps = 1,
    this.errorMessage,
    this.currentMathProblem,
    this.shakesCompleted = 0,
    this.currentGForce = 0.0,
    this.targetSentence = '',
    this.currentTypedInput = '',
    this.memoryCards = const [],
    this.selectedCardIndices = const [],
    this.isBoardLocked = false,
  });

  double get progressFraction {
    switch (config.type) {
      case MissionType.none:
        return 1.0;
      case MissionType.math:
      case MissionType.typing:
        return (currentStep - 1) / totalSteps;
      case MissionType.barcode:
        return isCompleted ? 1.0 : 0.0;
      case MissionType.shake:
        return (shakesCompleted / config.shakeTargetCount).clamp(0.0, 1.0);
      case MissionType.memory:
        if (memoryCards.isEmpty) return 0.0;
        final matched = memoryCards.where((c) => c.isMatched).length;
        return matched / memoryCards.length;
    }
  }

  MissionRuntimeState copyWith({
    bool? isCompleted,
    int? currentStep,
    int? totalSteps,
    String? errorMessage,
    MathProblem? currentMathProblem,
    int? shakesCompleted,
    double? currentGForce,
    String? targetSentence,
    String? currentTypedInput,
    List<MemoryCardItem>? memoryCards,
    List<int>? selectedCardIndices,
    bool? isBoardLocked,
  }) {
    return MissionRuntimeState(
      config: config,
      isCompleted: isCompleted ?? this.isCompleted,
      currentStep: currentStep ?? this.currentStep,
      totalSteps: totalSteps ?? this.totalSteps,
      errorMessage: errorMessage,
      currentMathProblem: currentMathProblem ?? this.currentMathProblem,
      shakesCompleted: shakesCompleted ?? this.shakesCompleted,
      currentGForce: currentGForce ?? this.currentGForce,
      targetSentence: targetSentence ?? this.targetSentence,
      currentTypedInput: currentTypedInput ?? this.currentTypedInput,
      memoryCards: memoryCards ?? this.memoryCards,
      selectedCardIndices: selectedCardIndices ?? this.selectedCardIndices,
      isBoardLocked: isBoardLocked ?? this.isBoardLocked,
    );
  }
}

class MissionExecutionHandler extends StateNotifier<MissionRuntimeState> {
  final Random _rng = Random();
  StreamSubscription<UserAccelerometerEvent>? _accelSubscription;
  DateTime _lastShakeTimestamp = DateTime.fromMillisecondsSinceEpoch(0);

  static const List<String> _motivationalCorpus = [
    'Discipline weighs ounces while regret weighs tons.',
    'The secret of getting ahead is getting started right now.',
    'Do not wait for opportunity; wake up and create it today.',
    'Small daily execution compounds into unstoppable momentum.',
    'Conquer the morning before the morning conquers your goals.',
  ];

  static const List<String> _memorySymbols = [
    '⚡', '🔥', '🎯', '🚀', '💎', '🛡️', '🧭', '⏳'
  ];

  MissionExecutionHandler(MissionConfig config)
      : super(MissionRuntimeState(config: config)) {
    _initializeMission();
  }

  void _initializeMission() {
    switch (state.config.type) {
      case MissionType.none:
        state = state.copyWith(isCompleted: true);
        break;
      case MissionType.math:
        state = state.copyWith(
          currentStep: 1,
          totalSteps: state.config.problemCount,
          currentMathProblem: _generateMathProblem(state.config.mathDifficulty),
        );
        break;
      case MissionType.barcode:
        state = state.copyWith(currentStep: 1, totalSteps: 1);
        break;
      case MissionType.shake:
        _startShakeSensorStream();
        break;
      case MissionType.typing:
        state = state.copyWith(
          currentStep: 1,
          totalSteps: state.config.problemCount,
          targetSentence: _pickRandomSentence(),
          currentTypedInput: '',
        );
        break;
      case MissionType.memory:
        state = state.copyWith(
          memoryCards: _generateMemoryDeck(
            state.config.memoryGridRows,
            state.config.memoryGridCols,
          ),
        );
        break;
    }
  }

  // ===========================================================================
  // 1. MATH CHALLENGE ENGINE (Easy / Medium / Hard)
  // ===========================================================================
  MathProblem _generateMathProblem(MathDifficulty difficulty) {
    switch (difficulty) {
      case MathDifficulty.easy:
        // 2-digit addition: e.g., 47 + 38
        final a = 10 + _rng.nextInt(90);
        final b = 10 + _rng.nextInt(90);
        return MathProblem(expression: '$a + $b', answer: a + b);

      case MathDifficulty.medium:
        // 2-digit multiplication: e.g., 14 * 12
        final a = 11 + _rng.nextInt(19);
        final b = 11 + _rng.nextInt(15);
        return MathProblem(expression: '$a × $b', answer: a * b);

      case MathDifficulty.hard:
        // Multi-step operation: e.g., (14 * 6) + 38
        final a = 12 + _rng.nextInt(18);
        final b = 4 + _rng.nextInt(9);
        final c = 15 + _rng.nextInt(75);
        return MathProblem(
          expression: '($a × $b) + $c',
          answer: (a * b) + c,
        );
    }
  }

  void submitMathAnswer(String rawInput) {
    final parsed = int.tryParse(rawInput.trim());
    final currentProblem = state.currentMathProblem;
    if (currentProblem == null) return;

    if (parsed == currentProblem.answer) {
      if (state.currentStep >= state.totalSteps) {
        state = state.copyWith(isCompleted: true, errorMessage: null);
      } else {
        state = state.copyWith(
          currentStep: state.currentStep + 1,
          currentMathProblem: _generateMathProblem(state.config.mathDifficulty),
          errorMessage: null,
        );
      }
    } else {
      state = state.copyWith(
        errorMessage: 'Incorrect answer. Recalculate carefully!',
      );
    }
  }

  // ===========================================================================
  // 2. BARCODE / QR SCANNER GUARDRAIL
  // ===========================================================================
  void verifyScannedBarcode(String scannedRawValue) {
    final expected = state.config.registeredBarcode?.trim();
    if (expected == null || expected.isEmpty) {
      state = state.copyWith(isCompleted: true);
      return;
    }

    if (scannedRawValue.trim() == expected) {
      state = state.copyWith(isCompleted: true, errorMessage: null);
    } else {
      state = state.copyWith(
        errorMessage:
            'Code mismatch! Scanned "$scannedRawValue", expected registered target.',
      );
    }
  }

  // ===========================================================================
  // 3. SHAKE CHALLENGE (Linear UserAccelerometer + Debounce)
  // ===========================================================================
  void _startShakeSensorStream() {
    _accelSubscription?.cancel();
    _accelSubscription = userAccelerometerEventStream(
      samplingPeriod: SensorInterval.gameInterval,
    ).listen((UserAccelerometerEvent event) {
      if (state.isCompleted) return;

      // Calculate linear acceleration magnitude in G (excluding gravity)
      final magnitudeMetersPerSecSq =
          sqrt(event.x * event.x + event.y * event.y + event.z * event.z);
      final gForce = magnitudeMetersPerSecSq / 9.80665;

      final now = DateTime.now();
      if (gForce >= state.config.shakeThresholdG &&
          now.difference(_lastShakeTimestamp).inMilliseconds >= 160) {
        _lastShakeTimestamp = now;
        final nextCount = state.shakesCompleted + 1;
        final done = nextCount >= state.config.shakeTargetCount;
        state = state.copyWith(
          shakesCompleted: nextCount,
          currentGForce: gForce,
          isCompleted: done,
        );
        if (done) {
          _accelSubscription?.cancel();
        }
      } else {
        state = state.copyWith(currentGForce: gForce);
      }
    });
  }

  // ===========================================================================
  // 4. TYPING CHALLENGE (Zero-Typo Strict Verification)
  // ===========================================================================
  String _pickRandomSentence() {
    return _motivationalCorpus[_rng.nextInt(_motivationalCorpus.length)];
  }

  void updateTypingProgress(String typed) {
    final target = state.targetSentence;
    final hasTypo = !target.startsWith(typed);

    if (typed == target) {
      if (state.currentStep >= state.totalSteps) {
        state = state.copyWith(
          currentTypedInput: typed,
          isCompleted: true,
          errorMessage: null,
        );
      } else {
        state = state.copyWith(
          currentStep: state.currentStep + 1,
          targetSentence: _pickRandomSentence(),
          currentTypedInput: '',
          errorMessage: null,
        );
      }
    } else {
      state = state.copyWith(
        currentTypedInput: typed,
        errorMessage: hasTypo
            ? 'Typo detected! Fix the highlighted characters.'
            : null,
      );
    }
  }

  // ===========================================================================
  // 5. MEMORY TILE CHALLENGE (3x4 or 4x4 Card Flipping Match)
  // ===========================================================================
  List<MemoryCardItem> _generateMemoryDeck(int rows, int cols) {
    final totalCards = rows * cols;
    final pairCount = totalCards ~/ 2;
    final symbols = _memorySymbols.take(pairCount).toList();
    final deckSymbols = [...symbols, ...symbols]..shuffle(_rng);

    return List.generate(
      totalCards,
      (index) => MemoryCardItem(id: index, symbol: deckSymbols[index]),
    );
  }

  Future<void> flipMemoryCard(int index) async {
    if (state.isBoardLocked || state.isCompleted) return;
    final cards = List<MemoryCardItem>.from(state.memoryCards);
    if (cards[index].isFlipped || cards[index].isMatched) return;

    cards[index] = cards[index].copyWith(isFlipped: true);
    final selected = [...state.selectedCardIndices, index];

    if (selected.length < 2) {
      state = state.copyWith(
        memoryCards: cards,
        selectedCardIndices: selected,
      );
      return;
    }

    // Two cards flipped: evaluate match
    final firstIdx = selected[0];
    final secondIdx = selected[1];
    final isMatch = cards[firstIdx].symbol == cards[secondIdx].symbol;

    if (isMatch) {
      cards[firstIdx] = cards[firstIdx].copyWith(isMatched: true);
      cards[secondIdx] = cards[secondIdx].copyWith(isMatched: true);
      final allMatched = cards.every((c) => c.isMatched);

      state = state.copyWith(
        memoryCards: cards,
        selectedCardIndices: [],
        isCompleted: allMatched,
      );
    } else {
      state = state.copyWith(
        memoryCards: cards,
        selectedCardIndices: selected,
        isBoardLocked: true,
      );
      await Future.delayed(const Duration(milliseconds: 650));
      cards[firstIdx] = cards[firstIdx].copyWith(isFlipped: false);
      cards[secondIdx] = cards[secondIdx].copyWith(isFlipped: false);
      state = state.copyWith(
        memoryCards: cards,
        selectedCardIndices: [],
        isBoardLocked: false,
      );
    }
  }

  @override
  void dispose() {
    _accelSubscription?.cancel();
    super.dispose();
  }
}
