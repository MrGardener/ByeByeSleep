import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../alarm.dart';
import '../sounds.dart';

/// Picks the alarm's sound from the phone's own sounds; tapping one plays a
/// preview. Returns the choice (null inside: the default alarm sound), or
/// nothing when cancelled.
Future<(AlarmSoundChoice?,)?> pickAlarmSound(
  BuildContext context,
  AlarmSoundChoice? current,
) => showModalBottomSheet<(AlarmSoundChoice?,)>(
  context: context,
  isScrollControlled: true,
  builder: (_) => _SoundPicker(current: current),
);

class _SoundPicker extends ConsumerStatefulWidget {
  const _SoundPicker({required this.current});

  final AlarmSoundChoice? current;

  @override
  ConsumerState<_SoundPicker> createState() => _SoundPickerState();
}

class _SoundPickerState extends ConsumerState<_SoundPicker> {
  late AlarmSoundChoice? _selected = widget.current;
  List<AlarmSoundChoice>? _sounds;
  late final SoundsSource _source = ref.read(soundsSourceProvider);

  @override
  void initState() {
    super.initState();
    _source.list().then(
      (s) {
        if (mounted) setState(() => _sounds = s);
      },
      onError: (Object _) {
        if (mounted) setState(() => _sounds = const []);
      },
    );
  }

  @override
  void dispose() {
    _source.stopPreview();
    super.dispose();
  }

  void _pick(AlarmSoundChoice? s) {
    setState(() => _selected = s);
    _source.preview(s?.uri);
  }

  @override
  Widget build(BuildContext context) {
    final sounds = _sounds;
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    Widget tile(AlarmSoundChoice? s) {
      final selected = s?.uri == _selected?.uri;
      return ListTile(
        selected: selected,
        leading: Icon(
          selected ? Icons.radio_button_checked : Icons.radio_button_off,
          color: selected ? scheme.primary : scheme.onSurfaceVariant,
        ),
        onTap: () => _pick(s),
        title: Text(s?.title ?? 'Default alarm sound'),
        subtitle: s == null || s.kind.isEmpty ? null : Text(s.kind),
        trailing: selected ? const Icon(Icons.volume_up_rounded) : null,
      );
    }

    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.75,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
            child: Row(
              children: [
                Expanded(child: Text('Alarm sound', style: text.titleLarge)),
                FilledButton(
                  key: const Key('sound-choose'),
                  onPressed: () => Navigator.of(context).pop((_selected,)),
                  child: const Text('Choose'),
                ),
              ],
            ),
          ),
          Expanded(
            child: sounds == null
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    children: [tile(null), for (final s in sounds) tile(s)],
                  ),
          ),
        ],
      ),
    );
  }
}
