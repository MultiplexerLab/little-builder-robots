import 'dart:math';

import 'package:flutter/material.dart';
import 'package:little_builder_robots/app/theme.dart';
import 'package:little_builder_robots/core/widgets/kid_widgets.dart';
import 'package:little_builder_robots/core/widgets/robot_painter.dart';
import 'package:little_builder_robots/domain/models/part.dart';
import 'package:little_builder_robots/domain/models/robot_config.dart';

/// The part of the robot's 100 x 130 box each slot sits in.
Rect slotArea(Slot slot) => switch (slot) {
  Slot.head => const Rect.fromLTWH(14, 0, 72, 58),
  Slot.body => const Rect.fromLTWH(8, 44, 84, 62),
  Slot.arms => const Rect.fromLTWH(4, 30, 92, 70),
  Slot.moves => const Rect.fromLTWH(10, 92, 80, 38),
};

/// The robot drawn by the shared renderer (WRK-13), zoomed to one slot.
class PartThumbnail extends StatelessWidget {
  const PartThumbnail({
    required this.config,
    required this.slot,
    this.size = 72,
    super.key,
  });

  final RobotConfig config;
  final Slot slot;
  final double size;

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: Size.square(size),
    painter: _ZoomPainter(config, slotArea(slot)),
  );
}

class _ZoomPainter extends CustomPainter {
  const _ZoomPainter(this.config, this.area);

  final RobotConfig config;
  final Rect area;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = min(size.width / area.width, size.height / area.height);
    canvas
      ..save()
      // Show only the slot's area, never the whole robot.
      ..clipRect(Offset.zero & size)
      ..translate(
        (size.width - area.width * scale) / 2,
        (size.height - area.height * scale) / 2,
      )
      ..scale(scale)
      ..translate(-area.left, -area.top);
    RobotArt.draw(canvas, RobotLook(config));
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ZoomPainter old) =>
      old.config != config || old.area != area;
}

/// How a locked tile says how to get it, without words (WRK-02).
sealed class TileLock {
  const TileLock();
}

/// Bought with bolts: bolt icon and number.
class CostLock extends TileLock {
  const CostLock(this.cost);
  final int cost;
}

/// Awarded by a course: a map pin with the course number.
class CourseLock extends TileLock {
  const CourseLock(this.courseNumber);
  final int courseNumber;
}

/// A 96 pt part, paint or decal tile (WRK-02, DES-06): selected is pale
/// Sunny with a thick Navy outline; locked is dashed with a padlock.
class PickerTile extends StatelessWidget {
  const PickerTile({
    required this.label,
    required this.child,
    required this.onTap,
    this.selected = false,
    this.lock,
    this.glow = false,
    super.key,
  });

  final String label;
  final Widget child;
  final VoidCallback onTap;
  final bool selected;
  final TileLock? lock;

  /// WRK-12: the part a hint suggested.
  final bool glow;

  @override
  Widget build(BuildContext context) {
    final locked = lock != null;
    final tile = SizedBox.square(
      dimension: AppSizes.partTile,
      child: CustomPaint(
        painter: _TileBorder(selected: selected, dashed: locked),
        child: Stack(
          children: [
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Opacity(opacity: locked ? 0.55 : 1, child: child),
              ),
            ),
            if (locked)
              const Positioned(
                left: 6,
                top: 6,
                child: Icon(
                  Icons.lock_rounded,
                  color: AppColors.navy,
                  size: 22,
                ),
              ),
            if (lock case CostLock(:final cost))
              Positioned(
                right: 4,
                bottom: 4,
                child: _Chip(
                  children: [
                    const BoltIcon(size: 18),
                    const SizedBox(width: 2),
                    Text('$cost', style: AppText.label),
                  ],
                ),
              ),
            if (lock case CourseLock(:final courseNumber))
              Positioned(
                right: 4,
                bottom: 4,
                child: _Chip(
                  children: [
                    const Icon(
                      Icons.location_on_rounded,
                      size: 18,
                      color: AppColors.tangerine,
                    ),
                    Text('$courseNumber', style: AppText.label),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: glow ? Pulse(child: tile) : tile,
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
    decoration: BoxDecoration(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: AppColors.navy, width: 1.5),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: children),
  );
}

class _TileBorder extends CustomPainter {
  const _TileBorder({required this.selected, required this.dashed});

  final bool selected;
  final bool dashed;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      (Offset.zero & size).deflate(2),
      const Radius.circular(20),
    );
    canvas.drawRRect(
      rrect,
      Paint()..color = selected ? AppColors.sunnyPale : AppColors.cloud,
    );
    final stroke = Paint()
      ..color = selected
          ? AppColors.navy
          : AppColors.navy.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = selected ? AppSizes.outlineThick : 2;
    if (!dashed) {
      canvas.drawRRect(rrect, stroke);
      return;
    }
    final path = Path()..addRRect(rrect);
    for (final metric in path.computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += 12) {
        canvas.drawPath(metric.extractPath(d, d + 6), stroke);
      }
    }
  }

  @override
  bool shouldRepaint(_TileBorder old) =>
      old.selected != selected || old.dashed != dashed;
}
