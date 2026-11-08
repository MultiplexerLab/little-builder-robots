import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:little_builder_robots/app/links.dart';
import 'package:little_builder_robots/app/providers.dart';
import 'package:little_builder_robots/app/router.dart';
import 'package:little_builder_robots/app/theme.dart';
import 'package:little_builder_robots/core/l10n/gen/app_localizations.dart';
import 'package:little_builder_robots/core/utils/play_clock.dart';
import 'package:little_builder_robots/domain/models/settings.dart';
import 'package:url_launcher/url_launcher.dart';

/// Grown-ups settings (PAR-04 to PAR-10, PAR-12, HLP-01): Nunito Sans, white
/// cards on Cloud, no outlines (DES-11). Reached only through the Parent
/// gate (PAR-03). No purchase UI in v1.0 (PAR-12).
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late final ValueController<bool> _gate;

  @override
  void initState() {
    super.initState();
    _gate = ref.read(gatePassedProvider.notifier);
  }

  @override
  void dispose() {
    // The next visit asks again (PAR-03). Providers can't change while
    // the tree is being torn down, so this waits a moment.
    final gate = _gate;
    scheduleMicrotask(() => gate.set(false));
    super.dispose();
  }

  Future<void> _resetProgress() async {
    final l10n = AppLocalizations.of(context);
    Future<bool> confirm(String title, String body, String action) async =>
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(title),
            content: Text(body),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(l10n.buttonCancel),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                style: TextButton.styleFrom(foregroundColor: AppColors.danger),
                child: Text(action),
              ),
            ],
          ),
        ) ??
        false;

    // PAR-04: reset needs a second confirm.
    if (!await confirm(l10n.resetTitle, l10n.resetBody, l10n.resetAction)) {
      return;
    }
    if (!mounted) return;
    if (!await confirm(
      l10n.resetSureTitle,
      l10n.resetSureBody,
      l10n.resetAction,
    )) {
      return;
    }
    ref.read(progressProvider.notifier).reset();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final settings = ref.watch(settingsProvider);
    final profile = ref.watch(profileProvider);
    final data = ref.watch(gameDataProvider);
    final update = ref.read(settingsProvider.notifier).update;
    final theme = AppTheme.grownUps();

    final now = DateTime.now();
    final weekSeconds = [
      for (var d = 0; d < 7; d++)
        profile.playSecondsByDay[dayKey(now.subtract(Duration(days: d)))] ?? 0,
    ].fold(0, (a, b) => a + b);
    final done = data.courses
        .where((c) => profile.resultFor(c.id).completed)
        .length;
    final stars = data.courses.fold(
      0,
      (sum, c) => sum + profile.resultFor(c.id).stars,
    );

    Widget toggle(
      String label, {
      required bool value,
      required Settings Function({required bool on}) change,
    }) => MergeSemantics(
      child: InkWell(
        onTap: () => update((_) => change(on: !value)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: AppSizes.grownUpsTarget,
          ),
          child: Row(
            children: [
              Expanded(child: Text(label, style: theme.textTheme.bodyLarge)),
              Switch(
                value: value,
                onChanged: (v) => update((_) => change(on: v)),
              ),
            ],
          ),
        ),
      ),
    );

    return Theme(
      data: theme,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: AppColors.cloud,
          leading: IconButton(
            tooltip: l10n.buttonClose,
            icon: const Icon(Icons.close_rounded),
            onPressed: () => context.go(AppRoute.home.path),
          ),
          title: Text(l10n.grownUpsTitle, style: theme.textTheme.titleLarge),
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _Card(
              children: [
                Row(
                  children: [
                    const Icon(Icons.shield_outlined, color: AppColors.success),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        l10n.grownUpsPrivacyHeader,
                        style: theme.textTheme.bodyLarge,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            _Card(
              title: l10n.playStyleTitle,
              children: [
                // HLP-01: play style sets Helper mode.
                RadioGroup<PlayStyle>(
                  groupValue: settings.playStyle,
                  onChanged: (v) {
                    if (v != null) update((s) => s.copyWith(playStyle: v));
                  },
                  child: Column(
                    children: [
                      RadioListTile<PlayStyle>(
                        value: PlayStyle.little,
                        title: Text(l10n.playStyleLittleFull),
                        subtitle: Text(l10n.playStyleLittleHelp),
                      ),
                      RadioListTile<PlayStyle>(
                        value: PlayStyle.big,
                        title: Text(l10n.playStyleBigFull),
                        subtitle: Text(l10n.playStyleBigHelp),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            _Card(
              title: l10n.soundTitle,
              children: [
                toggle(
                  l10n.settingMusic,
                  value: settings.music,
                  change: ({required on}) => settings.copyWith(music: on),
                ),
                toggle(
                  l10n.settingSfx,
                  value: settings.sfx,
                  change: ({required on}) => settings.copyWith(sfx: on),
                ),
                toggle(
                  l10n.settingVoice,
                  value: settings.voice,
                  change: ({required on}) => settings.copyWith(voice: on),
                ),
                toggle(
                  l10n.settingHaptics,
                  value: settings.haptics,
                  change: ({required on}) => settings.copyWith(haptics: on),
                ),
              ],
            ),
            _Card(
              title: l10n.dailyLimitTitle,
              children: [
                Text(l10n.dailyLimitHelp, style: theme.textTheme.bodyMedium),
                const SizedBox(height: 8),
                SegmentedButton<int>(
                  segments: [
                    for (final m in const [0, 15, 30, 45])
                      ButtonSegment(
                        value: m,
                        label: Text(
                          m == 0 ? l10n.limitOff : l10n.limitMinutes(m),
                        ),
                      ),
                  ],
                  selected: {settings.dailyLimitMinutes},
                  onSelectionChanged: (v) =>
                      update((s) => s.copyWith(dailyLimitMinutes: v.first)),
                ),
              ],
            ),
            _Card(
              title: l10n.progressTitle,
              children: [
                Text(
                  l10n.progressSummary(
                    done,
                    data.courses.length,
                    stars,
                    data.courses.length * 3,
                    profile.stickerIds.length,
                    data.stickers.length,
                  ),
                  style: theme.textTheme.bodyLarge,
                ),
                Text(
                  l10n.playTimeWeek((weekSeconds / 60).round()),
                  style: theme.textTheme.bodyLarge,
                ),
              ],
            ),
            _Card(
              title: l10n.learningTitle,
              children: [
                Text(l10n.learningBody, style: theme.textTheme.bodyMedium),
              ],
            ),
            _Card(
              title: l10n.guidedAccessTitle,
              children: [
                Text(l10n.guidedAccessBody, style: theme.textTheme.bodyMedium),
              ],
            ),
            _Card(
              children: [
                _LinkRow(
                  icon: Icons.policy_outlined,
                  label: l10n.linkPrivacy,
                  onTap: () => unawaited(
                    launchUrl(
                      AppLinks.privacyPolicy,
                      mode: LaunchMode.externalApplication,
                    ),
                  ),
                ),
                _LinkRow(
                  icon: Icons.mail_outline_rounded,
                  label: l10n.linkSupport,
                  onTap: () => unawaited(launchUrl(AppLinks.supportEmail)),
                ),
              ],
            ),
            _Card(
              children: [
                _LinkRow(
                  icon: Icons.restart_alt_rounded,
                  label: l10n.resetTitle,
                  color: AppColors.danger,
                  onTap: _resetProgress,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.children, this.title});

  final String? title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Card(
    color: AppColors.white,
    elevation: 0,
    margin: const EdgeInsets.only(bottom: 12),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null) ...[
            Text(
              title!,
              style: Theme.of(context).textTheme.titleLarge,
              semanticsLabel: title,
            ),
            const SizedBox(height: 8),
          ],
          ...children,
        ],
      ),
    ),
  );
}

/// A full-width link row with a 48 pt hit area (PAR-04, PAR-06).
class _LinkRow extends StatelessWidget {
  const _LinkRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color = AppColors.navy,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    child: InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: AppSizes.grownUpsTarget),
        child: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(color: color),
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: color),
          ],
        ),
      ),
    ),
  );
}
