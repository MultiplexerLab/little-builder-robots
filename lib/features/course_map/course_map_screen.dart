import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:little_builder_robots/app/providers.dart';
import 'package:little_builder_robots/app/router.dart';
import 'package:little_builder_robots/app/services.dart';
import 'package:little_builder_robots/app/theme.dart';
import 'package:little_builder_robots/core/audio/audio_service.dart';
import 'package:little_builder_robots/core/l10n/gen/app_localizations.dart';
import 'package:little_builder_robots/core/l10n/l10n_lookup.dart';
import 'package:little_builder_robots/core/widgets/chunky_button.dart';
import 'package:little_builder_robots/core/widgets/kid_widgets.dart';
import 'package:little_builder_robots/domain/models/course.dart';
import 'package:little_builder_robots/domain/rules/obstacle_needs.dart';
import 'package:little_builder_robots/features/course_map/course_node.dart';

/// The Course map (MAP-01 to MAP-08): World 1 as one winding path of 15
/// nodes that fits the screen, so no scrolling is needed (NFR-19).
class CourseMapScreen extends ConsumerStatefulWidget {
  const CourseMapScreen({super.key});

  @override
  ConsumerState<CourseMapScreen> createState() => _CourseMapScreenState();
}

class _CourseMapScreenState extends ConsumerState<CourseMapScreen> {
  Course? _picked;

  @override
  void initState() {
    super.initState();
    unawaited(ref.read(audioProvider).music(MusicGroup.menus));
  }

  void _tap(Course course, bool playable) {
    final audio = ref.read(audioProvider);
    if (!playable) {
      audio.sfx(Sfx.shake);
      return;
    }
    audio.sfx(Sfx.tap);
    ref.read(selectedCourseProvider.notifier).select(course.id);
    setState(() => _picked = course);
    // MAP-04: a voiced hint about the course's main obstacle.
    unawaited(audio.voice(course.hintKey));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final data = ref.watch(gameDataProvider);
    final profile = ref.watch(profileProvider);
    final rules = ref.watch(unlockRulesProvider);
    final coach = ref.watch(obstacleCoachProvider);
    final courses = data.courses;
    final next = SelectedCourseController.nextCourse(courses, profile);
    final stars = courses.fold(0, (s, c) => s + profile.resultFor(c.id).stars);

    return ChildScaffold(
      background: AppColors.grass,
      topRight: Semantics(
        label: l10n.starsLabel(stars, courses.length * 3),
        excludeSemantics: true,
        child: Container(
          padding: const EdgeInsets.fromLTRB(8, 6, 16, 6),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: AppColors.navy, width: AppSizes.outline),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.star_rounded, color: AppColors.sunny, size: 32),
              const SizedBox(width: 4),
              Text(
                '$stars / ${courses.length * 3}',
                style: AppText.button,
              ),
            ],
          ),
        ),
      ),
      body: LayoutBuilder(
        builder: (context, box) {
          final points = mapPoints(
            courses.length,
            Size(box.maxWidth, box.maxHeight),
            top: 96,
          );
          return Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(painter: MapPathPainter(points)),
              ),
              for (final (i, course) in courses.indexed)
                Positioned(
                  left: points[i].dx - CourseNode.slot / 2,
                  top: points[i].dy - CourseNode.slot / 2,
                  child: CourseNode(
                    number: course.index,
                    stars: profile.resultFor(course.id).stars,
                    state: profile.resultFor(course.id).completed
                        ? (course == next && course != courses.last
                              ? NodeState.next
                              : NodeState.done)
                        : course == next
                        ? NodeState.next
                        : rules.isCourseUnlocked(profile, course)
                        ? NodeState.next
                        : NodeState.locked,
                    robot: course == next ? profile.robot : null,
                    onTap: () =>
                        _tap(course, rules.isCourseUnlocked(profile, course)),
                  ),
                ),
              if (_picked != null)
                _HintBubble(
                  course: _picked!,
                  anchor: points[courses.indexOf(_picked!)],
                  area: Size(box.maxWidth, box.maxHeight),
                  need: coach.mainNeed(_picked!),
                  text: lookup(l10n, _picked!.hintKey),
                  onGo: () => context.go(AppRoute.workshop.path),
                  onDismiss: () => setState(() => _picked = null),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// Node centres along a snake of rows: left to right, then right to left.
/// The drawn path joins them as one line (MAP-08).
List<Offset> mapPoints(int count, Size size, {double top = 0}) {
  const perRow = 5;
  final rows = (count / perRow).ceil();
  final rowHeight = (size.height - top) / rows;
  const margin = CourseNode.slot * 0.75;
  final step = (size.width - 2 * margin) / (perRow - 1);
  return [
    for (var i = 0; i < count; i++)
      Offset(
        margin +
            step *
                ((i ~/ perRow).isEven ? i % perRow : perRow - 1 - i % perRow),
        top + rowHeight * (i ~/ perRow + 0.5) + 10 * sin(i * 1.3),
      ),
  ];
}

class MapPathPainter extends CustomPainter {
  const MapPathPainter(this.points);

  final List<Offset> points;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) {
      final a = points[i - 1];
      final b = points[i];
      if ((a.dy - b.dy).abs() > 30) {
        // Turn at the row end with a smooth U.
        final side = a.dx > size.width / 2 ? 1 : -1;
        path.cubicTo(
          a.dx + side * 70,
          a.dy,
          b.dx + side * 70,
          b.dy,
          b.dx,
          b.dy,
        );
      } else {
        path.quadraticBezierTo(
          (a.dx + b.dx) / 2,
          (a.dy + b.dy) / 2 - 12,
          b.dx,
          b.dy,
        );
      }
    }
    canvas
      ..drawPath(
        path,
        Paint()
          ..color = AppColors.navy
          ..style = PaintingStyle.stroke
          ..strokeWidth = 22
          ..strokeCap = StrokeCap.round,
      )
      ..drawPath(
        path,
        Paint()
          ..color = AppColors.cloud
          ..style = PaintingStyle.stroke
          ..strokeWidth = 14
          ..strokeCap = StrokeCap.round,
      );
  }

  @override
  bool shouldRepaint(MapPathPainter old) => old.points != points;
}

