import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'alarm.dart';

/// The phone's own sounds for the alarm editor (SoundsChannel.kt), offline.
abstract class SoundsSource {
  Future<List<AlarmSoundChoice>> list();

  /// Plays [uri] briefly at alarm volume; null = the default alarm sound.
  Future<void> preview(String? uri);
  Future<void> stopPreview();
}

class MethodChannelSounds implements SoundsSource {
  static const _channel = MethodChannel('byebyesleep/sounds');

  @override
  Future<List<AlarmSoundChoice>> list() async {
    try {
      final raw = await _channel.invokeListMethod<Map<Object?, Object?>>(
        'list',
      );
      return [
        for (final m in raw ?? const <Map<Object?, Object?>>[])
          AlarmSoundChoice(
            m['uri']! as String,
            m['title']! as String,
            kind: m['kind'] as String? ?? '',
          ),
      ];
    } on MissingPluginException {
      return const [];
    }
  }

  @override
  Future<void> preview(String? uri) async {
    try {
      await _channel.invokeMethod<void>('preview', {'uri': uri});
    } on MissingPluginException {
      // No previews here.
    }
  }

  @override
  Future<void> stopPreview() async {
    try {
      await _channel.invokeMethod<void>('stopPreview');
    } on MissingPluginException {
      // Nothing playing.
    }
  }
}

final soundsSourceProvider = Provider<SoundsSource>(
  (_) => MethodChannelSounds(),
);

/// Sound choice, gradual volume and vibration are Android features; on
/// iPhone the system plays its own alarm sound.
final alarmSoundsSupportedProvider = Provider<bool>((_) => Platform.isAndroid);

/// Gradual volume choices, in seconds.
const rampChoices = [0, 30, 60, 120, 300];

String rampLabel(int seconds) => switch (seconds) {
  0 => 'Off (full volume)',
  < 60 => 'Over $seconds s',
  _ => 'Over ${seconds ~/ 60} min',
};
