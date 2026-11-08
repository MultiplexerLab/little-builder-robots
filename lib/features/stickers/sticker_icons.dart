import 'package:flutter/material.dart';
import 'package:little_builder_robots/app/theme.dart';
import 'package:little_builder_robots/domain/rules/sticker_rules.dart';

/// Placeholder sticker art until the illustrated stickers land: one icon
/// per sticker rule on a coloured badge.
IconData stickerIcon(String rule) => switch (rule) {
  Fact.jump => Icons.keyboard_double_arrow_up_rounded,
  Fact.bolt => Icons.hexagon_rounded,
  Fact.splash => Icons.water_drop_rounded,
  Fact.boing => Icons.sentiment_very_satisfied_rounded,
  Fact.mud => Icons.landslide_rounded,
  Fact.jetpack => Icons.rocket_launch_rounded,
  Fact.heavySwitch => Icons.toggle_on_rounded,
  Fact.swing => Icons.back_hand_rounded,
  Fact.leaves => Icons.eco_rounded,
  Fact.ramp => Icons.trending_up_rounded,
  Fact.ceiling => Icons.vertical_align_top_rounded,
  Fact.gate => Icons.door_sliding_rounded,
  Fact.pitStop => Icons.build_rounded,
  Fact.hop => Icons.celebration_rounded,
  Fact.hint => Icons.lightbulb_rounded,
  Fact.testTrackLap => Icons.route_rounded,
  Fact.paint => Icons.palette_rounded,
  Fact.decal => Icons.star_rounded,
  Fact.headSwap => Icons.face_retouching_natural_rounded,
  Fact.newPart => Icons.extension_rounded,
  Fact.allMoves => Icons.directions_run_rounded,
  Fact.threeStars => Icons.stars_rounded,
  Fact.goldHead => Icons.emoji_events_rounded,
  Fact.world1 => Icons.flag_rounded,
  _ => Icons.help_rounded,
};

/// A round sticker. Unearned stickers are silhouettes (STK-03).
class StickerBadge extends StatelessWidget {
  const StickerBadge({
    required this.rule,
    this.earned = true,
    this.size = 88,
    super.key,
  });

  final String rule;
  final bool earned;
  final double size;

  static const List<Color> _fills = [
    AppColors.sunny,
    AppColors.roboBlue,
    AppColors.mint,
    AppColors.tangerine,
    AppColors.grass,
  ];

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: earned
          ? _fills[rule.hashCode.abs() % _fills.length]
          : AppColors.cloud,
      border: Border.all(
        color: earned ? AppColors.navy : AppColors.navy.withValues(alpha: 0.3),
        width: AppSizes.outline,
      ),
    ),
    child: Icon(
      stickerIcon(rule),
      size: size * 0.55,
      color: earned ? AppColors.navy : AppColors.navy.withValues(alpha: 0.25),
    ),
  );
}
