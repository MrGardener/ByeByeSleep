import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../app/ui_kit.dart';
import '../alarm.dart';
import '../alarm_platform.dart';
import '../alarm_providers.dart';
import '../guard.dart';
import '../preflight.dart';
import '../series.dart';
import '../sounds.dart';
import '../stage_config.dart';
import 'reminder_photo_screen.dart';
import 'repeat_summary.dart';
import 'sound_picker.dart';
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
  late int _followUp;
  late int _maxRing;
  AlarmSoundChoice? _sound;
  late int _ramp;
  late bool _vibrate;
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
    _followUp = a?.followUpMinutes ?? 0;
    _maxRing = a?.maxRingMinutes ?? Alarm.defaultMaxRing;
    _sound = a?.sound;
    _ramp = a?.rampSeconds ?? 0;
    _vibrate = a?.vibrate ?? true;
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
    if (existing != null) {
      final current = ref.read(alarmListProvider).value ?? const <Alarm>[];
      final oldSeries = [
        for (final a in current)
          if (a.parentId == existing.id) a,
      ];
      final draft = _draft().copyWith(enabled: true);
      final newSeries = ref
          .read(alarmListProvider.notifier)
          .planSeries(draft, current);
      if (groupWeakens(
            [existing, ...oldSeries],
            [draft, ...newSeries],
            ref.read(nowProvider)(),
          ) &&
          !await confirmWeakening(
            ref,
            existing,
            'Confirm changing an alarm that rings soon',
            series: oldSeries,
          )) {
        if (mounted) setState(() => _saving = false);
        return;
      }
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
    followUpMinutes: _followUp,
    maxRingMinutes: _maxRing,
    sound: _sound,
    rampSeconds: _ramp,
    vibrate: _vibrate,
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
          'off and deleted on its own. This cannot be undone. Changes not '
          'yet saved in this screen are discarded.',
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

  Widget _soundSection() => Column(
    children: [
      ListTile(
        key: const Key('sound-tile'),
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.library_music_outlined),
        title: Text(_sound?.title ?? 'Default alarm sound'),
        subtitle: const Text('Tap to choose and listen'),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: () async {
          final picked = await pickAlarmSound(context, _sound);
          if (picked != null && mounted) setState(() => _sound = picked.$1);
        },
      ),
      ListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Gradually louder'),
        subtitle: const Text('Starts soft and rises to full volume.'),
        trailing: DropdownButton<int>(
          key: const Key('ramp-dropdown'),
          value: _ramp,
          borderRadius: BorderRadius.circular(AppTheme.radius),
          items: [
            for (final r in {...rampChoices, _ramp})
              DropdownMenuItem(value: r, child: Text(rampLabel(r))),
          ],
          onChanged: (r) => setState(() => _ramp = r ?? 0),
        ),
      ),
      SwitchListTile(
        key: const Key('vibrate-switch'),
        contentPadding: EdgeInsets.zero,
        title: const Text('Vibrate'),
        value: _vibrate,
        onChanged: (v) => setState(() => _vibrate = v),
      ),
    ],
  );

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
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.alarm == null ? 'New alarm' : 'Edit alarm'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton(
              key: const Key('save-alarm'),
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(minimumSize: const Size(88, 44)),
              child: const Text('Save'),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          HeroCard(
            margin: EdgeInsets.zero,
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
            child: Column(
              children: [
                Text(
                  'WAKE UP AT',
                  style: text.labelMedium?.copyWith(
                    color: Colors.white,
                    letterSpacing: 1.6,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                TextButton(
                  key: const Key('time-button'),
                  onPressed: _pickTime,
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radius),
                    ),
                  ),
                  child: Text(
                    timeText,
                    style: text.displayLarge?.copyWith(
                      color: Colors.white,
                      fontSize: 88,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.touch_app_outlined, size: 16),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'Tap the time to change it',
                        style: text.bodyMedium?.copyWith(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            alignment: WrapAlignment.center,
            children: [
              for (var d = 1; d <= 7; d++)
                FilterChip(
                  key: Key('day-chip-$d'),
                  label: Text(dayName(d)),
                  showCheckmark: false,
                  labelPadding: const EdgeInsets.symmetric(horizontal: 2),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 8,
                  ),
                  selected: _days.contains(d),
                  onSelected: (on) => setState(() {
                    final day = d;
                    on ? _days.add(day) : _days.remove(day);
                  }),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Center(
            child: Text(
              repeatSummary(_days),
              style: text.labelLarge?.copyWith(
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            key: const Key('label-field'),
            controller: _label,
            decoration: const InputDecoration(
              labelText: 'Label',
              prefixIcon: Icon(Icons.label_outline),
            ),
          ),
          const SectionHeader(Icons.extension_outlined, 'Challenges'),
          _Panel(
            children: [
              if (_stages.isNotEmpty) ...[
                StageEditor(
                  stages: _stages,
                  pauseSeconds: _pauseSeconds,
                  onChanged: (s) => setState(() => _stages = s),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Pause between challenges'),
                  subtitle: const Text(
                    'Quieter after each challenge. You can go on to the next '
                    'one right away; Stop still needs every challenge done.',
                  ),
                  trailing: DropdownButton<int>(
                    key: const Key('pause-dropdown'),
                    value: _pauseSeconds,
                    borderRadius: BorderRadius.circular(AppTheme.radius),
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
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text('None: this alarm is a reminder only.'),
                ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text("Check I'm awake"),
                subtitle: const Text(
                  'Rings once more after Stop; one quick challenge proves you '
                  'did not fall asleep again.',
                ),
                trailing: DropdownButton<int>(
                  key: const Key('followup-dropdown'),
                  value: _followUp,
                  borderRadius: BorderRadius.circular(AppTheme.radius),
                  items: [
                    for (final m in const [0, 5, 10, 15, 20])
                      DropdownMenuItem(
                        value: m,
                        child: Text(m == 0 ? 'Off' : 'After $m min'),
                      ),
                  ],
                  onChanged: (m) => setState(() => _followUp = m ?? 0),
                ),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Stop ringing after'),
                subtitle: const Text(
                  'If nobody stops it (you are away), it stops by itself and '
                  'leaves a "missed alarm" notification.',
                ),
                trailing: DropdownButton<int>(
                  key: const Key('maxring-dropdown'),
                  value: _maxRing,
                  borderRadius: BorderRadius.circular(AppTheme.radius),
                  items: [
                    for (final m in const [10, 20, 30, 45, 60])
                      DropdownMenuItem(value: m, child: Text('After $m min')),
                  ],
                  onChanged: (m) =>
                      setState(() => _maxRing = m ?? Alarm.defaultMaxRing),
                ),
              ),
            ],
          ),
          if (ref.watch(alarmSoundsSupportedProvider)) ...[
            const SectionHeader(Icons.music_note_rounded, 'Sound'),
            _Panel(children: [_soundSection()]),
          ],
          const SectionHeader(Icons.repeat_rounded, 'Series'),
          _Panel(children: [_seriesSection()]),
          const SectionHeader(Icons.photo_camera_outlined, 'Reminder'),
          _Panel(children: [_reminderSection()]),
        ],
      ),
    );
  }
}

/// One tonal, rounded block of the editor.
class _Panel extends StatelessWidget {
  const _Panel({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    // Material, not a DecoratedBox: the list tiles inside paint on it.
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      ),
    );
  }
}
