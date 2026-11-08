import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:little_builder_robots/app/providers.dart';
import 'package:little_builder_robots/app/services.dart';
import 'package:little_builder_robots/app/theme.dart';
import 'package:little_builder_robots/core/audio/audio_service.dart';
import 'package:little_builder_robots/core/l10n/gen/app_localizations.dart';
import 'package:little_builder_robots/core/l10n/l10n_lookup.dart';
import 'package:little_builder_robots/core/widgets/kid_widgets.dart';
import 'package:little_builder_robots/features/stickers/sticker_icons.dart';

/// The sticker book (STK-01 to STK-04): earned stickers in colour, the rest
/// as silhouettes that play a voiced clue when tapped.
class StickerBookScreen extends ConsumerStatefulWidget {
  const StickerBookScreen({super.key});

  @override
  ConsumerState<StickerBookScreen> createState() => _StickerBookScreenState();
}

class _StickerBookScreenState extends ConsumerState<StickerBookScreen> {
  String? _clueKey;

  @override
  void initState() {
    super.initState();
    unawaited(ref.read(audioProvider).music(MusicGroup.menus));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final stickers = ref.watch(gameDataProvider).stickers;
    final earned = ref.watch(profileProvider).stickerIds;
    final audio = ref.read(audioProvider);
    return ChildScaffold(
      topRight: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.menu_book_rounded, size: 32),
          const SizedBox(width: 8),
          Text(
            '${earned.length} / ${stickers.length}',
            style: AppText.button,
          ),
        ],
      ),
      body: Stack(
        children: [
          // The clue sits in the top bar, so it never pushes the grid.
          if (_clueKey != null)
            Positioned(
              left: 96,
              right: 150,
              top: AppSizes.targetSpacing,
              child: Row(
                children: [
                  Flexible(
                    child: Text(lookup(l10n, _clueKey!), style: AppText.body),
                  ),
                  const SizedBox(width: 8),
                  ReplayVoiceButton(voiceKey: _clueKey!),
                ],
              ),
            ),
          Positioned.fill(
            top: 92,
            child: LayoutBuilder(
              builder: (context, box) {
                // All 24 stickers fit on screen; tapping only (NFR-19).
                const columns = 8;
                final rows = (stickers.length / columns).ceil();
                const gap = 8.0;
                final size = [
                  (box.maxWidth - 32 - gap * (columns - 1)) / columns,
                  (box.maxHeight - 8 - gap * (rows - 1)) / rows,
                ].reduce((a, b) => a < b ? a : b);
                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Wrap(
                    spacing: gap,
                    runSpacing: gap,
                    alignment: WrapAlignment.center,
                    children: [
                      for (final sticker in stickers)
                        Semantics(
                          button: true,
                          label: earned.contains(sticker.id)
                              ? lookup(l10n, sticker.clueKey)
                              : l10n.stickerLocked,
                          excludeSemantics: true,
                          child: GestureDetector(
                            onTap: () {
                              audio.sfx(Sfx.tap);
                              setState(() => _clueKey = sticker.clueKey);
                              // STK-03: a voiced clue about how to get it.
                              unawaited(audio.voice(sticker.clueKey));
                            },
                            child: StickerBadge(
                              rule: sticker.rule,
                              earned: earned.contains(sticker.id),
                              size: size,
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
