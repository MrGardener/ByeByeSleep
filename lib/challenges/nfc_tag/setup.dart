import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/nfc.dart';
import '../core/setup_scaffold.dart';

/// Registers the sticker the user placed away from the bed.
Future<Map<String, Object?>?> setupNfc(
  BuildContext context,
  Map<String, Object?> current,
) => Navigator.of(context).push<Map<String, Object?>>(
  MaterialPageRoute(builder: (_) => const _NfcSetupScreen()),
);

class _NfcSetupScreen extends ConsumerStatefulWidget {
  const _NfcSetupScreen();

  @override
  ConsumerState<_NfcSetupScreen> createState() => _NfcSetupScreenState();
}

class _NfcSetupScreenState extends ConsumerState<_NfcSetupScreen> {
  late final NfcReader _reader = ref.read(nfcReaderProvider);
  StreamSubscription<String>? _sub;
  String? _id;

  @override
  void initState() {
    super.initState();
    _sub = _reader.tagIds().listen((id) => setState(() => _id = id));
  }

  @override
  void dispose() {
    _sub?.cancel();
    _reader.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final id = _id;
    return SetupScaffold(
      title: 'NFC sticker — setup',
      explanation:
          'Stick an NFC tag somewhere away from your bed (coffee machine, '
          'bathroom mirror…) and hold the back of the phone against it.',
      onSave: id == null ? null : () => {'tagId': id},
      child: Text(
        id == null ? 'Waiting for a sticker…' : 'Sticker $id found',
        style: Theme.of(context).textTheme.titleLarge,
      ),
    );
  }
}
