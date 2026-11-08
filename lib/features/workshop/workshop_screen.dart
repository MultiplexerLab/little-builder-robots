import 'dart:async';

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
import 'package:little_builder_robots/core/widgets/robot_painter.dart';
import 'package:little_builder_robots/core/widgets/robot_show_off.dart';
import 'package:little_builder_robots/domain/models/decal.dart';
import 'package:little_builder_robots/domain/models/part.dart';
import 'package:little_builder_robots/domain/rules/unlock_rules.dart';
import 'package:little_builder_robots/features/result/reveal.dart';
import 'package:little_builder_robots/features/workshop/good_at_panel.dart';
import 'package:little_builder_robots/features/workshop/part_tile.dart';
import 'package:little_builder_robots/features/workshop/unlock_dialog.dart';

/// The Workshop tabs: the four slots (WRK-01), then paint (WRK-06) and
/// decals (WRK-10).
enum WorkshopTab { head, body, arms, moves, paint, decal }

extension on WorkshopTab {
  Slot? get slot => switch (this) {
    WorkshopTab.head => Slot.head,
    WorkshopTab.body => Slot.body,
    WorkshopTab.arms => Slot.arms,
    WorkshopTab.moves => Slot.moves,
    _ => null,
  };

  IconData get icon => switch (this) {
    WorkshopTab.head => Icons.smart_toy_rounded,
    WorkshopTab.body => Icons.crop_square_rounded,
    WorkshopTab.arms => Icons.back_hand_outlined,
    WorkshopTab.moves => Icons.directions_walk_rounded,
    WorkshopTab.paint => Icons.palette_rounded,
    WorkshopTab.decal => Icons.auto_awesome_rounded,
  };
}

/// The Workshop (WRK-01 to WRK-13, ONB-02).
class WorkshopScreen extends ConsumerStatefulWidget {
  const WorkshopScreen({super.key});

  @override
  ConsumerState<WorkshopScreen> createState() => _WorkshopScreenState();
}

class _WorkshopScreenState extends ConsumerState<WorkshopScreen> {
  WorkshopTab _tab = WorkshopTab.moves;
  int _snap = 0;
  Trick _trick = Trick.spin;
  int _shake = 0;
  bool _yawn = false;

  /// ONB-02: 0 = point at a part, 1 = point at Test it!, 2 = done.
  int _tutorialStep = 2;

  late final ValueController<String?> _suggestion;

