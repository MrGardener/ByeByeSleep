import 'package:flutter/foundation.dart';
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
  LocalAuthAuthenticator({
    Future<bool> Function()? isSupported,
    Future<bool> Function(String reason)? authenticate,
  }) : _isSupported = isSupported ?? LocalAuthentication().isDeviceSupported,
       _authenticate =
           authenticate ??
           ((reason) =>
               LocalAuthentication().authenticate(localizedReason: reason));

  final Future<bool> Function() _isSupported;
  final Future<bool> Function(String reason) _authenticate;

  @override
  Future<bool> confirm(String reason) async {
    try {
      // A phone without any lock cannot be asked; don't block its owner.
      if (!await _isSupported()) return true;
      return await _authenticate(reason);
    } on LocalAuthException catch (e) {
      // Cancelled, timed out, locked out… mean "no" — except no lock at all.
      return e.code == LocalAuthExceptionCode.noCredentialsSet;
    } on MissingPluginException {
      return true;
    } on PlatformException {
      return false;
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
  final at = a.onceAt;
  if (at != null) return at.isAfter(now) ? at : null;
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

/// Whether changing [before] into [after] makes it ring later (or not at
/// all) or swaps its challenges — the edits that need confirmation when the
/// alarm is imminent.
bool weakens(Alarm before, Alarm after, DateTime now) {
  if (!listEquals(before.stages, after.stages)) return true;
  final was = nextRing(before, now);
  final will = nextRing(after, now);
  if (was == null) return false;
  return will == null || will.isAfter(was);
}

/// Like [weakens] for a main alarm together with its series ([before] into
/// [after], matched by id; a missing id was deleted): true when any alarm
/// that rings within the guard window would ring later or not at all.
bool groupWeakens(List<Alarm> before, List<Alarm> after, DateTime now) {
  final byId = {for (final a in after) a.id: a};
  for (final b in before) {
    if (!needsGuard(b, now)) continue;
    final a = byId[b.id];
    if (a == null || weakens(b, a, now)) return true;
  }
  return false;
}

/// True when the change may go ahead: not guarded, or confirmed. [series]
/// are the alarms of [a]'s series, which go with it.
Future<bool> confirmWeakening(
  WidgetRef ref,
  Alarm a,
  String reason, {
  List<Alarm> series = const [],
}) async {
  final now = ref.read(nowProvider)();
  if (![a, ...series].any((x) => needsGuard(x, now))) return true;
  try {
    return await ref.read(authenticatorProvider).confirm(reason);
  } catch (_) {
    return false; // when in doubt, keep the alarm as it is
  }
}
