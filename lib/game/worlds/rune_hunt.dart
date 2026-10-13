import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../challenges/core/nfc.dart';
import 'world_kit.dart';

/// Touch [needed] different NFC stickers.
class RuneHunt {
  RuneHunt({this.needed = 3});

  final int needed;
  final _ids = <String>{};

  int get found => _ids.length;
  bool get passed => found >= needed;
  double get progress => (found / needed).clamp(0, 1);

  void add(String tagId) => _ids.add(tagId);
}

/// Rune Hunt: touch the phone to three different NFC stickers or cards.
class RuneHuntWorld extends ConsumerStatefulWidget {
  const RuneHuntWorld({super.key, required this.args});

  final WorldArgs args;

  @override
  ConsumerState<RuneHuntWorld> createState() => _RuneHuntState();
}

class _RuneHuntState extends ConsumerState<RuneHuntWorld> {
  final _hunt = RuneHunt();
  StreamSubscription<String>? _sub;
  bool _reported = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    final reader = ref.read(nfcReaderProvider);
    bool available;
    try {
      available = await reader.isAvailable();
    } catch (_) {
      available = false;
    }
    if (!mounted) return;
    if (!available) {
      widget.args.onUnavailable?.call();
      return;
    }
    _sub = reader.tagIds().listen((id) {
      setState(() => _hunt.add(id));
      if (_hunt.passed && !_reported) {
        _reported = true;
        widget.args.onPassed();
      }
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WorldPanel(
      icon: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < _hunt.needed; i++)
            Icon(
              i < _hunt.found ? Icons.auto_awesome : Icons.circle_outlined,
              size: 56,
            ),
        ],
      ),
      message: _hunt.passed
          ? 'All runes collected!'
          : 'Touch the back of the phone to an NFC sticker or card.',
      detail: 'Each one must be different (${_hunt.found} of ${_hunt.needed}).',
      progress: _hunt.progress,
    );
  }
}
