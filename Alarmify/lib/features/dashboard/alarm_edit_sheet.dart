import 'package:flutter/material.dart';
import '../../domain/entities/alarm_entity.dart';

class AlarmEditSheet extends StatefulWidget {
  final AlarmEntity? initialAlarm;
  const AlarmEditSheet({super.key, this.initialAlarm});

  @override
  State<AlarmEditSheet> createState() => _AlarmEditSheetState();
}

class _AlarmEditSheetState extends State<AlarmEditSheet> {
  late TimeOfDay _selectedTime;
  late TextEditingController _labelController;
  late TextEditingController _barcodeController;
  late Set<int> _selectedWeekdays;
  late MissionType _missionType;
  late MathDifficulty _mathDifficulty;
  late int _problemCount;
  late int _shakeCount;
  late int _crescendoSeconds;
  late int _maxSnoozeCount;
  late bool _volumeLock;
  late bool _wakeUpCheck;
  late String _ringtoneUri;

  static const _weekdayLabels = {
    1: 'Pzt',
    2: 'Sal',
    3: 'Çar',
    4: 'Per',
    5: 'Cum',
    6: 'Cmt',
    7: 'Paz',
  };

  @override
  void initState() {
    super.initState();
    final a = widget.initialAlarm;
    _selectedTime = a != null
        ? TimeOfDay(hour: a.hour, minute: a.minute)
        : TimeOfDay.now();
    _labelController = TextEditingController(text: a?.label ?? 'Sabah Görevi');
    _barcodeController = TextEditingController(
      text: a?.mission.registeredBarcode ?? '8690000000001',
    );
    _selectedWeekdays = Set<int>.from(a?.repeatWeekdays ?? []);
    _missionType = a?.mission.type ?? MissionType.math;
    _mathDifficulty = a?.mission.mathDifficulty ?? MathDifficulty.medium;
    _problemCount = a?.mission.problemCount ?? 3;
    _shakeCount = a?.mission.shakeTargetCount ?? 40;
    _crescendoSeconds = a?.antiCheat.crescendoSeconds ?? 30;
    _maxSnoozeCount = a?.antiCheat.maxSnoozeCount ?? 2;
    _volumeLock = a?.antiCheat.volumeLock ?? true;
    _wakeUpCheck = a?.antiCheat.wakeUpCheckEnabled ?? true;
    _ringtoneUri = a?.ringtoneUri ?? 'assets/sounds/siren_110db.mp3';
  }

  @override
  void dispose() {
    _labelController.dispose();
    _barcodeController.dispose();
    super.dispose();
  }

  void _save() {
    final id = widget.initialAlarm?.id ??
        DateTime.now().millisecondsSinceEpoch.remainder(100000);
    final newAlarm = AlarmEntity(
      id: id,
      hour: _selectedTime.hour,
      minute: _selectedTime.minute,
      label: _labelController.text.trim().isEmpty
          ? 'Mission Alarm'
          : _labelController.text.trim(),
      isEnabled: true,
      repeatWeekdays: _selectedWeekdays.toList()..sort(),
      ringtoneUri: _ringtoneUri,
      mission: MissionConfig(
        type: _missionType,
        mathDifficulty: _mathDifficulty,
        problemCount: _problemCount,
        registeredBarcode: _barcodeController.text.trim(),
        shakeTargetCount: _shakeCount,
      ),
      antiCheat: AntiCheatConfig(
        volumeLock: _volumeLock,
        crescendoSeconds: _crescendoSeconds,
        maxSnoozeCount: _maxSnoozeCount,
        wakeUpCheckEnabled: _wakeUpCheck,
      ),
    );
    Navigator.of(context).pop(newAlarm);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF0B0B0B),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'ALARM VE GÖREV AYARLARI',
                  style: TextStyle(
                    color: Color(0xFF00FF9D),
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close, color: Colors.white54),
                ),
              ],
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: () async {
                final picked = await showTimePicker(
                  context: context,
                  initialTime: _selectedTime,
                );
                if (picked != null) setState(() => _selectedTime = picked);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFF141414),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF00FF9D)),
                ),
                child: Text(
                  '${_selectedTime.hour.toString().padLeft(2, '0')}:${_selectedTime.minute.toString().padLeft(2, '0')}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 48,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _labelController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Alarm Etiketi',
                labelStyle: TextStyle(color: Colors.white54),
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 6,
              children: _weekdayLabels.entries.map((entry) {
                final selected = _selectedWeekdays.contains(entry.key);
                return FilterChip(
                  label: Text(entry.value),
                  selected: selected,
                  selectedColor: const Color(0xFF00FF9D),
                  checkmarkColor: Colors.black,
                  labelStyle: TextStyle(
                    color: selected ? Colors.black : Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                  onSelected: (val) {
                    setState(() {
                      if (val) {
                        _selectedWeekdays.add(entry.key);
                      } else {
                        _selectedWeekdays.remove(entry.key);
                      }
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<MissionType>(
              value: _missionType,
              dropdownColor: const Color(0xFF1A1A1A),
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Kapatma Görevi (Mission)',
                labelStyle: TextStyle(color: Color(0xFF00FF9D)),
              ),
              items: MissionType.values.map((m) {
                return DropdownMenuItem(
                  value: m,
                  child: Text(m.name.toUpperCase()),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) setState(() => _missionType = val);
              },
            ),
            if (_missionType == MissionType.math) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<MathDifficulty>(
                value: _mathDifficulty,
                dropdownColor: const Color(0xFF1A1A1A),
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: 'Matematik Zorluğu'),
                items: MathDifficulty.values.map((d) {
                  return DropdownMenuItem(
                    value: d,
                    child: Text(d.name.toUpperCase()),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _mathDifficulty = val);
                },
              ),
            ],
            if (_missionType == MissionType.barcode) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _barcodeController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Hedef Barkod / QR Kodu',
                ),
              ),
            ],
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'Ses Kilidi (%100 Sabitle)',
                style: TextStyle(color: Colors.white),
              ),
              value: _volumeLock,
              activeColor: const Color(0xFF00FF9D),
              onChanged: (v) => setState(() => _volumeLock = v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'Uyanıklık Kontrolü (Wake-Up Check)',
                style: TextStyle(color: Colors.white),
              ),
              value: _wakeUpCheck,
              activeColor: const Color(0xFF00FF9D),
              onChanged: (v) => setState(() => _wakeUpCheck = v),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00FF9D),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              onPressed: _save,
              child: const Text(
                'ALARMI KAYDET',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
