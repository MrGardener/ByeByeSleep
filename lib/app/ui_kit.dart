import 'package:flutter/material.dart';

import '../challenges/core/challenge_id.dart';
import '../game/quest.dart';
import 'theme.dart';

/// A rounded card painted with the night-to-sunrise hero gradient.
class HeroCard extends StatelessWidget {
  const HeroCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(24),
    this.margin = const EdgeInsets.fromLTRB(16, 8, 16, 8),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    final colors = SunriseColors.of(context);
    return Padding(
      padding: margin,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: colors.hero,
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
          boxShadow: [
            BoxShadow(
              color: Sunrise.ember.withValues(alpha: 0.25),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
          child: Stack(
            children: [
              // A soft sun rising in the corner.
              Positioned(
                right: -40,
                bottom: -60,
                child: IgnorePointer(
                  child: Container(
                    width: 180,
                    height: 180,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          Sunrise.amber.withValues(alpha: 0.45),
                          Sunrise.amber.withValues(alpha: 0),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: padding,
                child: DefaultTextStyle.merge(
                  style: TextStyle(color: colors.onHero),
                  child: IconTheme.merge(
                    data: IconThemeData(color: colors.onHero),
                    child: SizedBox(width: double.infinity, child: child),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A big pill button filled with the coral-to-amber glow, for the moments
/// that matter most (Stop).
class GlowButton extends StatelessWidget {
  const GlowButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.height = 72,
  });

  final VoidCallback? onPressed;
  final Widget child;
  final double height;

  @override
  Widget build(BuildContext context) {
    final colors = SunriseColors.of(context);
    return DecoratedBox(
      decoration: ShapeDecoration(
        shape: const StadiumBorder(),
        gradient: colors.glow,
        shadows: [
          BoxShadow(
            color: Sunrise.coral.withValues(alpha: 0.4),
            blurRadius: 24,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          foregroundColor: const Color(0xFF2A0A00),
          minimumSize: Size.fromHeight(height),
          textStyle: Theme.of(context).textTheme.headlineSmall!
              .copyWith(fontWeight: FontWeight.w800, letterSpacing: 0.5),
        ),
        child: child,
      ),
    );
  }
}

/// Section heading: a tinted icon, a bold title and a hairline.
class SectionHeader extends StatelessWidget {
  const SectionHeader(
    this.icon,
    this.title, {
    super.key,
    this.padding = const EdgeInsets.only(top: 28, bottom: 12),
  });

  final IconData icon;
  final String title;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: padding,
      child: Row(
        children: [
          IconBadge(icon, size: 36, color: scheme.primary),
          const SizedBox(width: 12),
          Flexible(
            flex: 3,
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(color: scheme.onSurface),
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(child: Divider()),
        ],
      ),
    );
  }
}

/// An icon on a softly tinted rounded square.
class IconBadge extends StatelessWidget {
  const IconBadge(this.icon, {super.key, this.color, this.size = 44});

  final IconData icon;
  final Color? color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).colorScheme.primary;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(size * 0.32),
      ),
      child: Icon(icon, color: c, size: size * 0.55),
    );
  }
}

/// The three accents in turn, so long lists feel lively, not uniform.
Color accentAt(ColorScheme scheme, int i) =>
    [scheme.primary, scheme.secondary, scheme.tertiary][i % 3];

/// An icon for each challenge, shown in lists.
IconData challengeIcon(ChallengeId id) => switch (id) {
  ChallengeId.orientationHopscotch => Icons.screen_rotation,
  ChallengeId.tiltMaze => Icons.blur_circular,
  ChallengeId.brokenCalculator => Icons.calculate_outlined,
  ChallengeId.stroopTap => Icons.palette_outlined,
  ChallengeId.lightsOn => Icons.lightbulb_outline,
  ChallengeId.walkSteps => Icons.directions_walk,
  ChallengeId.photoMatch => Icons.photo_camera_outlined,
  ChallengeId.nfcTag => Icons.nfc,
  ChallengeId.barcode => Icons.qr_code_scanner,
  ChallengeId.batteryGuess => Icons.battery_5_bar,
  ChallengeId.heartRate => Icons.favorite_border,
  ChallengeId.compass => Icons.explore_outlined,
  ChallengeId.watchSwing => Icons.watch,
  ChallengeId.watchSteps => Icons.directions_run,
  ChallengeId.stairs => Icons.stairs_outlined,
  ChallengeId.timeSense => Icons.hourglass_bottom,
  ChallengeId.pulseCode => Icons.vibration,
  ChallengeId.colourHunt => Icons.colorize,
};

/// An icon for each Sensor Quest world.
IconData worldIcon(World w) => switch (w) {
  World.batteryOracle => Icons.battery_charging_full,
  World.labyrinth => Icons.blur_circular,
  World.compassTemple => Icons.explore,
  World.solarGarden => Icons.local_florist,
  World.ghostHide => Icons.visibility_off_outlined,
  World.skyTower => Icons.apartment,
  World.runeHunt => Icons.nfc,
  World.pulseRun => Icons.monitor_heart_outlined,
};
