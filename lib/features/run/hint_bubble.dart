import 'package:flutter/material.dart';
import 'package:little_builder_robots/app/theme.dart';
import 'package:little_builder_robots/core/l10n/gen/app_localizations.dart';
import 'package:little_builder_robots/core/widgets/kid_widgets.dart';
import 'package:little_builder_robots/domain/models/robot_config.dart';
import 'package:little_builder_robots/features/run/run_controller.dart';
import 'package:little_builder_robots/features/workshop/part_tile.dart';

/// RUN-13 step 3: "Try new parts?" A small bubble next to the robot that
/// covers no more than a third of the screen and never dims the course. It
/// shows the current part and the suggested part with an arrow, and has one
/// button: the 96 pt wrench. No lives, tries or counters.
class HintBubble extends StatelessWidget {
  const HintBubble({
    required this.hint,
    required this.robot,
    required this.onWrench,
    super.key,
  });

  final HintState hint;
  final RobotConfig robot;
  final VoidCallback onWrench;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final suggestion = hint.suggestion;
    return LayoutBuilder(
      builder: (context, box) => ConstrainedBox(
        constraints: BoxConstraints(maxWidth: box.maxWidth / 3 + 40),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.navy, width: AppSizes.outline),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (suggestion != null) ...[
                PartThumbnail(config: robot, slot: suggestion.slot, size: 52),
                const Icon(Icons.arrow_forward_rounded, size: 28),
                Stack(
                  children: [
                    PartThumbnail(
                      config: robot.withPart(suggestion.slot, suggestion.id),
                      slot: suggestion.slot,
                      size: 52,
                    ),
                    if (!hint.suggestionOwned)
                      const Positioned(
                        right: 0,
                        top: 0,
                        child: Icon(Icons.lock_rounded, size: 18),
                      ),
                  ],
                ),
              ] else
                NeedBadge(need: hint.need.need, size: 52),
              const SizedBox(width: 8),
              RoundIconButton(
                icon: Icons.build_rounded,
                label: l10n.tryNewParts,
                size: AppSizes.childPrimary,
                primary: true,
                onPressed: onWrench,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
