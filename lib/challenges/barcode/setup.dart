import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/barcode_scanner.dart';
import '../core/setup_scaffold.dart';

/// Registers a barcode on something away from the bed (toothpaste, coffee).
Future<Map<String, Object?>?> setupBarcode(
  BuildContext context,
  Map<String, Object?> current,
) => Navigator.of(context).push<Map<String, Object?>>(
  MaterialPageRoute(builder: (_) => const _BarcodeSetupScreen()),
);

class _BarcodeSetupScreen extends ConsumerStatefulWidget {
  const _BarcodeSetupScreen();

  @override
  ConsumerState<_BarcodeSetupScreen> createState() =>
      _BarcodeSetupScreenState();
}

class _BarcodeSetupScreenState extends ConsumerState<_BarcodeSetupScreen> {
  String? _code;

  @override
  Widget build(BuildContext context) {
    final code = _code;
    return SetupScaffold(
      title: 'Barcode — setup',
      explanation:
          'Scan a barcode or QR code on something that stays away from your '
          'bed: toothpaste, coffee, a sticker on the fridge.',
      onSave: code == null ? null : () => {'code': code},
      child: Column(
        children: [
          Expanded(
            child: ref.read(barcodeScannerProvider)(
              (c) => setState(() => _code = c),
            ),
          ),
          Text(code == null ? 'Point the camera at a code…' : 'Found: $code'),
        ],
      ),
    );
  }
}
