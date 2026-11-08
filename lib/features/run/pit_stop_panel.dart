import 'package:flutter/material.dart';
import 'package:little_builder_robots/app/theme.dart';
import 'package:little_builder_robots/core/l10n/gen/app_localizations.dart';
import 'package:little_builder_robots/core/l10n/l10n_lookup.dart';
import 'package:little_builder_robots/core/widgets/chunky_button.dart';
import 'package:little_builder_robots/core/widgets/kid_widgets.dart';
import 'package:little_builder_robots/domain/models/part.dart';
import 'package:little_builder_robots/domain/models/part_catalog.dart';
import 'package:little_builder_robots/domain/models/robot_config.dart';
import 'package:little_builder_robots/domain/rules/obstacle_needs.dart';
import 'package:little_builder_robots/features/workshop/part_tile.dart';

/// RUN-11: the pit stop panel. The robot, the next obstacle's icon, and the
/// four slots with owned parts only. A tap equips; Go continues.
class PitStopPanel extends StatelessWidget {
  const PitStopPanel({
    required this.robot,
    required this.catalog,
    required this.owned,
    required this.nextNeed,
    required this.onSwap,
    required this.onGo,
    this.glowPartId,
    super.key,
  });

  final RobotConfig robot;
  final PartCatalog catalog;
  final Set<String> owned;
  final ObstacleNeed? nextNeed;
  final ValueChanged<Part> onSwap;
  final VoidCallback onGo;

  /// The part a hint suggested.
  final String? glowPartId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ColoredBox(
      color: AppColors.scrim,
      child: SafeArea(
        child: Center(
          child: Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.sky,
              borderRadius: BorderRadius.circular(32),
              border: Border.all(
                color: AppColors.white,
                width: AppSizes.outlineThick,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.build_rounded,
                      size: 36,
                      color: AppColors.navy,
                    ),
                    RobotView(config: robot, size: 130),
                    if (nextNeed != null) ...[
                      const SizedBox(height: 8),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.arrow_forward_rounded, size: 28),
                          NeedBadge(need: nextNeed!.need, size: 52),
                          if (nextNeed!.pips > 0) ...[
                            const SizedBox(width: 4),
                            Pips(value: nextNeed!.pips, max: nextNeed!.pips),
                          ],
                        ],
                      ),
                    ],
                  ],
                ),
                const SizedBox(width: 16),
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final slot in Slot.values)
                          if (slot != Slot.head)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Wrap(
                                spacing: 8,
                                children: [
                                  for (final part in catalog.inSlot(slot))
                                    if (owned.contains(part.id))
                                      SizedBox.square(
                                        dimension: AppSizes.partTile,
                                        child: PickerTile(
                                          label: lookup(l10n, part.nameKey),
                                          selected:
                                              robot.partIdFor(slot) == part.id,
                                          glow: glowPartId == part.id,
                                          onTap: () => onSwap(part),
                                          child: PartThumbnail(
                                            config: robot.withPart(
                                              slot,
                                              part.id,
                                            ),
                                            slot: slot,
                                          ),
                                        ),
                                      ),
                                ],
                              ),
                            ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                ChunkyButton(
                  label: l10n.buttonGo,
                  icon: Icons.play_arrow_rounded,
                  style: ChunkyButtonStyle.primary,
                  onPressed: onGo,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
