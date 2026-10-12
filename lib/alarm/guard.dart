import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';

import 'alarm.dart';

/// Weakening an alarm this close to ringing needs the phone's lock (spec §6.5).
const guardWindow = Duration(minutes: 30);

/// Asks for fingerprint / face / PIN.
abstract class Authenticator {
  Future<bool> confirm(String reason);
}

class LocalAuthAuthenticator implements Authenticator {
  final _auth = LocalAuthentication();

  @override
  Future<bool> confirm(String reason) async {
    try {
      // A phone without any lock cannot be asked; don't block its owner.
      if (!await _auth.isDeviceSupported()) return true;
      return await _auth.authenticate(localizedReason: reason);
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return true;
    }
  }
}

final authenticatorProvider = Provider<Authenticator>(
  (_) => LocalAuthAuthenticator(),
);

/// Clock for the guard; tests pin it.
final nowProvider = Provider<DateTime Function()>((_) => DateTime.now);

/// Next time [a] rings after [now] (local time), or null when disabled.
DateTime? nextRing(Alarm a, DateTime now) {
  if (!a.enabled) return null;
  for (var d = 0; d <= 7; d++) {
    final day = DateTime(now.year, now.month, now.day + d, a.hour, a.minute);
    if (a.repeatDays.isNotEmpty && !a.repeatDays.contains(day.weekday)) {
      continue;
    }
    if (day.isAfter(now)) return day;
  }
  return null;
}

bool needsGuard(Alarm a, DateTime now) {
  final next = nextRing(a, now);
  return next != null && next.difference(now) <= guardWindow;
}

/// True when the change may go ahead: not guarded, or confirmed.
Future<bool> confirmWeakening(WidgetRef ref, Alarm a, String reason) async {
  if (!needsGuard(a, ref.read(nowProvider)())) return true;
  return ref.read(authenticatorProvider).confirm(reason);
}
