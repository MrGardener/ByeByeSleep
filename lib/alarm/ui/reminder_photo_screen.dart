import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../challenges/core/camera.dart';

/// Takes the reminder's photo; pops the stored photo's path, or null.
class ReminderPhotoScreen extends ConsumerStatefulWidget {
  const ReminderPhotoScreen({super.key});

  @override
  ConsumerState<ReminderPhotoScreen> createState() =>
      _ReminderPhotoScreenState();
}

class _ReminderPhotoScreenState extends ConsumerState<ReminderPhotoScreen> {
  late final PhotoCamera _camera = ref.read(photoCameraProvider)();
  bool _ready = false;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _camera.init().then(
      (_) => mounted ? setState(() => _ready = true) : null,
      onError: (Object _) =>
          mounted ? setState(() => _error = 'Camera unavailable') : null,
    );
  }

  @override
  void dispose() {
    _camera.dispose();
    super.dispose();
  }

  Future<void> _shoot() async {
    setState(() => _busy = true);
    try {
      final bytes = await _camera.capture();
      final path = await ref.read(photoStoreProvider).save(bytes);
      if (mounted) Navigator.of(context).pop(path);
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = 'Could not take the photo. Try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Photo of what not to forget')),
      body: Column(
        children: [
          Expanded(
            child: _ready
                ? _camera.preview()
                : Center(child: Text(_error ?? 'Starting camera…')),
          ),
          if (_ready && _error != null) Text(_error!),
          Padding(
            padding: const EdgeInsets.all(16),
            child: FilledButton.icon(
              key: const Key('reminder-shutter'),
              onPressed: _ready && !_busy ? _shoot : null,
              icon: const Icon(Icons.camera_alt),
              label: const Text('Take photo'),
            ),
          ),
        ],
      ),
    );
  }
}
