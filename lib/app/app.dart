import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:little_builder_robots/app/providers.dart';
import 'package:little_builder_robots/app/router.dart';
import 'package:little_builder_robots/app/services.dart';
import 'package:little_builder_robots/app/theme.dart';
import 'package:little_builder_robots/core/l10n/gen/app_localizations.dart';
import 'package:little_builder_robots/core/utils/play_clock.dart';
import 'package:little_builder_robots/core/utils/touch_guard.dart';

class App extends ConsumerStatefulWidget {
  const App({super.key});

  @override
  ConsumerState<App> createState() => _AppState();
}

class _AppState extends ConsumerState<App> {
  late final AppLifecycleListener _lifecycle;
  late final PlayClock _clock;

  @override
  void initState() {
    super.initState();
    final clock = _clock = ref.read(playClockProvider)..start();
    // Count play time only while the app is in front (PAR-07).
    _lifecycle = AppLifecycleListener(
      onResume: clock.start,
      onPause: clock.pause,
      onHide: clock.pause,
    );
    ref.read(audioProvider).apply(ref.read(settingsProvider));
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _clock.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // AUD-03: each audio channel follows its Grown-ups switch.
    ref.listen(settingsProvider, (_, s) => ref.read(audioProvider).apply(s));
    return MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.child(),
      routerConfig: ref.watch(routerProvider),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) =>
          TouchGuardScope(child: child ?? const SizedBox()),
    );
  }
}