/// MAP-04 and MAP-08: the voiced hint bubble with the need's icon, a 64 pt
/// replay button and a 96 pt Go button.
class _HintBubble extends StatelessWidget {
  const _HintBubble({
    required this.course,
    required this.anchor,
    required this.area,
    required this.need,
    required this.text,
    required this.onGo,
    required this.onDismiss,
  });

  final Course course;
  final Offset anchor;
  final Size area;
  final Need? need;
  final String text;
  final VoidCallback onGo;
  final VoidCallback onDismiss;

  static const _width = 500.0;
  static const _height = 130.0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final left = (anchor.dx - _width / 2).clamp(8.0, area.width - _width - 8);
    final below = anchor.dy + CourseNode.slot / 2 + _height < area.height;
    final top = below
        ? anchor.dy + CourseNode.slot / 2
        : anchor.dy - CourseNode.slot / 2 - _height;
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: onDismiss,
          ),
        ),
        Positioned(
          left: left,
          top: top.clamp(0.0, area.height - _height),
          child: Container(
            width: _width,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: AppColors.navy,
                width: AppSizes.outline,
              ),
            ),
            child: Row(
              children: [
                if (need != null) NeedBadge(need: need!, size: 56),
                const SizedBox(width: 8),
                Expanded(child: Text(text, style: AppText.body)),
                const SizedBox(width: 8),
                // Side by side, so the bubble stays short enough to fit
                // under any node.
                ReplayVoiceButton(voiceKey: course.hintKey),
                const SizedBox(width: 8),
                ChunkyButton(
                  label: l10n.buttonGo,
                  style: ChunkyButtonStyle.primary,
                  onPressed: onGo,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
