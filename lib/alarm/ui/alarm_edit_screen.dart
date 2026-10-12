import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../alarm.dart';
import '../alarm_providers.dart';
import '../stage_config.dart';
import 'repeat_summary.dart';
import 'stage_editor.dart';

/// Creates a new alarm ([alarm] == null) or edits an existing one.
class AlarmEditScreen extends ConsumerStatefulWidget {
  const AlarmEditScreen({super.key, this.alarm});

  final Alarm? alarm;

  @override
  ConsumerState<AlarmEditScreen> createState() => _AlarmEditScreenState();
}

class _AlarmEditScreenState extends ConsumerState<AlarmEditScreen> {
  late TimeOfDay _time;
  late Set<int> _days;
  late List<StageConfig> _stages;
  late final TextEditingController _label;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final a = widget.alarm;
    _time = a != null
        ? TimeOfDay(hour: a.hour, minute: a.minute)
        : TimeOfDay(hour: (DateTime.now().hour + 1) % 24, minute: 0);
    _days = {...?a?.repeatDays};
    _stages = a?.stages ?? defaultStages;
    _label = TextEditingController(text: a?.label ?? '');
  }

  @override
  void dispose() {
    _label.dispose();
    super.dispose();
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _time);
    if (picked != null) setState(() => _time = picked);
  }

  Future<void> _save() async {
    if (_saving) return; // ignore double taps
    setState(() => _saving = true);
    try {
      await _persist();
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save the alarm. Try again.')),
      );
      return;
    }
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _persist() async {
    final notifier = ref.read(alarmListProvider.notifier);
    final existing = widget.alarm;
    if (existing == null) {
      await notifier.add(
        hour: _time.hour,
        minute: _time.minute,
        repeatDays: _days,
        label: _label.text.trim(),
        stages: _stages,
      );
    } else {
      await notifier.save(
        existing.copyWith(
          hour: _time.hour,
          minute: _time.minute,
          repeatDays: _days,
          label: _label.text.trim(),
          enabled: true,
          stages: _stages,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final timeText =
        '${_time.hour.toString().padLeft(2, '0')}:${_time.minute.toString().padLeft(2, '0')}';
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.alarm == null ? 'New alarm' : 'Edit alarm'),
        actions: [
          TextButton(
            key: const Key('save-alarm'),
            onPressed: _saving ? null : _save,
            child: const Text('Save'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: TextButton(
              key: const Key('time-button'),
              onPressed: _pickTime,
              child: Text(
                timeText,
                style: Theme.of(context).textTheme.displayLarge,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 6,
            alignment: WrapAlignment.center,
            children: [
              for (var d = 1; d <= 7; d++)
                FilterChip(
                  key: Key('day-chip-$d'),
                  label: Text(dayName(d)),
                  selected: _days.contains(d),
                  onSelected: (on) => setState(() {
                    final day = d;
                    on ? _days.add(day) : _days.remove(day);
                  }),
                ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            key: const Key('label-field'),
            controller: _label,
            decoration: const InputDecoration(labelText: 'Label'),
          ),
          const SizedBox(height: 24),
          StageEditor(
            stages: _stages,
            onChanged: (s) => setState(() => _stages = s),
          ),
        ],
      ),
    );
  }
}
