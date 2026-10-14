import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../alarm/alarm_providers.dart';
import '../tools/ios_bedtime.dart';
import 'ring_screen.dart';

/// On iPhone the system shows the alarm, not the app: the challenges open
/// when the app is opened (or comes back) while an alarm rings. Android has
/// its own ring screen over the lock screen (RingActivity).
final ringLauncherEnabledProvider = Provider<bool>((_) => Platform.isIOS);

typedef RingScreenBuilder = Widget Function(
  int alarmId,
  VoidCallback onFinished,
);

Widget _defaultRingScreen(int alarmId, VoidCallback onFinished) =>
    RingScreen(alarmId: alarmId, onFinished: onFinished);

class RingLauncher extends ConsumerStatefulWidget {
  const RingLauncher({
    super.key,
    required this.child,
    this.ringScreen = _defaultRingScreen,
  });

  final Widget child;
  final RingScreenBuilder ringScreen;

  @override
  ConsumerState<RingLauncher> createState() => _RingLauncherState();
}

class _RingLauncherState extends ConsumerState<RingLauncher>
    with WidgetsBindingObserver {
  var _showing = false;

  /// An alarm going off over the open app does not bring it back to the
  /// foreground, so look every 15 s while it is open.
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
    _startPolling();
  }

  void _startPolling() {
    _poll?.cancel();
    if (!ref.read(ringLauncherEnabledProvider)) return;
    _poll = Timer.periodic(const Duration(seconds: 15), (_) => _check());
  }

  @override
  void dispose() {
    _poll?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startPolling();
      unawaited(_check());
    } else if (state == AppLifecycleState.paused) {
      _poll?.cancel();
    }
  }

  Future<void> _check() async {
    if (_showing || !mounted || !ref.read(ringLauncherEnabledProvider)) return;
    final platform = ref.read(alarmPlatformProvider);
    List<int> ringing;
    try {
      ringing = await platform.ringingAlarmIds();
    } catch (_) {
      return;
    }
    // What rang may have switched alarms off: show the list as it is now.
    ref.invalidate(alarmListProvider);
    if (ringing.isEmpty || _showing || !mounted) return;
    _showing = true;
    final navigator = Navigator.of(context);
    await navigator.push<void>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => PopScope(
          canPop: false,
          child: widget.ringScreen(ringing.first, navigator.pop),
        ),
      ),
    );
    _showing = false;
    // Another alarm may be ringing too.
    unawaited(_check());
  }

  @override
  Widget build(BuildContext context) {
    // iPhone: keep the bedtime reminders in step with the alarms.
    ref.watch(iosBedtimeSyncProvider);
    return widget.child;
  }
}