  @override
  void initState() {
    super.initState();
    final audio = ref.read(audioProvider);
    _suggestion = ref.read(suggestedPartProvider.notifier);
    unawaited(audio.music(MusicGroup.workshop));

    final suggested = ref.read(suggestedPartProvider);
    if (suggested != null) {
      final slot = ref.read(gameDataProvider).catalog.byId(suggested).slot;
      _tab = WorkshopTab.values.firstWhere((t) => t.slot == slot);
    }
    final profile = ref.read(profileProvider);
    final firstCourse = ref.read(gameDataProvider).courses.first;
    if (!ref.read(workshopTutorialSeenProvider) &&
        !profile.resultFor(firstCourse.id).completed) {
      _tutorialStep = 0;
      unawaited(audio.voice('tutorialTapPart'));
    }
    // PAR-11: a yawn 5 minutes before the limit.
    if (ref.read(playLimitProvider).windDown) {
      _yawn = true;
      audio.sfx(Sfx.yawn);
      Timer(const Duration(seconds: 2), () {
        if (mounted) setState(() => _yawn = false);
      });
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(revealStickers(context, ref));
    });
  }

  @override
  void deactivate() {
    // WRK-12: the glow lasts until the part is tapped or the child leaves.
    // Providers can't change while the tree is being torn down.
    final suggestion = _suggestion;
    scheduleMicrotask(() => suggestion.set(null));
    super.deactivate();
  }

  void _advanceTutorial() {
    if (_tutorialStep == 0) {
      setState(() => _tutorialStep = 1);
      unawaited(ref.read(audioProvider).voice('tutorialTestIt'));
    }
  }

  Future<void> _tapPart(Part part) async {
    final audio = ref.read(audioProvider);
    final rules = ref.read(unlockRulesProvider);
    final controller = ref.read(progressProvider.notifier);
    final profile = ref.read(profileProvider);
    if (ref.read(suggestedPartProvider) == part.id) {
      ref.read(suggestedPartProvider.notifier).set(null);
    }

    switch (rules.checkPart(profile, part)) {
      case BuyCheck.owned:
        controller.equip(part);
        _equipped(trickFor(part.id));
      case BuyCheck.canBuy:
        final cost = (part.unlock as BoltsUnlock).cost;
        if (await confirmUnlock(context, part, cost) &&
            controller.buyPart(part)) {
          audio.sfx(Sfx.unlock);
          _equipped(trickFor(part.id));
        }
      case BuyCheck.needMoreBolts:
        _needMoreBolts();
      case BuyCheck.notForSale:
        // A course reward: the map pin shows where; a gentle "not yet".
        audio.sfx(Sfx.shake);
        unawaited(audio.voice('partFromCourse'));
    }
  }

  /// WRK-03: snap sound and light haptic, then the robot shows off what
  /// the part does.
  void _equipped([Trick trick = Trick.spin]) {
    ref.read(audioProvider).sfx(Sfx.snap);
    ref.read(hapticsProvider).light();
    setState(() {
      _trick = trick;
      _snap++;
    });
    _advanceTutorial();
  }

  /// WRK-11: shake the counter and say where bolts come from.
  void _needMoreBolts() {
    final audio = ref.read(audioProvider)..sfx(Sfx.shake);
    unawaited(audio.voice('needMoreBolts'));
    setState(() => _shake++);
  }

  Future<void> _tapDecal(Decal decal) async {
    final controller = ref.read(progressProvider.notifier);
    final rules = ref.read(unlockRulesProvider);
    switch (rules.checkDecal(ref.read(profileProvider), decal)) {
      case BuyCheck.owned:
        final current = ref.read(profileProvider).robot.decalId;
        controller.wearDecal(current == decal.id ? null : decal.id);
        _equipped();
      case BuyCheck.canBuy:
        if (await confirmDecal(context, decal) && controller.buyDecal(decal)) {
          ref.read(audioProvider).sfx(Sfx.unlock);
          _equipped();
        }
      case BuyCheck.needMoreBolts || BuyCheck.notForSale:
        _needMoreBolts();
    }
  }

  void _testIt() {
    // WRK-07: the RobotConfig is already saved; open the run.
    ref.read(workshopTutorialSeenProvider.notifier).set(true);
    context.go(AppRoute.run.path);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final profile = ref.watch(profileProvider);
    final stats = ref.watch(robotStatsProvider);
    final course = ref.watch(selectedCourseDataProvider);
    final suggested = ref.watch(suggestedPartProvider);
    final suggestedSlot = suggested == null
        ? null
        : ref.watch(gameDataProvider).catalog.byId(suggested).slot;

    return ChildScaffold(
      topRight: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Which course "Test it!" opens, as a map pin and number.
          Semantics(
            label: l10n.courseLabel(course.index),
            excludeSemantics: true,
            child: Row(
              children: [
                const Icon(
                  Icons.location_on_rounded,
                  color: AppColors.tangerine,
                  size: 32,
                ),
                Text('${course.index}', style: AppText.title),
              ],
            ),
          ),
          const SizedBox(width: 16),
          BoltCounter(bolts: profile.bolts, shake: _shake),
        ],
      ),
      // Laid out to fit a landscape iPhone without scrolling (NFR-19): the
      // slot tabs share the top bar with Home, then robot | tiles | stats.
      body: Stack(
        children: [
          Positioned(
            left: 96,
            top: AppSizes.targetSpacing,
            right: 200,
            child: _Tabs(
              selected: _tab,
              glowSlot: suggestedSlot,
              onSelect: (tab) {
                ref.read(audioProvider).sfx(Sfx.tap);
                setState(() => _tab = tab);
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 96, 16, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 200,
                  child: Column(
                    children: [
                      RobotShowOff(
                        config: profile.robot,
                        trick: _trick,
                        play: _snap,
                        face: _yawn ? RobotFace.sleep : RobotFace.happy,
                      ),
                      const Spacer(),
                      Pulse(
                        active: _tutorialStep == 1,
                        child: ChunkyButton(
                          label: l10n.buttonTestIt,
                          icon: Icons.flag_rounded,
                          style: ChunkyButtonStyle.primary,
                          onPressed: _testIt,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: SingleChildScrollView(
                          child: Wrap(
                            spacing: AppSizes.targetSpacing,
                            runSpacing: AppSizes.targetSpacing,
                            children: _tiles(l10n),
                          ),
                        ),
                      ),
                      if (_tutorialStep == 0)
                        const Positioned(
                          left: 40,
                          top: 50,
                          child: _TutorialHand(),
                        ),
                      if (_tutorialStep == 1)
                        const Positioned(
                          left: 0,
                          bottom: 0,
                          child: _TutorialHand(),
                        ),
                    ],
                  ),
                ),
                // Paint and decals don't change stats, so their tiles get
                // the room.
                if (_tab.slot != null) ...[
                  const SizedBox(width: 16),
                  // Shrinks rather than overflows on short screens.
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.topCenter,
                    child: GoodAtPanel(stats: stats),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _tiles(AppLocalizations l10n) {
    final data = ref.watch(gameDataProvider);
    final profile = ref.watch(profileProvider);
    final robot = profile.robot;
    final suggested = ref.watch(suggestedPartProvider);

    switch (_tab) {
      case WorkshopTab.paint:
        return [
          for (final MapEntry(key: id, value: colour)
              in AppColors.paints.entries)
            PickerTile(
              label: l10n.paintLabel(id),
              selected: robot.colour == id,
              onTap: () {
                ref.read(progressProvider.notifier).paint(id);
                _equipped();
              },
              child: Container(
                decoration: BoxDecoration(
                  color: colour,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.navy, width: 3),
                ),
                child: PartThumbnail(
                  config: robot.copyWith(colour: id, decalId: null),
                  slot: Slot.body,
                ),
              ),
            ),
        ];
      case WorkshopTab.decal:
        return [
          for (final decal in data.decals)
            PickerTile(
              label: l10n.decalLabel(decal.id),
              selected: robot.decalId == decal.id,
              lock: profile.unlockedDecalIds.contains(decal.id)
                  ? null
                  : CostLock(decal.cost),
              onTap: () => _tapDecal(decal),
              child: PartThumbnail(
                config: robot.copyWith(decalId: decal.id),
                slot: Slot.body,
              ),
            ),
        ];
      case WorkshopTab.head ||
          WorkshopTab.body ||
          WorkshopTab.arms ||
          WorkshopTab.moves:
        final slot = _tab.slot!;
        return [
          for (final part in data.catalog.inSlot(slot))
            PickerTile(
              label: lookup(l10n, part.nameKey),
              selected: robot.partIdFor(slot) == part.id,
              glow: suggested == part.id,
              lock: profile.unlockedPartIds.contains(part.id)
                  ? null
                  : switch (part.unlock) {
                      BoltsUnlock(:final cost) => CostLock(cost),
                      RewardUnlock(:final courseId) => CourseLock(
                        data.courseById(courseId).index,
                      ),
                      StartUnlock() => null,
                    },
              onTap: () => _tapPart(part),
              child: PartThumbnail(
                config: robot.withPart(slot, part.id),
                slot: slot,
              ),
            ),
        ];
    }
  }
}

/// WRK-10: the confirm for a decal, the same kid-level shape as parts.
Future<bool> confirmDecal(BuildContext context, Decal decal) async =>
    await showDialog<bool>(
      context: context,
      barrierColor: AppColors.scrim,
      builder: (context) {
        final l10n = AppLocalizations.of(context);
        return Dialog(
          backgroundColor: AppColors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(32),
            side: const BorderSide(
              color: AppColors.navy,
              width: AppSizes.outline,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const BoltIcon(),
                const SizedBox(width: 4),
                Text('${decal.cost}', style: AppText.title),
                const SizedBox(width: 24),
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
          ),
        );
      },
    ) ??
    false;

class _Tabs extends StatelessWidget {
  const _Tabs({
    required this.selected,
    required this.onSelect,
    this.glowSlot,
  });

  final WorkshopTab selected;
  final ValueChanged<WorkshopTab> onSelect;
  final Slot? glowSlot;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final tab in WorkshopTab.values)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Pulse(
                active: tab.slot != null && tab.slot == glowSlot,
                child: Semantics(
                  button: true,
                  selected: tab == selected,
                  label: l10n.tabLabel(tab.name),
                  excludeSemantics: true,
                  child: GestureDetector(
                    onTap: () => onSelect(tab),
                    child: Container(
                      constraints: const BoxConstraints(
                        minWidth: 72,
                        minHeight: AppSizes.childTarget,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        // DES-06 selected style: shape and outline, not
                        // colour alone (WRK-01).
                        color: tab == selected
                            ? AppColors.sunnyPale
                            : AppColors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: AppColors.navy,
                          width: tab == selected
                              ? AppSizes.outlineThick
                              : AppSizes.outline,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(tab.icon, color: AppColors.navy, size: 28),
                          Text(l10n.tabLabel(tab.name), style: AppText.label),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// ONB-02: an animated hand showing where to tap.
class _TutorialHand extends StatelessWidget {
  const _TutorialHand();

  @override
  Widget build(BuildContext context) => const IgnorePointer(
    child: Pulse(
      child: Icon(
        Icons.touch_app_rounded,
        size: 64,
        color: AppColors.navy,
      ),
    ),
  );
}
