import 'package:flutter/material.dart';
import 'package:little_builder_robots/app/theme.dart';
import 'package:little_builder_robots/core/l10n/gen/app_localizations.dart';
import 'package:little_builder_robots/core/l10n/l10n_lookup.dart';
import 'package:little_builder_robots/core/widgets/kid_widgets.dart';
import 'package:little_builder_robots/domain/models/stats.dart';

/// The voiced one-line hint for a robot (WRK-04): its strongest point.
String goodAtKey(Stats stats) {
  if (stats.has(Ability.jetpack)) return 'goodAtJetpack';
  if (stats.has(Ability.grab)) return 'goodAtGrab';
  if (stats.has(Ability.fan)) return 'goodAtFan';
  if (stats.has(Ability.mudproof)) return 'goodAtMudproof';
  final best = [Stat.climb, Stat.jump, Stat.weight, Stat.speed].reduce(
    (a, b) => stats.valueOf(b) > stats.valueOf(a) ? b : a,
  );
  return switch (best) {
    Stat.climb => 'goodAtClimb',
    Stat.jump => 'goodAtJump',
    Stat.weight when stats.weight >= 4 => 'goodAtHeavy',
    _ => 'goodAtSpeed',
  };
}

/// "Good at" (WRK-04): each stat as its icon with 0 to 5 pips, abilities as
/// icons, and a voiced hint with a replay button. Pips are never replaced
/// by a sentence.
class GoodAtPanel extends StatelessWidget {
  const GoodAtPanel({required this.stats, super.key});

  final Stats stats;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final hint = goodAtKey(stats);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.navy, width: AppSizes.outline),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final stat in Stat.values)
            Semantics(
              label: l10n.statLabel(statName(l10n, stat), stats.valueOf(stat)),
              excludeSemantics: true,
              child: Padding(
                padding: EdgeInsets.zero,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statIcon(stat), color: AppColors.navy, size: 24),
                    const SizedBox(width: 8),
                    Pips(value: stats.valueOf(stat)),
                  ],
                ),
              ),
            ),
          if (stats.abilities.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final ability in stats.abilities)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Icon(
                        abilityIcon(ability),
                        color: AppColors.tangerine,
                        size: 28,
                        semanticLabel: abilityName(l10n, ability),
                      ),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 6),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 110),
                child: Text(lookup(l10n, hint), style: AppText.label),
              ),
              const SizedBox(width: 6),
              ReplayVoiceButton(voiceKey: hint),
            ],
          ),
        ],
      ),
    );
  }
}
