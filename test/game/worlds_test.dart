import 'dart:math';

import 'package:byebyesleep/game/worlds/compass_temple.dart';
import 'package:byebyesleep/game/worlds/ghost_hide.dart';
import 'package:byebyesleep/game/worlds/rune_hunt.dart';
import 'package:byebyesleep/game/worlds/sky_tower.dart';
import 'package:byebyesleep/game/worlds/solar_garden.dart';
import 'package:flutter_test/flutter_test.dart';

Duration ms(int v) => Duration(milliseconds: v);

void main() {
  group('Compass Temple', () {
    test('holding each target for 2 s passes', () {
      final t = CompassTrial([0, 90, 180, 270]);
      var now = 0;
      for (final target in [0.0, 90.0, 180.0, 270.0]) {
        for (var i = 0; i <= 20; i++) {
          t.update(target + 5, ms(now));
          now += 100;
        }
      }
      expect(t.passed, isTrue);
    });

    test('350° counts as within 15° of 5°', () {
      final t = CompassTrial([5]);
      t.update(350, ms(0));
      t.update(350, ms(2000));
      expect(t.passed, isTrue);
    });

    test('random targets are at least 60° apart in a row', () {
      final targets = CompassTrial.randomTargets(Random(1));
      expect(targets, hasLength(4));
      for (var i = 1; i < targets.length; i++) {
        final d = ((targets[i] - targets[i - 1]) % 360 + 540) % 360 - 180;
        expect(d.abs(), greaterThanOrEqualTo(60));
      }
    });
  });

  group('Solar Garden', () {
    test('10 s of bright light passes', () {
      final g = SolarGarden();
      for (var t = 0; t <= 9900; t += 100) {
        g.update(200, ms(t));
      }
      expect(g.passed, isFalse);
      g.update(200, ms(10000));
      expect(g.passed, isTrue);
    });

    test('darkness wilts the plant at half speed', () {
      final g = SolarGarden();
      var t = 0;
      void run(double lux, int untilMs) {
        for (; t <= untilMs; t += 100) {
          g.update(lux, ms(t));
        }
        t -= 100;
      }

      run(200, 6000); // 6 s grown
      run(5, 10000); // −2 s → 4 s
      expect(g.grown, const Duration(seconds: 4));
      run(200, 15900);
      expect(g.passed, isFalse);
      g.update(200, ms(16000));
      expect(g.passed, isTrue);
    });
  });

  group('Ghost Hide', () {
    /// Runs the game for [seconds] with [cover] deciding the sensor.
    void play(GhostHide g, bool Function(GhostPhase) cover, int seconds) {
      for (var t = 0; t <= seconds * 1000; t += 100) {
        g.update(cover(g.phase), ms(t));
      }
    }

    test('hiding at every warning survives five visits', () {
      final g = GhostHide(Random(3));
      play(g, (p) => p == GhostPhase.warning || p == GhostPhase.looking, 60);
      expect(g.passed, isTrue);
    });

    test('being seen restarts the visit', () {
      final g = GhostHide(Random(3));
      play(g, (p) => p == GhostPhase.warning, 60);
      expect(g.survived, 0);
    });

    test('staying covered the whole time makes no progress', () {
      final g = GhostHide(Random(3));
      play(g, (_) => true, 60);
      expect(g.survived, 0);
      expect(g.phase, GhostPhase.uncover);
    });
  });

  group('Sky Tower', () {
    test('a slow climb of 0.35 hPa passes', () {
      final s = SkyTower();
      for (var t = 0; t <= 3000; t += 100) {
        s.update(1000, ms(t));
      }
      var passedAt = -1;
      for (var t = 3100; t <= 40000; t += 100) {
        final drop = min(0.35, (t - 3000) / 20000 * 0.35);
        s.update(1000 - drop, ms(t));
        if (s.passed && passedAt < 0) passedAt = t;
      }
      expect(passedAt, inInclusiveRange(22000, 23500));
    });

    test('a short spike does not pass', () {
      final s = SkyTower();
      for (var t = 0; t <= 3000; t += 100) {
        s.update(1000, ms(t));
      }
      for (var t = 3100; t <= 10000; t += 100) {
        final spike = t >= 5000 && t < 5500;
        s.update(spike ? 999.5 : 1000, ms(t));
      }
      expect(s.passed, isFalse);
    });
  });

  group('Rune Hunt', () {
    test('three different tags pass; repeats do not count', () {
      final r = RuneHunt();
      r.add('AA');
      r.add('AA');
      r.add('BB');
      expect(r.found, 2);
      expect(r.passed, isFalse);
      r.add('CC');
      expect(r.passed, isTrue);
    });
  });
}
