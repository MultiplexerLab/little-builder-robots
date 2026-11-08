# Little Builder Robots

Flutter kids' game for iOS (ages 3-7). Full spec: docs/SRS.md. Requirement IDs (WRK-03, RUN-11...) are the source of truth. Build order: SRS section 9.1.

## Commands
- flutter pub get
- dart run build_runner build --delete-conflicting-outputs
- flutter analyze (must be clean)
- flutter test (must pass before every commit; includes the course solver test)
- flutter run -d <ios-simulator>

## Rules
- Never add a package that does analytics, ads, crash reporting or tracking (SRS section 6). Ask before adding any new dependency.
- No network calls in v1.0. No google_fonts; Fredoka and Nunito Sans are bundled in assets/fonts. No runtime downloads.
- Game rules and run physics live in lib/domain as pure Dart with unit tests. No Flutter imports there. Flame only renders RunSimulator state.
- Runs must be deterministic: fixed timestep, no randomness.
- Parts, stats, courses, stickers and decals come from assets/data/*.json. Never hard-code tuning values.
- Landscape only. Child touch targets at least 64pt, primary 96pt+; Grown-ups area at least 48pt.
- Colours, type and sizes come only from lib/app/theme.dart (SRS 3.15, DES-01 to DES-12). Where a mockup disagrees with the SRS, the SRS wins (SRS section 11).
- Child screens use taps only (plus hold for Jetpack). No swipes, drags or text input.
- Every child-facing instruction has a voice-over clip. Never require reading.
- All user-facing strings go through l10n (ARB files in lib/core/l10n; generated code in lib/core/l10n/gen is not committed).
- No purchases, prices or buy prompts in v1.0 (World 2 is v1.1).
- Reference requirement IDs in commit messages, e.g. "WRK-03: snap animation on equip".

## Structure
See SRS section 7.2. Features live in lib/features/<name>/.
