# Little Builder Robots: app summary

*Status as of 8 November 2026. The detailed spec is [SRS.md](SRS.md); requirement IDs below (WRK-03, RUN-11…) refer to it.*

## At a glance

| | |
|---|---|
| What it is | An offline robot-building game for children aged 3 to 7 |
| Platform | iOS, landscape (Flutter and Flame). Android also builds |
| State | Feature-complete for v1.0 (build steps 1 to 16). Not yet run on an iPhone or the iOS simulator; that needs a Mac |
| Quality | `flutter analyze`: no issues. `flutter test`: 401 tests pass. A scripted play-through clears all 15 courses through the real screens, and the real app runs in Chrome with no errors. A debug Android build compiles |
| Size of the code | 68 Dart files (about 10,000 lines) in `lib`, 25 test files (about 3,600 lines) |
| Content | 15 courses, 17 parts, 6 paints, 8 decals, 24 stickers, 9 Test Track sections, 186 text strings, 93 audio clips |
| Privacy | No accounts, ads, analytics, tracking or network requests. Everything stays on the device |

## How the game plays

1. **Build.** In the Workshop the child picks parts for 4 slots: Head, Body, Arms and Moves. Each part changes 5 stats (Speed, Climb, Jump, Weight, Fuel) or adds an ability (Jetpack, Grab bars, Blow leaves, Mudproof).
2. **Test.** The robot runs a course by itself. Each obstacle shows the stat it needs as an icon with pips. For example, steps show the Climb icon with 2 pips.
3. **Learn from failing.** There are no lives and no losing. A failed obstacle sends the robot back to the last checkpoint, and repeated failures climb a hint ladder:
   - first, the robot shrugs;
   - next, a voiced hint names what's needed;
   - then a wrench bubble suggests a part that would work.
4. **Swap mid-run.** Pit stops let the child change parts during a course.
5. **Earn.** Stars, bolts (the in-game currency), new parts and stickers.

There are two play styles, chosen by a grown-up on first launch:

- **Little Builder (ages 3 to 4):** Helper mode. The robot jumps and flies by itself and the run plays at 80% speed. Part choice still matters.
- **Big Builder (ages 5 to 7):** the child taps to jump and holds to fly.

## Screens and features

| Screen | What it does | Requirements |
|---|---|---|
| Splash | Under 2 s, no buttons. Goes to first-run setup, Home, or rest time | HOM-01 |
| First-run setup | "Who is playing?" card with two picture buttons. Stores only the play style | ONB-01 |
| Home | Robot (reacts to taps), Play, Courses, Test Track (padlocked until course 3), Sticker book, and a 48 pt Grown-ups gear | HOM-02 to HOM-05, TRK-01 |
| Workshop | Slot tabs plus Paint and Decal tabs, 96 pt part tiles, "Good at" stat pips with a voiced hint, unlock confirm showing gains and losses, a bolt counter that shakes when bolts are short, and a hand tutorial on the first visit | WRK-01 to WRK-13, ONB-02 |
| Course map | 15 nodes on one winding path that fits the screen. Each node shows done (with stars), next (robot marker) or locked. Tapping a node shows a voiced hint bubble, and Go opens the Workshop. Star counter out of 45 | MAP-01 to MAP-08 |
| Run | Flame game with a progress bar showing checkpoints and pit stops, a bolt count, Pause, a jump zone on the right 40% of the screen, need icons on obstacles, a camera preview on the first play, the hint ladder, pit stops and a Jetpack fuel gauge | RUN-01 to RUN-15, HLP-01 to HLP-05 |
| Pause | Resume, Restart and Workshop as large buttons. Map, Home and Sound as 64 pt buttons. Bolts shown as icons. Leaving early keeps collected bolts | RUN-08, RES-03 |
| Result | Stars with rule icons, +N bolts, part and sticker reveals, then Next, Rebuild and Play again. Course 15 adds a celebration | RES-01 to RES-06 |
| Test Track | Endless loop of every obstacle type met so far, each followed by a pit stop. No stars or bolts | TRK-01 to TRK-04 |
| Sticker book | 24 stickers earned for discoveries, never for skill or time. Silhouettes play a voiced clue when tapped | STK-01 to STK-04 |
| Parent gate | Multiplication question written in words, with a number pad. Guards Grown-ups and every link | PAR-01 to PAR-03 |
| Grown-ups | Play style, music, sound effects, voice and vibration switches, a daily time limit, a progress summary, the "what your child is learning" and Guided Access cards, privacy and support links, and reset with two confirms | PAR-04 to PAR-12 |
| Rest time | When today's limit is reached (after the current run finishes), the robot falls asleep. A grown-up can add 10 more minutes or turn the limit off | PAR-07, PAR-11 |

