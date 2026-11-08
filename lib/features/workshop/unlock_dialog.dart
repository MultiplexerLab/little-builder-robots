import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:little_builder_robots/app/providers.dart';
import 'package:little_builder_robots/app/theme.dart';
import 'package:little_builder_robots/core/l10n/gen/app_localizations.dart';
import 'package:little_builder_robots/core/l10n/l10n_lookup.dart';
import 'package:little_builder_robots/core/widgets/kid_widgets.dart';
import 'package:little_builder_robots/domain/models/part.dart';
import 'package:little_builder_robots/features/workshop/part_tile.dart';

/// The kid-level unlock confirm (WRK-05): the part, its cost, its ability
/// and every stat it changes against the part in that slot now, from
/// stat_calculator. Big cross, big tick (primary). Returns true to buy.
Future<bool> confirmUnlock(BuildContext context, Part part, int cost) async =>
    await showDialog<bool>(
      context: context,
      barrierColor: AppColors.scrim,
      builder: (context) => _UnlockDialog(part: part, cost: cost),
    ) ??
    false;

class _UnlockDialog extends ConsumerWidget {
  const _UnlockDialog({required this.part, required this.cost});

  final Part part;
  final int cost;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final robot = ref.watch(profileProvider).robot;
    final changes = ref
        .watch(statCalculatorProvider)
        .changesIfEquipped(robot, part);
    return Dialog(
      backgroundColor: AppColors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(32),
        side: const BorderSide(color: AppColors.navy, width: AppSizes.outline),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  PartThumbnail(
                    config: robot.withPart(part.slot, part.id),
                    slot: part.slot,
                    size: 110,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const BoltIcon(),
                      const SizedBox(width: 4),
                      Text('$cost', style: AppText.title),
                      if (part.ability != null) ...[
                        const SizedBox(width: 12),
                        Icon(
                          abilityIcon(part.ability!),
                          color: AppColors.tangerine,
                          size: 32,
                          semanticLabel: abilityName(l10n, part.ability!),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
              const SizedBox(width: 24),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final MapEntry(key: stat, value: change)
                      in changes.entries)
                    Semantics(
                      label: l10n.statChangeLabel(
                        statName(l10n, stat),
                        change.before,
                        change.after,
                      ),
                      excludeSemantics: true,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(statIcon(stat), size: 28),
                            const SizedBox(width: 8),
                            Pips(
                              value: change.after,
                              before: change.before,
                              size: 18,
                            ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      RoundIconButton(
                        icon: Icons.close_rounded,
                        label: l10n.buttonNo,
                        size: 80,
                        onPressed: () => Navigator.pop(context, false),
                      ),
                      const SizedBox(width: 24),
                      RoundIconButton(
                        icon: Icons.check_rounded,
                        label: l10n.buttonYes,
                        size: AppSizes.childPrimary,
                        primary: true,
                        onPressed: () => Navigator.pop(context, true),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
