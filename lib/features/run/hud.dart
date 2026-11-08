import 'package:flutter/material.dart';
import 'package:little_builder_robots/app/theme.dart';
import 'package:little_builder_robots/core/l10n/gen/app_localizations.dart';
import 'package:little_builder_robots/core/widgets/kid_widgets.dart';
import 'package:little_builder_robots/domain/models/course.dart';
import 'package:little_builder_robots/domain/sim/run_state.dart';

/// RUN-07: a progress bar with a dot per checkpoint (a wrench for pit
/// stops), the finish flag and the robot's place on it.
class ProgressTrack extends StatelessWidget {
  const ProgressTrack({required this.course, required this.state, super.key});

  final Course course;
  final RunState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final progress = (state.x / course.lengthPx).clamp(0.0, 1.0);
    return Semantics(
      label: l10n.progressLabel((progress * 100).round()),
      excludeSemantics: true,
      child: SizedBox(
        height: 44,
        child: LayoutBuilder(
          builder: (context, box) {
            final w = box.maxWidth - 32;
            double at(double x) => 16 + w * (x / course.lengthPx).clamp(0, 1);
            return Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.centerLeft,
              children: [
                Positioned(
                  left: 16,
                  right: 16,
                  child: Container(
                    height: 12,
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppColors.navy, width: 2),
                    ),
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: progress,
                      child: Container(color: AppColors.mint),
                    ),
                  ),
                ),
                for (final (i, cp) in course.checkpoints.indexed)
                  if (i > 0)
                    Positioned(
                      left: at(cp.x) - 12,
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: i <= state.checkpointIndex
                              ? AppColors.success
                              : AppColors.white,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.navy, width: 2),
                        ),
                        child: cp.pitStop
                            ? Icon(
                                Icons.build_rounded,
                                size: 14,
                                color: i <= state.checkpointIndex
                                    ? AppColors.white
                                    : AppColors.navy,
                              )
                            : null,
                      ),
                    ),
                Positioned(
                  left: at(course.lengthPx) - 8,
                  child: const Icon(
                    Icons.sports_score_rounded,
                    color: AppColors.navy,
                    size: 30,
                  ),
                ),
                Positioned(
                  left: at(state.x) - 10,
                  child: const Icon(
                    Icons.smart_toy_rounded,
                    color: AppColors.navy,
                    size: 22,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// RUN-07: this run's bolts in a read-only pill (DES-12).
class RunBolts extends StatelessWidget {
  const RunBolts({required this.collected, super.key});

  final int collected;

  @override
  Widget build(BuildContext context) => BoltCounter(bolts: collected);
}

/// The course's bolts as icons, collected filled and missing outlined
/// (RUN-08), never as a sentence.
class BoltRow extends StatelessWidget {
  const BoltRow({required this.collected, required this.total, super.key});

  final int collected;
  final int total;

  @override
  Widget build(BuildContext context) => Semantics(
    label: AppLocalizations.of(context).boltsOfLabel(collected, total),
    excludeSemantics: true,
    child: Wrap(
      spacing: 4,
      runSpacing: 4,
      children: [
        for (var i = 0; i < total; i++)
          BoltIcon(size: 30, filled: i < collected),
      ],
    ),
  );
}

/// Jetpack fuel, shown only with a Jetpack.
class FuelGauge extends StatelessWidget {
  const FuelGauge({required this.fuel, required this.max, super.key});

  final double fuel;
  final double max;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      const Icon(Icons.local_gas_station_rounded, color: AppColors.navy),
      const SizedBox(width: 4),
      Container(
        width: 80,
        height: 14,
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(7),
          border: Border.all(color: AppColors.navy, width: 2),
        ),
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: max <= 0 ? 0 : (fuel / max).clamp(0.0, 1.0),
          child: Container(color: AppColors.tangerine),
        ),
      ),
    ],
  );
}
