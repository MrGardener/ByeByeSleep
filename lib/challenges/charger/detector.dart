import '../core/types.dart';

/// Plug the phone in during the challenge. If it is already charging (on the
/// bedside charger) it has to be unplugged first.
class ChargerDetector {
  ChargerDetector({required bool pluggedAtStart})
    : _needsUnplug = pluggedAtStart;

  bool _needsUnplug;
  bool _passed = false;

  bool get needsUnplug => _needsUnplug;

  ChallengeProgress onPlugged(bool plugged) {
    if (!plugged) {
      _needsUnplug = false;
    } else if (!_needsUnplug) {
      _passed = true;
    }
    return _passed ? ChallengeProgress.complete : ChallengeProgress.none;
  }
}
