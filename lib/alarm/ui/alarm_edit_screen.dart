import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../alarm.dart';
import '../alarm_platform.dart';
import '../alarm_providers.dart';
import '../guard.dart';
import '../preflight.dart';
import '../series.dart';
import '../stage_config.dart';
import 'reminder_photo_screen.dart';
import 'repeat_summary.dart';
import 'stage_editor.dart';
import 'stored_photo.dart';

/// Creates a new alarm ([alarm] == null) or edits an existing one.
class AlarmEditScreen extends ConsumerStatefulWidget {
  const AlarmEditScreen({super.key, this.alarm});

  final Alarm? alarm;

  @override
  ConsumerState<AlarmEditScreen> createState() => _AlarmEditScreenState();
}

/// Pause lengths offered between stages, in seconds.
const pauseChoices = [0, 5, 10, 15, 20, 30, 60];

class _AlarmEditScreenState extends ConsumerState<AlarmEditScreen> {
  late TimeOfDay _time;
  late Set<int> _days;
  late List<StageConfig> _stages;
  late int _pauseSeconds;
  SeriesConfig? _series;
  String? _reminderPhoto;
  late final TextEditingController _reminderCaption;

  /// Challenges to restore when "reminder only" is switched off again.
  List<StageConfig> _stagesBeforeReminderOnly = defaultStages;
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
    _pauseSeconds = a?.pauseSeconds ?? 0;
    _series = a?.series;
    _reminderPhoto = a?.reminder?.photoPath;
    _reminderCaption = TextEditingController(text: a?.reminder?.caption ?? '')
      ..addListener(() => setState(() {}));
    _label = TextEditingController(text: a?.label ?? '');
  }

  @override
  void dispose() {
    _label.dispose();
    _reminderCaption.dispose();
    super.dispose();
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _time);
    if (picked != null) setState(() => _time = picked);
  }

  /// Shows pre-flight problems; true when the user still wants to save.
  Future<bool> _confirmPreflight() async {
    PermissionStatus permissions;
    try {
      permissions = await ref.read(alarmPlatformProvider).permissions();
    } catch (_) {
      permissions = PermissionStatus.unknownAllGranted;
    }
    final draft = Alarm(
      id: widget.alarm?.id ?? 0,
      hour: _time.hour,
      minute: _time.minute,
      repeatDays: _days,
      stages: _stages,
    );
    final problems = preflightProblems(draft, permissions);
    if (problems.isEmpty || !mounted) return true;
    final save = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        key: const Key('preflight-dialog'),
        title: const Text('This alarm may not work'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [for (final p in problems) Text('• $p')],
        ),
        actions: [
          TextButton(
            key: const Key('preflight-fix'),
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Fix'),
          ),
          TextButton(
            key: const Key('preflight-save'),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Save anyway'),
          ),
        ],
      ),
    );
    return save ?? false;
  }

  Future<void> _save() async {
    if (_saving) return; // ignore double taps
    setState(() => _saving = true);
    final existing = widget.alarm;
    if (existing != null &&
        weakens(
          existing,
          existing.copyWith(
            hour: _time.hour,
            minute: _time.minute,
            repeatDays: _days,
            stages: _stages,
            pauseSeconds: _pauseSeconds,
            enabled: true,
          ),
          ref.read(nowProvider)(),
        ) &&
        !await confirmWeakening(
          ref,
          existing,
          'Confirm changing an alarm that rings soon',
        )) {
      if (mounted) setState(() => _saving = false);
      return;
    }
    if (!await _confirmPreflight()) {
      if (mounted) setState(() => _saving = false);
      return;
    }
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

  /// The alarm as currently edited.
  Alarm _draft() => Alarm(
    id: widget.alarm?.id ?? 0,
    hour: _time.hour,
    minute: _time.minute,
    repeatDays: _days,
    label: _label.text.trim(),
    pauseSeconds: _pauseSeconds,
    reminder: _reminder.isEmpty ? null : _reminder,
    // Without a reminder an alarm needs at least one challenge.
    stages: _stages.isEmpty && _reminder.isEmpty ? defaultStages : _stages,
    series: _series,
  );

  Reminder get _reminder => Reminder(
    photoPath: _reminderPhoto,
    caption: _reminderCaption.text.trim(),
  );

  Widget _reminderSection() {
    final photo = _reminderPhoto;
    final reminderOnly = _stages.isEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            if (photo != null)
              SizedBox(width: 72, height: 72, child: StoredPhoto(photo)),
            const SizedBox(width: 8),
            Expanded(
              child: Wrap(
                spacing: 8,
                children: [
                  OutlinedButton.icon(
                    key: const Key('reminder-photo'),
                    onPressed: () async {
                      final path = await Navigator.of(context).push<String>(
                        MaterialPageRoute(
                          builder: (_) => const ReminderPhotoScreen(),
                        ),
                      );
                      if (path != null) setState(() => _reminderPhoto = path);
                    },
                    icon: const Icon(Icons.add_a_photo_outlined),
                    label: Text(photo == null ? 'Add photo' : 'Retake'),
                  ),
                  if (photo != null)
                    TextButton(
                      key: const Key('reminder-photo-remove'),
                      onPressed: () => setState(() => _reminderPhoto = null),
                      child: const Text('Remove'),
                    ),
                ],
              ),
            ),
          ],
        ),
        TextField(
          key: const Key('reminder-caption'),
          controller: _reminderCaption,
          maxLength: Reminder.maxCaption,
          decoration: const InputDecoration(
            labelText: "What not to forget (e.g. 'Passport and keys')",
          ),
        ),
        SwitchListTile(
          key: const Key('reminder-only'),
          contentPadding: EdgeInsets.zero,
          title: const Text('Reminder only — no challenges'),
          subtitle: const Text('Stop shows at once, then the reminder.'),
          value: reminderOnly,
          onChanged: _reminder.isEmpty && !reminderOnly
              ? null
              : (on) => setState(() {
                  if (on) {
                    _stagesBeforeReminderOnly = _stages;
                    _stages = const [];
                  } else {
                    _stages = _stagesBeforeReminderOnly;
                  }
                }),
        ),
      ],
    );
  }

  Future<void> _persist() async {
    final notifier = ref.read(alarmListProvider.notifier);
    if (widget.alarm == null) {
      await notifier.addAlarm(_draft());
    } else {
      await notifier.save(_draft());
    }
  }

  Future<void> _split() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        key: const Key('split-dialog'),
        title: const Text('Split into separate alarms?'),
        content: const Text(
          'Every alarm of this series becomes its own alarm at the same time. '
          'They will no longer follow this alarm: each one is edited, switched '
          'off and deleted on its own. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            key: const Key('split-confirm'),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Split'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await ref.read(alarmListProvider.notifier).split(widget.alarm!.id);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not split the series.')),
      );
      return;
    }
    if (mounted) Navigator.of(context).pop();
  }

  Widget _seriesSection() {
    final series = _series;
    final draft = _draft();
    final times = [
      if (series?.direction != SeriesDirection.before) draft.timeLabel,
      for (final c in seriesChildren(draft)) c.timeLabel,
      if (series?.direction == SeriesDirection.before) draft.timeLabel,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SwitchListTile(
          key: const Key('series-switch'),
          contentPadding: EdgeInsets.zero,
          title: const Text('Ring as a series'),
          subtitle: const Text(
            'One alarm that rings again every few minutes, instead of adding '
            'several alarms.',
          ),
          value: series != null,
          onChanged: (on) => setState(
            () => _series = on
                ? const SeriesConfig(count: 3, everyMinutes: 5)
                : null,
          ),
        ),
        if (series != null) ...[
          Row(
            children: [
              const Text('Alarms'),
              const SizedBox(width: 8),
              DropdownButton<int>(
                key: const Key('series-count'),
                value: series.count,
                items: [
                  for (var n = 2; n <= SeriesConfig.maxCount; n++)
                    DropdownMenuItem(value: n, child: Text('$n')),
                ],
                onChanged: (n) => setState(
                  () => _series = SeriesConfig(
                    count: n!,
                    everyMinutes: series.everyMinutes,
                    direction: series.direction,
                    followUp: series.followUp,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              const Text('every'),
              const SizedBox(width: 8),
              DropdownButton<int>(
                key: const Key('series-every'),
                value: series.everyMinutes,
                items: [
                  for (final m in const [1, 2, 3, 5, 10, 15, 20, 30])
                    DropdownMenuItem(value: m, child: Text('$m min')),
                ],
                onChanged: (m) => setState(
                  () => _series = SeriesConfig(
                    count: series.count,
                    everyMinutes: m!,
                    direction: series.direction,
                    followUp: series.followUp,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SegmentedButton<SeriesDirection>(
            key: const Key('series-direction'),
            segments: const [
              ButtonSegment(
                value: SeriesDirection.after,
                label: Text('Starts at this time'),
              ),
              ButtonSegment(
                value: SeriesDirection.before,
                label: Text('Ends at this time'),
              ),
            ],
            selected: {series.direction},
            onSelectionChanged: (d) => setState(
              () => _series = SeriesConfig(
                count: series.count,
                everyMinutes: series.everyMinutes,
                direction: d.single,
                followUp: series.followUp,
              ),
            ),
          ),
          const SizedBox(height: 8),
          SegmentedButton<FollowUp>(
            key: const Key('series-followup'),
            segments: const [
              ButtonSegment(
                value: FollowUp.same,
                label: Text('Same challenges'),
              ),
              ButtonSegment(
                value: FollowUp.quick,
                label: Text('One quick sum'),
              ),
            ],
            selected: {series.followUp},
            onSelectionChanged: (f) => setState(
              () => _series = SeriesConfig(
                count: series.count,
                everyMinutes: series.everyMinutes,
                direction: series.direction,
                followUp: f.single,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Rings at ${times.join(', ')}',
            key: const Key('series-preview'),
          ),
          if (widget.alarm?.series != null)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                key: const Key('series-split'),
                onPressed: _split,
                icon: const Icon(Icons.call_split),
                label: const Text('Split into separate alarms'),
              ),
            ),
        ],
      ],
    );
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
          const _SectionTitle(Icons.schedule, 'When'),
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
          const _SectionTitle(Icons.extension_outlined, 'Challenges'),
          if (_stages.isNotEmpty) ...[
            StageEditor(
              stages: _stages,
              pauseSeconds: _pauseSeconds,
              onChanged: (s) => setState(() => _stages = s),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Pause between challenges'),
              subtitle: const Text('The alarm rings quieter during the pause.'),
              trailing: DropdownButton<int>(
                key: const Key('pause-dropdown'),
                value: _pauseSeconds,
                items: [
                  for (final s in pauseChoices)
                    DropdownMenuItem(
                      value: s,
                      child: Text(s == 0 ? 'No pause' : '$s seconds'),
                    ),
                ],
                onChanged: (s) => setState(() => _pauseSeconds = s ?? 0),
              ),
            ),
          ] else
            const Text('None: this alarm is a reminder only.'),
          const _SectionTitle(Icons.repeat, 'Series'),
          _seriesSection(),
          const _SectionTitle(Icons.photo_camera_outlined, 'Reminder'),
          _reminderSection(),
        ],
      ),
    );
  }
}

/// Heading of one tool in the editor: When, Challenges, Series, Reminder.
class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.icon, this.title);

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 8),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 8),
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(color: color),
          ),
          const SizedBox(width: 8),
          const Expanded(child: Divider()),
        ],
      ),
    );
  }
}
