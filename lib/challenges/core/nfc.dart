import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager/nfc_manager_android.dart';
import 'package:nfc_manager/nfc_manager_ios.dart';

import 'types.dart';

String tagIdHex(List<int> bytes) =>
    bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join().toUpperCase();

/// Reads NFC sticker ids, behind an interface so tests can fake taps.
abstract class NfcReader {
  Future<bool> isAvailable();

  /// Starts a reading session; one uppercase-hex id per tag touched.
  Stream<String> tagIds();

  Future<void> stop();
}

class PluginNfcReader implements NfcReader {
  @override
  Future<bool> isAvailable() async =>
      await NfcManager.instance.checkAvailability() == NfcAvailability.enabled;

  @override
  Stream<String> tagIds() {
    late final StreamController<String> controller;
    controller = StreamController<String>(
      onListen: () => NfcManager.instance.startSession(
        pollingOptions: NfcPollingOption.values.toSet(),
        onDiscovered: (tag) async {
          final id =
              NfcTagAndroid.from(tag)?.id ?? MiFareIos.from(tag)?.identifier;
          if (id != null) controller.add(tagIdHex(id));
        },
      ),
      onCancel: stop,
    );
    return controller.stream;
  }

  @override
  Future<void> stop() async {
    try {
      await NfcManager.instance.stopSession();
    } on Object {
      // No session running.
    }
  }
}

final nfcReaderProvider = Provider<NfcReader>((_) => PluginNfcReader());

/// Capability probe: {nfc} when the phone has NFC switched on.
Future<Set<SensorKind>> nfcCapability() async =>
    await PluginNfcReader().isAvailable() ? {SensorKind.nfc} : {};