## Courses (World 1, Gear Garden)

| # | Teaches | Intended build | Pit stops | Reward |
|---|---|---|---|---|
| 1 | Rolling and collecting bolts | Any | – | 5 bolts |
| 2 | Steps | Legs | – | 5 bolts |
| 3 | Small gaps (tap to jump) | Any | – | Spring feet |
| 4 | Steps, then timed gates | Legs, then Wheels | 1 | 8 bolts |
| 5 | Bigger gaps | Spring feet | – | 8 bolts |
| 6 | Ramp jumps | Wheels | – | Jetpack |
| 7 | Wide gaps, low ceilings | Jetpack | – | 10 bolts |
| 8 | Steps and gaps | Legs, or Legs then Spring feet | 1 | 10 bolts |
| 9 | Mud | Light frame | – | Heavy frame |
| 10 | Heavy switches | Heavy frame | – | 12 bolts |
| 11 | Switch, then mud | Heavy frame, then Light frame | 1 | Grabber arms |
| 12 | Bar swings | Grabber arms | – | 12 bolts |
| 13 | Leaf piles | Jetpack (or Fan arms) | – | 15 bolts |
| 14 | Mixed | Legs, then Spring feet, then Heavy frame | 2 | 15 bolts |
| 15 | Finale: every obstacle type | Four stages | 3 | Gold head and celebration |

Every course is checked automatically by the solver test. It can be finished with parts the child already owns when it unlocks, without buying anything. Each intended build earns 3 stars in 20 to 40 seconds. Little Builder mode never changes which builds can finish.

## How it is built

| Layer | Folder | Contents |
|---|---|---|
| Rules and physics | `lib/domain` | Pure Dart with no Flutter: data models, stat, star, unlock and sticker rules, obstacle needs and part suggestions, the Test Track builder, and the run simulator. The simulator is deterministic: fixed 1/120 s steps and no randomness |
| Data and saving | `lib/data`, `assets/data` | JSON game data (parts, physics, courses, decals, stickers, Test Track). Saves go to Hive with a schema version, a backup copy and step-by-step migrations. A broken save falls back to the backup, then to a fresh start |
| App state | `lib/app` | Riverpod providers that save after every change, plus the router with the Parent gate guard and the daily-limit redirect |
| Screens | `lib/features/<name>` | Flutter screens. The run is a Flame game that only draws the simulator's state |
| Shared | `lib/core` | Theme tokens, one robot renderer used everywhere, audio, vibration, toddler touch guard, play clock, translations |

**Design rules kept throughout:**
- All tuning values live in JSON, not code.
- Colours, type and sizes come only from `lib/app/theme.dart`.
- All text lives in translation files, and every child-facing line has a voice clip.
- Child touch targets are 64 pt or larger (96 pt for the main action on each screen).
- Child screens use taps only: no scrolling or dragging.
- Touches with 3 or more fingers are ignored (palm guard), and navigation buttons ignore repeat taps within 400 ms.
- Reduce Motion is respected.

**Packages:** flutter_riverpod, go_router, flame, hive_ce and hive_ce_flutter, audioplayers, url_launcher, freezed and json_serializable, and intl. None of them do analytics, ads or tracking. `audioplayers` includes the `http` package for streaming, but the app only plays bundled files.

## Tests (401, all passing)

