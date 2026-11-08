import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:little_builder_robots/app/providers.dart';
import 'package:little_builder_robots/app/services.dart';
import 'package:little_builder_robots/app/theme.dart';
import 'package:little_builder_robots/core/audio/audio_service.dart';
import 'package:little_builder_robots/core/l10n/gen/app_localizations.dart';
import 'package:little_builder_robots/core/widgets/chunky_button.dart';
import 'package:little_builder_robots/core/widgets/kid_widgets.dart';
import 'package:little_builder_robots/domain/models/part.dart';
import 'package:little_builder_robots/domain/models/stats.dart';
import 'package:little_builder_robots/features/stickers/sticker_icons.dart';
import 'package:little_builder_robots/features/workshop/part_tile.dart';

/// RES-04: a new part reveal with every stat it changes and a 96 pt
/// "Try it on" button.
Future<void> revealPart(BuildContext context, Part part) => showDialog<void>(
  context: context,
  barrierColor: AppColors.scrim,
  builder: (context) => _PartReveal(part: part),
);

/// STK-02: shows stickers earned since the last reveal, then marks them
/// seen. Called on Result and Workshop, never mid-run.
Future<void> revealStickers(BuildContext context, WidgetRef ref) async {
  final ids = ref.read(profileProvider).unrevealedStickerIds;
  if (ids.isEmpty) return;
  final stickers = ref
      .read(gameDataProvider)
      .stickers
      .where((s) => ids.contains(s.id))
      .toList();
  ref.read(progressProvider.notifier).markStickersRevealed();
  if (stickers.isEmpty || !context.mounted) return;
  await showDialog<void>(
    context: context,
    barrierColor: AppColors.scrim,
    builder: (context) => _Reveal(
      title: AppLocalizations.of(context).newStickerTitle,
      voiceKey: 'newStickerTitle',
      child: Wrap(
        spacing: 12,
        children: [
          for (final s in stickers.take(6))
            StickerBadge(rule: s.rule, size: 96),
        ],
      ),
    ),
  );
}

class _PartReveal extends ConsumerWidget {
  const _PartReveal({required this.part});

  final Part part;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final robot = ref.watch(profileProvider).robot;
    return _Reveal(
      title: l10n.newPartTitle,
      voiceKey: 'newPartTitle',
      action: ChunkyButton(
        label: l10n.buttonTryItOn,
        icon: Icons.build_rounded,
        style: ChunkyButtonStyle.primary,
        onPressed: () {
          ref.read(progressProvider.notifier).equip(part);
          ref.read(audioProvider).sfx(Sfx.snap);
          Navigator.pop(context);
        },
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          PartThumbnail(
            config: robot.withPart(part.slot, part.id),
            slot: part.slot,
            size: 120,
          ),
          const SizedBox(width: 16),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Every stat the part changes, as icon and +/- pips.
              for (final stat in Stat.values)
                if (part.mods.valueOf(stat) != 0)
                  Row(
                    children: [
                      Icon(statIcon(stat), size: 28),
                      const SizedBox(width: 6),
                      Icon(
                        part.mods.valueOf(stat) > 0
                            ? Icons.arrow_upward_rounded
                            : Icons.arrow_downward_rounded,
                        color: part.mods.valueOf(stat) > 0
                            ? AppColors.success
                            : AppColors.danger,
                      ),
                      Pips(
                        value: part.mods.valueOf(stat).abs(),
                        max: part.mods.valueOf(stat).abs(),
                        size: 16,
                      ),
                    ],
                  ),
              if (part.ability != null)
                Icon(
                  abilityIcon(part.ability!),
                  color: AppColors.tangerine,
                  size: 36,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A reveal card: scales in, tap anywhere to skip (NFR-21), voiced title.
class _Reveal extends ConsumerStatefulWidget {
  const _Reveal({
    required this.title,
    required this.voiceKey,
    required this.child,
    this.action,
  });

  final String title;
  final String voiceKey;
  final Widget child;
  final Widget? action;

  @override
  ConsumerState<_Reveal> createState() => _RevealState();
}

class _RevealState extends ConsumerState<_Reveal> {
  @override
  void initState() {
    super.initState();
    final audio = ref.read(audioProvider)..sfx(Sfx.reveal);
    unawaited(audio.voice(widget.voiceKey));
  }

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.disableAnimationsOf(context);
    final card = Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: AppColors.white, width: AppSizes.outline),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(widget.title, style: AppText.title),
          const SizedBox(height: 12),
          widget.child,
          const SizedBox(height: 16),
          widget.action ??
              RoundIconButton(
                icon: Icons.check_rounded,
                label: AppLocalizations.of(context).buttonOk,
                size: AppSizes.childPrimary,
                primary: true,
                onPressed: () => Navigator.pop(context),
              ),
        ],
      ),
    );
    return Center(
      child: SingleChildScrollView(
        child: Material(
          type: MaterialType.transparency,
          child: reduce
              ? card
              : TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.6, end: 1),
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutBack,
                  builder: (context, s, child) =>
                      Transform.scale(scale: s, child: child),
                  child: card,
                ),
        ),
      ),
    );
  }
}
