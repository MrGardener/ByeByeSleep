import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// Builds a live camera scanner calling [onCode] for each code it reads.
typedef BarcodeScannerBuilder = Widget Function(ValueChanged<String> onCode);

Widget _mobileScanner(ValueChanged<String> onCode) => MobileScanner(
  onDetect: (capture) {
    for (final b in capture.barcodes) {
      final value = b.rawValue;
      if (value != null && value.isNotEmpty) {
        onCode(value);
        return;
      }
    }
  },
);

final barcodeScannerProvider = Provider<BarcodeScannerBuilder>(
  (_) => _mobileScanner,
);