| Area | What is covered |
|---|---|
| Rules | Stats for every common build, stars, unlocks and buying, run payouts, stickers, Test Track, obstacle needs, part suggestions |
| Simulator | Speed, jump height, steps, gaps, gates, Jetpack and fuel, ceilings, bars, switches, mud, leaves, ramps, pit stops, tutorial wait, determinism, terrain geometry |
| Courses | Course data matches the SRS tables and the solver passes all 15 courses in both play styles |
| Saving | Corrupt saves, backups, migrations, a newer-version save, real Hive surviving a restart, parts removed in an update |
| App state | Every progress action saves; settings; which course is next |
| Screens | Every route builds without layout errors; Home, Workshop, Parent gate, Pause, jump zone, Result; key buttons sit fully on screen with no scrolling; one full course played end to end through Flame |
| Other | Audio files exist for every clip the code plays, every text key exists, the robot renderer handles every part, haptics follow the switch, play time and the daily limit |

## Checks beyond the unit tests

| Check | What it does | Result |
|---|---|---|
| Play-through (`tool/soak/play_session_test.dart`) | Plays all 15 courses through the real screens with the intended parts, including 7 pit-stop swaps, then Test Track laps, every sticker, the Parent gate and every Grown-ups setting | 3 stars on every course; no errors |
| Live app in Chrome (`tool/web_check/drive.mjs`) | Builds the real app for the web and drives it in headless Chrome: first run, Workshop, a full course, Pause, Result, map, stickers, Parent gate | No console errors or exceptions |
| Screenshots (`tool/screenshots/screenshots_test.dart`) | Renders every screen with the real fonts for comparison with the mockups | Copies in [screenshots/](screenshots/) |

These checks found and fixed four real problems: Workshop part tiles drew the whole robot over the tabs, and the Result buttons, the map's Go button and the third row of stickers fell off a landscape iPhone screen. The `web/` folder exists only for the Chrome check; the product is iOS.

## Audio and art

- **Music (4 loops) and sound effects (18):** original sounds, generated by code in `tool/audio/synth.py`. Free to ship.
- **Voice-over (71 lines):** placeholder text-to-speech in a US English voice (Microsoft Zira). Replace it with a recorded British English voice before release; the file names are listed in [AUDIO_CLIPS.md](AUDIO_CLIPS.md). Rebuild all audio with `python tool/audio/build_audio.py`.
- **Art:** the robot, obstacles, map and stickers are drawn in code with the design-system colours. The app icon is rendered from the robot art with `python tool/app_icon/write_icons.py`.

## What is left before release

| Item | Who or what it needs |
|---|---|
| First iOS build and device testing. The edge-swipe and home-indicator code in `ios/Runner/SceneDelegate.swift` (NFR-20) has not been compiled | A Mac with Xcode |
| Performance checks: 60 fps in runs, start-up under 3 s, memory, install size (NFR-01 to NFR-04, RUN-10) | iPhone 11 and iPad 9th gen |
| VoiceOver check of every button (NFR-10). Labels are in place but untested with VoiceOver | A device |
| Recorded en_GB voice-over | A voice artist or licensed voice |
| Illustrated art, if wanted | An illustrator |
| Real bundle ID (currently `com.example.little_builder_robots`), privacy policy URL and support email (`lib/app/links.dart`) | You |
| Privacy policy page online; App Privacy label "Data Not Collected"; age band (PRV-06, PRV-07) | You, in App Store Connect |
| Playtests with children (SRS 8.1) and TestFlight crash-free rate (NFR-12) | Families and testers |
| Dependency audit before each release (PRV-10) | Before each release |

## Commands

```sh
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter analyze
flutter test
flutter run -d <ios-simulator>        # on a Mac
python tool/audio/build_audio.py      # rebuild audio (needs ffmpeg)
python tool/app_icon/write_icons.py   # rebuild app icons
flutter test tool/soak/play_session_test.dart        # full play-through
flutter test tool/screenshots/screenshots_test.dart  # screenshots
```
