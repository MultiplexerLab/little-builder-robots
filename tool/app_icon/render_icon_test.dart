// Renders the app icon from the game's own robot art (WRK-13) as raw RGBA
// files, one per pixel size. tool/app_icon/write_icons.py turns them into
// the iOS and Android icon PNGs (opaque, as the App Store requires).
//
// Run from the project root: python tool/app_icon/write_icons.py
// (it calls `flutter test tool/app_icon/render_icon_test.dart`).
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:little_builder_robots/app/theme.dart';
import 'package:little_builder_robots/core/widgets/robot_painter.dart';
import 'package:little_builder_robots/domain/models/robot_config.dart';

const sizes = [
  20, 29, 40, 48, 58, 60, 72, 76, 80, 87, 96, 120, 144, 152, 167, 180, 192,
  1024, //
];

const robot = RobotConfig(
  headId: 'head_antenna',
  bodyId: 'body_light_frame',
  armsId: 'arms_grabber',
  movesId: 'moves_wheels',
  colour: 'roboBlue',
  decalId: 'decal_stars',
);

void paintIcon(Canvas canvas, double size) {
  canvas
    ..scale(size / 1024)
    // Sunny sky, a cloud and grass (DES-01 colours only).
    ..drawRect(
      const Rect.fromLTWH(0, 0, 1024, 1024),
      Paint()..color = AppColors.sunny,
    )
    ..drawCircle(const Offset(512, 470), 380, Paint()..color = AppColors.sky)
    ..drawRect(
      const Rect.fromLTWH(0, 820, 1024, 204),
      Paint()..color = AppColors.grass,
    )
    ..drawLine(
      const Offset(0, 820),
      const Offset(1024, 820),
      Paint()
        ..color = AppColors.navy
        ..strokeWidth = 16,
    );
  RobotArt.paintInto(
    canvas..translate(212, 140),
    const Size(600, 690),
    const RobotLook(robot, face: RobotFace.cheer, armsUp: true),
  );
}

void main() {
  testWidgets('render app icon', (tester) async {
    final out = Directory('build/app_icon')..createSync(recursive: true);
    await tester.runAsync(() async {
      for (final size in sizes) {
        final recorder = ui.PictureRecorder();
        paintIcon(Canvas(recorder), size.toDouble());
        final image = await recorder.endRecording().toImage(size, size);
        final bytes = await image.toByteData();
        File(
          '${out.path}/icon_$size.rgba',
        ).writeAsBytesSync(bytes!.buffer.asUint8List());
      }
    });
  });
}
