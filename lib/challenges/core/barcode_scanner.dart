import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// Builds a live camera scanner calling [onCode] for each code it reads and
/// [onError] when the camera cannot start.
typedef BarcodeScannerBuilder = Widget Function(
  ValueChanged<String> onCode, {
  VoidCallback? onError,
});

Widget _mobileScanner(ValueChanged<String> onCode, {VoidCallback? onError}) =>
    MobileScanner(
      errorBuilder: (context, error) {
        if (onError != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) => onError());
        }
        return const Center(child: Text('Camera unavailable'));
      },
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
