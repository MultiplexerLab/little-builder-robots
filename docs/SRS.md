# Little Builder Robots: Software Requirements Specification

Revision 3 (final for v1.0) · Oct 31, 2026 · Author: Sarwar Miral

Revision 3 merges the review of the 15 UI mockups into the requirements. It adds a design system (section 3.15) that replaces the touch-target rules on the mockup style guide, tightens the screen requirements the mockups got wrong, and lists every mockup change still needed (section 11). Revision 2 widened the age range to 3 to 7, fixed rule conflicts, moved World 2 and its purchase to v1.1, and added features that make the game easier to learn. Section 0 lists every change.

---

## 0. Changes

### 0.1 Revision 4 (gameplay review)

| Area | Change |
|---|---|
| Hints | RUN-13: the simulator checks whether the robot's parts can pass the obstacle. If not, the robot shrugs once and then offers new parts (Little Builder gets the wrench at once). If they can, the child gets a timing tip instead, never a push for new parts |
| Puzzle | MAP-04 and RUN-13: Big Builder hears hints that describe the problem ("Those steps are too tall for this robot!"); Little Builder keeps hints that name the answer |
| Courses | Section 4.5: every course is rebuilt as teach, twist, payoff, and takes 15 to 25 s with the intended build (was 20 to 40). Bolt counts and rewards are unchanged |
| Replay | New RUN-16: one golden gear per course, often out of reach of the intended build, so children come back with new parts. Gears do not change stars. STK-01 gains a 25th sticker for the first gear |
| Personality | The robot shows off each part in the Workshop, shouts short voiced exclamations in runs, and does tricks on Home (FEEL) |

### 0.2 Revision 3 (mockup review)

| Area | Change |
|---|---|
| Design system | New section 3.15 (DES-01 to DES-12): colour, type and component tokens taken from the mockup style guide. Its touch-target rule ("48pt minimum; main action 64 to 92pt") and the 72 pt part tile are **replaced** by NFR-05 and WRK-02 |
| Home and shell | HOM-01: the splash has no buttons. HOM-02: layout of the four child buttons. HOM-06: the run screen's Pause button takes the Home position |
| Workshop | WRK-01 slot icons; WRK-04 stat pips instead of a sentence; WRK-05 the unlock confirm shows the change against the equipped part, gains and losses with arrows; new WRK-13 (robot drawn from RobotConfig everywhere) |
| Map | MAP-07 names the "World 2" chip as forbidden; new MAP-08 (path direction) |
| Run | RUN-07, RUN-08 and RUN-13 made precise (checkpoint dots, Workshop button on Pause, a small hint bubble that never blocks play, no lives indicator) |
| Result | RES-01 rule icons, not words; RES-05 Play again is required |
| Feel | FEEL-01: no X eyes or other hurt faces |
| Grown-ups | PAR-01 gate copy for v1.0; PAR-04 lists every control and the layout; new PAR-12: no purchase UI in v1.0 |
| Text on child screens | New DES-09: words on child screens are always paired with an icon and, if they say something, a voice clip |
| Fonts | Nunito Sans is bundled for the Grown-ups area, next to Fredoka |
| Mockups | Section 11 lists the changes each mockup needs |
| Rewards (build step 3) | RES-03: a run left before the flag keeps its collected bolts, but no stars or rewards |
| Tech (build step 3) | Courses are hand-written JSON, not Tiled (7.1); run physics tuning lives in physics.json (7.3) |
| Map (build step 7) | MAP-04 and MAP-08 together: tapping a playable node plays its voiced hint in a bubble with the need icon, a 64 pt replay button and a 96 pt Go button; Go opens the Workshop |
| Helper mode (build step 9) | HLP-04 is met by slowing the whole run to 80% game time, so every jump keeps its shape and timed gates give the same result. HLP-05: a tap in Helper mode is a cosmetic hop that never changes the run |
| Hints (build step 9) | RUN-13 step 3 suggests the first single part swap that the headless simulator shows would pass the obstacle, preferring owned parts; with no pit stop behind the robot, the wrench opens the Workshop and banks the bolts (RES-03) |
| Workshop (build step 6) | Paint (WRK-06) and decals (WRK-10) are two extra tabs after the four slot tabs. Tabs sit in the top bar so two rows of 96 pt tiles fit a landscape iPhone without scrolling |
| Content (build step 12) | Obstacles added to the model: barGap, heavySwitch, mud, leafPile, lowCeiling and ramp; Jetpack thrust and the autopilot used by Helper mode and the solver test. Test Track sections live in test_track.json; the 24 stickers in stickers.json |

### 0.3 Revision 2 (changes from revision 1)

| Area | Change |
|---|---|
| Age range | 4 to 7 becomes **3 to 7**. Two play styles: Little Builder (3 to 4) and Big Builder (5 to 7) |
| Scope | World 2 (Frosty Factory) and the World 2 purchase move to **v1.1**. v1.0 has no purchases and no network use |
| Rules | One weight threshold for switches and mud; steps can only be climbed; timed gates now matter; base stats defined; body stats written as modifiers |
| Content | Course 4 and 11 made solvable through pit stops; course 8 intended build fixed; Gold head counted in the 6 heads; World 2 teaser removed |
| New: play | Pit stops (RUN-11), stat icons on obstacles (RUN-12), hint ladder (RUN-13), course preview (RUN-14), jump zone (RUN-15), robot personality and haptics (FEEL) |
| New: modes | First-run setup and tutorial (ONB), Helper mode (HLP), Test Track sandbox (TRK) |
| New: rewards | Sticker book (STK), decals as a bolt sink (WRK-10) |
| New: parents | "What your child is learning" card, wind-down before the time limit, Guided Access tip |
| Removed from v1.0 | Robot naming (WRK-08) moves to v1.1; MAP-06 and IAP-01 to IAP-05 move to v1.1 |
| Tech | Run physics in a pure Dart simulator so a solver test can prove every course is beatable; bundled font instead of google_fonts; save schema ready for profiles |

---

## 1. Introduction

Little Builder Robots is an offline iOS game for children aged 3 to 7, built in Flutter. Children build a robot from parts and test it on short obstacle courses. The parts they pick decide what happens, so the game teaches cause and effect without reading and without losing.

### 1.1 Purpose

This SRS defines what v1.0 must do so it can be built in VS Code with Claude Code, tested against clear criteria, and submitted to the Apple App Store Kids Category.

### 1.2 Scope

In scope for v1.0:

- One world (Gear Garden) with 15 courses
- Robot Workshop with 4 part slots (Head, Body, Arms, Moves), paint and decals
- Obstacle runs driven by part stats, with one Jump action and pit stops to swap parts mid-course
- Two play styles: Little Builder (ages 3 to 4, with Helper mode) and Big Builder (ages 5 to 7)
- Test Track sandbox, sticker book, stars, bolts (soft currency) and unlockable parts
- Parent gate and Grown-ups area
- English (UK) voice-over and text; structure ready for more languages

Out of scope for v1.0: any purchase, World 2, accounts, cloud sync, multiplayer, chat, ads, analytics SDKs, robot naming, multiple profiles, Android release (the Flutter codebase keeps Android possible later).

Planned for v1.1: World 2 (Frosty Factory, 15 courses) with one non-consumable purchase (section 3.13), up to 3 local profiles, robot naming from preset names.

### 1.3 Definitions

| Term | Meaning |
|---|---|
| Part | A swappable robot piece in one slot (Head, Body, Arms, Moves) |
| RobotConfig | The four equipped parts, plus paint colour and decal |
| Stats | Speed, Climb, Jump, Weight, Fuel, derived from the RobotConfig |
| Ability | A special power a part has besides stats (grab bars, blow leaves, mudproof) |
| Course | One short obstacle level, 20 to 40 seconds to finish |
| Checkpoint | A flag on the course where the robot restarts after a failure |
| Pit stop | A checkpoint with a garage pad where the child can swap parts mid-run |
| Failure | A fall into a gap or water, or a bump that stops the robot (section 4.4) |
| Bolt | Soft currency collected in runs and spent on parts, heads and decals |
| Star | 0 to 3 per course, for finishing, collecting all bolts and not falling |
| Sticker | A collectable reward for a discovery, kept in the sticker book |
| Play style | Little Builder or Big Builder; set by a grown-up; controls Helper mode |
| Parent gate | An adult-only challenge in front of settings and external links |

### 1.4 References

- UI prototype: the Little Builder Robots design canvas; each screen's title lists the requirement IDs it covers (section 3.0). Where a mockup and this document disagree, this document wins; section 11 lists the known differences
- Design system: section 3.15 of this document (it supersedes the style guide board in the canvas)
- Apple App Store Review Guidelines, section 1.3 Kids Category and 5.1.4 Kids
- US COPPA rule and the UK ICO Age Appropriate Design Code (Children's Code)
- Flutter and Flame engine documentation

---

## 2. Overall description

The app is a self-contained, offline game: all content ships in the bundle, progress is stored on the device, and nothing about the child leaves the phone. v1.0 makes no network requests at all.

### 2.1 Users

| User | Age | Goals | Design implication |
|---|---|---|---|
| Little Builder | 3 to 4 | Tap, watch, build, see the robot do funny things | Taps only, very large targets, Helper mode on, voice for everything, failure is always funny |
| Big Builder | 5 to 7 | Plan a build, beat obstacles, collect everything | Full jump control, stars and stickers to chase, Test Track to experiment |
| Parent or carer | Adult | Safe content, control over sound and time, see progress | Parent gate, short settings screen, clear privacy statement, learning summary |

### 2.2 Operating environment

- iPhone and iPad, iOS 15 or later, landscape only
- Flutter stable channel (3.x), Dart 3, Flame engine for the run screen
- Works fully offline; no network calls anywhere in v1.0
- Built and signed through Xcode on macOS; development in VS Code with Claude Code

### 2.3 Constraints

- Must meet Apple Kids Category rules: no third-party advertising or analytics; parental gate before external links and settings
- App binary under 150 MB so it downloads over mobile data
- Child-facing UI must work without reading; every instruction is voiced or shown by animation
- One developer, part-time: v1.0 is planned for about 13 weeks (section 8). Should items can slip to v1.1 to hold the date

### 2.4 Assumptions and dependencies

- Art is 2D vector or PNG/WebP sprites (in-house, commissioned or licensed with commercial rights)
- Voice-over is recorded or produced with a licensed TTS voice and shipped as audio files
- Apple Developer Program membership is active (confirmed)
- App Store price for v1.0 (paid upfront or free) is decided at submission; it does not change any requirement here

---

## 3. Functional requirements

Each requirement has an ID for tickets, commits and tests. **Must** = required for v1.0 release; **Should** = planned for v1.0 but can slip to v1.1.

"Child-facing screen" means every screen except the Parent gate and the Grown-ups area.

### 3.0 Screen map

Every screen traces back to requirements. Requirements with no screen (SAV, AUD, most NFR) are system behaviour.

| # | Screen | Requirements |
|---|---|---|
| 1 | Splash | HOM-01 |
| 2 | First-run setup | ONB-01, ONB-02 |
| 3 | Home | HOM-02 to HOM-06 |
| 4 | Workshop | WRK-01 to WRK-07, WRK-09, WRK-10 |
| 5 | Unlock a part | WRK-02, WRK-05, WRK-11 |
| 6 | Course map | MAP-01 to MAP-05, MAP-07 |
| 7 | Course preview | RUN-14 |
| 8 | Obstacle run | RUN-01 to RUN-07, RUN-09, RUN-12, RUN-15, FEEL-01 to FEEL-03 |
| 9 | Pit stop | RUN-11 |
| 10 | Run paused | RUN-08 |
| 11 | Hint bubble | RUN-13 |
| 12 | Result | RES-01 to RES-03, RES-05, RES-06 |
| 13 | New part / sticker reveal | RES-04, STK-02 |
| 14 | Test Track | TRK-01 to TRK-04 |
| 15 | Sticker book | STK-01 to STK-04 |
| 16 | Parent gate | PAR-01 to PAR-03 |
| 17 | Grown-ups settings | PAR-04 to PAR-06, PAR-08 to PAR-10, HLP-01 |
| 18 | Rest time | PAR-07, PAR-11 |
| 19 | Style guide | DES-01 to DES-12, NFR-05, NFR-09, NFR-11 |
| 20 | World 2 purchase (v1.1 only) | IAP-01 to IAP-05 |

### 3.1 First run (ONB)

| ID | Requirement | Priority |
|---|---|---|
| ONB-01 | On first launch only, a "For grown-ups" card asks who is playing, with two large picture buttons: Little Builder (ages 3 to 4) and Big Builder (ages 5 to 7). The choice sets the play style and can be changed later in Grown-ups settings. The card is voiced. No age, name or birthday is stored, only the play style | Must |
| ONB-02 | The first Workshop visit and course 1 act as the tutorial: an animated hand shows tapping a part, tapping "Test it!", and (Big Builder) tapping the jump zone. In Big Builder the robot waits before the first gap until the child taps. The tutorial needs no reading and can't be failed | Must |

### 3.2 App shell and Home (HOM)

| ID | Requirement | Priority |
|---|---|---|
| HOM-01 | The app launches in landscape to a splash (max 2 s), then the First-run setup (first launch) or Home. The splash has no buttons and no text the child needs; a tap anywhere does nothing | Must |
| HOM-02 | Home shows the title, the player's current robot, a large Play button (primary, 96 pt+), and three 64 pt+ icon buttons: Courses (map icon, opens the Course map), Test Track (track icon) and Sticker book (book icon). Each button plays its voiced name when the robot is idle and the child hesitates for 5 s | Must |
| HOM-03 | Play opens the Workshop with the last saved RobotConfig and the next unplayed course selected; after all 15 courses are done, it selects course 15 | Must |
| HOM-04 | A Grown-ups button (gear icon, top right, 48 pt, placed away from child buttons) opens the Parent gate | Must |
| HOM-05 | The robot on Home plays an idle animation and reacts to a tap with a sound and a funny move | Should |
| HOM-06 | Every child-facing screen other than Home and the Rest screen has a Home button (house icon, 64 pt) in the same top-left position. On the run and Test Track screens the Pause button takes that position and Home is in the Pause menu (NFR-07 still holds). There is no separate back arrow on child screens | Must |

### 3.3 Workshop (WRK)

| ID | Requirement | Priority |
|---|---|---|
| WRK-01 | The Workshop shows four slot tabs, each with a drawn slot icon (head, body, arms, moves silhouettes) and its name. The selected tab uses the selected-tile style (DES-06); colour is never the only sign of a slot | Must |
| WRK-02 | Selecting a slot shows its parts as large tiles (min 96 x 96 pt). Locked parts show a dashed border, a lock, and either their bolt cost (bolt icon plus number) or the course node that awards them (small map pin with the course number), never words such as "Course 6" | Must |
| WRK-03 | Tapping an unlocked part equips it instantly; the robot preview updates with a snap animation, sound and light haptic | Must |
| WRK-04 | A "Good at" panel shows the robot's stats as icons with 0 to 5 pips, and a voiced one-line hint with a replay button. The stat icons match the obstacle icons in the run (RUN-12). The panel does not replace the pips with a sentence | Must |
| WRK-05 | Tapping a locked part with enough bolts asks for a kid-level confirm (big cross, big tick as the primary button) and unlocks it with a reveal. The confirm shows the part, its cost as bolt icon plus number, its ability icon if any, and each stat that changes against the part currently in that slot: current pips filled, gained pips with an up arrow, lost pips crossed out with a down arrow. The stat change comes from stat_calculator, never from the screen | Must |
| WRK-06 | A paint picker offers 6 body colours, each with a pattern swatch so colour is not the only signal | Should |
| WRK-07 | "Test it!" saves the RobotConfig and opens the Course preview for the selected course | Must |
| WRK-09 | The Workshop shows the bolt total at all times (read-only) | Must |
| WRK-10 | A decal picker offers 8 decals (stars, stripes, lightning, flowers, eyes, hearts, dots, gears); 2 free, 6 bought with bolts (section 4.6) | Should |
| WRK-11 | Tapping a locked part without enough bolts shakes the bolt counter gently and plays a voiced line ("Collect more bolts on the courses!"); nothing is lost | Must |
| WRK-12 | When the child arrives from a hint (RUN-13 step 3), the slot tab with the suggested part pulses and the part tile glows until it is tapped or the child leaves | Must |
| WRK-13 | The robot is drawn by one shared renderer (used by both the Flutter robot widget and the Flame robot component) from the RobotConfig on every screen (Home, Workshop, run, hint, result, rest), so its head, body, arms, moves, paint and decal always match what the child built | Must |

### 3.4 Course map (MAP)

| ID | Requirement | Priority |
|---|---|---|
| MAP-01 | The map shows World 1 (Gear Garden) as a path of 15 course nodes | Must |
| MAP-02 | Each node (min 64 pt; the next node 96 pt) shows its state with shape as well as colour: done (with 1 to 3 stars, filled or outlined), next (highlighted, bouncing robot marker), or locked (dashed border and padlock) | Must |
| MAP-03 | A course unlocks when the one before it is finished with at least 1 star | Must |
| MAP-04 | Tapping a playable node plays a voiced hint about its main obstacle, with its stat icon, in a bubble with a Go button that opens the Workshop with that course selected. For Big Builder the hint describes the problem ("Steps ahead, and they get taller!"); for Little Builder it names the answer ("Steps ahead! Legs are good at climbing.") | Must |
| MAP-05 | A star counter shows stars earned out of the world total (45) | Must |
| MAP-07 | Nothing on the map refers to purchases or unavailable content in v1.0: no World 2 chip, locked world button, teaser or price | Must |
| MAP-08 | The path reads as one line from course 1 to course 15 with no arrows that point against the direction of travel; the voiced hint bubble for a node has a 64 pt replay button | Must |

### 3.5 Obstacle run (RUN)

| ID | Requirement | Priority |
|---|---|---|
| RUN-01 | The robot moves right automatically at a speed set by its stats (section 4.1) | Must |
| RUN-02 | Jump is triggered by tapping the jump zone (RUN-15). With a Jetpack equipped, holding gives thrust until fuel runs out; fuel refills on landing | Must |
| RUN-03 | Steps can only be climbed if Climb is high enough; otherwise the robot bumps and stops, which counts as a failure (section 4.4) | Must |
| RUN-04 | Falling into a gap or water returns the robot to the last checkpoint after 1 s, with a funny splash or boing. No lives are lost | Must |
| RUN-05 | After a bump failure the robot wobbles, then rolls back to the last checkpoint after 1.5 s and tries again with the same build | Must |
| RUN-06 | Bolts on the course are collected on contact with a sound, a sparkle and a counter update | Must |
| RUN-07 | The HUD shows Pause (top left, 64 pt), a progress bar with a dot for each checkpoint (pit stops drawn as a wrench dot) and a finish flag, and the bolt count | Must |
| RUN-08 | Pause offers Resume (primary, 96 pt+), Restart and Workshop (wrench icon) as large icon buttons, plus smaller 64 pt Map, Home and sound buttons. It shows the course's bolts as bolt icons (collected filled, missing outlined), not as a sentence | Must |
| RUN-09 | Reaching the flag ends the run and opens Result | Must |
| RUN-10 | Runs keep 60 fps on iPhone 11 and newer and iPad 9th gen and newer | Must |
| RUN-11 | Pit stops: checkpoints marked as pit stops in course data have a garage pad. The robot parks on it and a panel opens showing the robot, the stat icon of the next obstacle, and the four slots with owned parts only. Tapping a part equips it; a large Go button continues the run. Parts swapped at a pit stop do not change the saved RobotConfig | Must |
| RUN-12 | Every obstacle shows the icon of the stat or ability it needs, with the required pips (for example, steps show the Climb icon with 2 pips). The icon pulses when the robot approaches | Must |
| RUN-13 | Hint ladder, counted per obstacle per run: the headless simulator first checks whether the robot's current parts can pass the obstacle. If they cannot: failure 1, the robot shrugs and looks at the obstacle; failure 2, a "Try new parts?" bubble with a wrench button that opens the nearest pit stop if one is behind the robot, otherwise the Workshop (WRK-12), with a voiced hint (Big Builder: the problem, "Those steps are too tall for this robot!"; Little Builder: the answer, "These steps are tall! Try legs that climb."). Little Builder gets the bubble at failure 1. If the parts can pass (a mistimed jump or flight): failure 1, the shrug; from failure 2, a voiced timing tip ("Tap jump right at the edge!"), and never the new-parts bubble. The bubble never blocks play: it is anchored next to the robot, covers no more than a third of the screen, does not dim the course, and tapping elsewhere dismisses it. Its only button is the wrench (primary, 96 pt); it shows the current part and the suggested part as pictures with an arrow between them. No lives, tries or failure counters are shown anywhere | Must |
| RUN-14 | Before each run the camera pans slowly across the course (max 4 s) and the robot points at the main obstacle while its hint plays. Tapping skips it. Replays of a finished course skip it automatically | Should |
| RUN-15 | The jump zone is the whole right 40% of the screen below the HUD, with a large jump icon (min 120 pt) as a visual cue. Taps anywhere in the zone count | Must |
| RUN-16 | Each course hides one golden gear, picked up on contact like a bolt. Many are out of reach of the intended build (high up for Spring feet or the Jetpack, or needing two parts together), so finishing with new parts later is rewarded. A found gear is kept once the course is finished, shown on its map node (an outline until found, a gold gear after) and on Result, and never changes stars. Helper mode's autopilot reaches for a gear only when the jump lands on clear, flat ground, so it can never cause a failure. The solver test checks every gear can be reached by some build | Should |

### 3.6 Helper mode (HLP)

Helper mode is on for Little Builder and off for Big Builder.

| ID | Requirement | Priority |
|---|---|---|
| HLP-01 | Grown-ups settings can switch play style; Helper mode follows it | Must |
| HLP-02 | Helper mode jumps automatically at the right moment before gaps the robot's stats can clear. If the stats can't clear the gap, the robot still jumps and falls, so part choice still matters | Must |
| HLP-03 | Helper mode makes the Jetpack hover automatically across gaps and ceilings while fuel lasts; no holding is needed | Must |
| HLP-04 | Helper mode runs at 80% speed and scales timed-gate open time to match, so gate results are the same as in Big Builder | Must |
| HLP-05 | Helper mode hides the jump zone; the robot still reacts with a happy jump if the child taps the screen | Should |

### 3.7 Result and rewards (RES)

| ID | Requirement | Priority |
|---|---|---|
| RES-01 | Result shows earned stars with animation and a cheer, and each unearned star as an outline. Under each star is an icon naming its rule (flag, bolt, no-splash), not a word | Must |
| RES-02 | Stars: 1 for finishing, +1 for collecting all bolts, +1 for no falls (bumps do not count as falls) | Must |
| RES-03 | Bolts collected in the run, plus the course reward bolts on the first finish only, are added to the wallet and shown as "+N" with bolt icons flying into the counter. A run left before the flag (Pause to Restart, Workshop, Map or Home, or the hint wrench) still keeps the bolts collected so far; it earns no stars, no reward bolts and no reward part | Must |
| RES-04 | If the course awards a part or a sticker is earned, a reveal shows it before the buttons appear; the part is added to the Workshop | Must |
| RES-05 | Buttons: Next (primary, 96 pt+, to Map with the next node highlighted), Rebuild (wrench icon, to Workshop, same course) and Play again (replay icon), each 64 pt+. Home is reachable via HOM-06 | Must |
| RES-06 | A best result per course is stored; a worse replay never lowers stars | Must |

### 3.8 Test Track (TRK)

| ID | Requirement | Priority |
|---|---|---|
| TRK-01 | Test Track unlocks after course 3 and is opened from Home. Before that, its Home button shows a padlock and a voiced line says when it opens | Must |
| TRK-02 | Test Track is an endless loop of short sections, one per obstacle type the child has already met in World 1, each followed by a pit stop | Must |
| TRK-03 | There are no stars, bolts, timers or finish in Test Track; failures follow the normal checkpoint rules and the hint ladder | Must |
| TRK-04 | Test Track uses the same simulator and obstacles as courses; it has no content of its own besides the section order | Must |

### 3.9 Sticker book (STK)

| ID | Requirement | Priority |
|---|---|---|
| STK-01 | A sticker book holds 25 stickers for discoveries, not skill (for example: first jump, first splash, sank in mud, first Jetpack flight, pressed a heavy switch, tried every Moves part, painted the robot, finished Test Track lap, 3 stars on any course, found a golden gear, finished World 1). The full list lives in `stickers.json` | Should |
| STK-02 | Earning a sticker shows a short reveal at the next Result screen or Workshop visit, never mid-run | Should |
| STK-03 | Unearned stickers show as silhouettes; tapping one plays a voiced clue about how to get it | Should |
| STK-04 | Stickers are never awarded for time spent or days played (no streaks) | Must |

### 3.10 Feel and personality (FEEL)

| ID | Requirement | Priority |
|---|---|---|
| FEEL-01 | The robot has reactions and never looks sad or hurt: cheer on a good landing, comic wobble on a bump (spiral eyes, never X eyes), shake-off after a splash, happy spin at the flag | Must |
| FEEL-02 | Light haptics on equip, jump, landing and bolt pickup; a haptics toggle in Grown-ups settings | Should |
| FEEL-03 | Failure sounds are funny (boing, splash, honk), never buzzers or "wrong" tones | Must |

### 3.11 Parent gate and Grown-ups area (PAR)

| ID | Requirement | Priority |
|---|---|---|
| PAR-01 | The Parent gate shows a multiplication question written in words (for example, "seven multiplied by six") with a number pad (keys 48 pt+) and a close button placed clear of the pad. In v1.0 the explanation reads "This keeps settings and links away from little fingers" and never mentions purchases | Must |
| PAR-02 | Both factors are from 3 to 9 and the answer is 20 to 81; a wrong answer shows a new question | Must |
| PAR-03 | The gate sits in front of Grown-ups settings and every external link; after a correct answer it continues to the requested screen. Closing it returns to the previous screen | Must |
| PAR-04 | Grown-ups settings: play style (Little Builder / Big Builder), music, sound effects, voice-over and haptics on/off, daily play time (PAR-07), reset progress (with a second confirm). Each toggle row is tappable across its full width (48 pt+ tall); links have 48 pt hit areas. The header says "No data leaves this device" | Must |
| PAR-05 | A progress summary: courses done, stars, stickers, play time this week (on device only) | Should |
| PAR-06 | Links to the privacy policy (opens Safari) and support email (opens Mail with a `mailto:` link), both behind the gate | Must |
| PAR-07 | An optional daily play-time limit (off, 15, 30, 45 min) shows a gentle rest screen when reached; play is locked until the next calendar day or until a grown-up passes the gate and chooses "10 more minutes" or "Turn off limit" | Should |
| PAR-08 | A "What your child is learning" card explains in plain language what the game builds: cause and effect, planning, trying again, early problem-solving | Should |
| PAR-09 | A short tip explains how to use iOS Guided Access to keep a young child in the app | Should |
| PAR-10 | All Grown-ups text is written for adults and has VoiceOver labels; it is not voiced to the child | Must |
| PAR-11 | Wind-down: 5 minutes before the limit the robot yawns once on the next Result or Workshop screen; at the limit, the run finishes first, then the robot plugs itself in and falls asleep on the rest screen | Should |
| PAR-12 | v1.0 has no purchase UI anywhere, including the Grown-ups area: no World 2 card, no "See details", no "Restore purchases" and no price. These arrive with IAP-02 and IAP-03 in v1.1 | Must |

### 3.12 Persistence (SAV)

| ID | Requirement | Priority |
|---|---|---|
| SAV-01 | Progress (RobotConfig, unlocked parts, bolts, stars per course, stickers, settings) is saved locally after every change | Must |
| SAV-02 | Saves survive app restarts and app updates through a versioned schema with migrations | Must |
| SAV-03 | A corrupt save falls back to defaults without crashing; the previous good save is kept as a backup and tried first | Must |
| SAV-04 | One player profile per device in v1.0, stored inside a `profiles` list so v1.1 can add more without a migration of game data | Must |

### 3.13 Purchases (IAP), v1.1

Not in v1.0. Kept here so the v1.0 code leaves room for them.

| ID | Requirement |
|---|---|
| IAP-01 | One non-consumable product unlocks World 2 using StoreKit 2 through the in_app_purchase plugin |
| IAP-02 | The purchase screen is reachable only after the Parent gate, from the Grown-ups area, and states clearly what the purchase includes |
| IAP-03 | Restore purchases is in Grown-ups settings, behind the gate |
| IAP-04 | Purchase state is read from StoreKit 2 current entitlements and the transaction listener on launch, and cached locally for offline play. `restorePurchases()` is never called automatically, so no Apple ID prompt can appear in front of a child |
| IAP-05 | No consumables, loot boxes, timers to skip, prices or buy prompts on child-facing screens. World 2 on the child's map appears only after purchase |

### 3.14 Audio and voice (AUD)

| ID | Requirement | Priority |
|---|---|---|
| AUD-01 | Background music loops per screen group (menus, workshop, run, test track) | Must |
| AUD-02 | Every hint, instruction and clue has a voice-over clip; text is shown alongside | Must |
| AUD-03 | The audio session uses the iOS ambient category so the silent switch mutes music and effects; each channel also follows its setting | Must |
| AUD-04 | Music ducks while voice-over plays | Should |
| AUD-05 | All clips are loudness-normalised; no sudden loud sounds | Must |

### 3.15 Design system (DES)

These tokens come from the mockup style guide and are the only values used in `lib/app/theme.dart`. Sizes are in points (pt); the mockups are drawn at @2x.

| ID | Requirement | Priority |
|---|---|---|
| DES-01 | Colours: Navy #1E2A4A (text, outlines, shadows), Sky #DFF1FF (default background), Robo blue #7FC8F8 (robot parts, water), Grass #8FD694 (ground, map), Success #1F7A4A (ticks, unlocked, on toggles), Sunny #FFC93C (primary action, bolts), Tangerine #FF8A3D (accents, hazards), Mint #9CF6C2 (robot eyes, stat gains), Cloud #EEF3F9 (panels, tiles), Danger #B23A1E (cross, reset). No other colours on child screens without updating this table | Must |
| DES-02 | Child type is Fredoka, bundled: Display 50/700, Title 28/700, Button 24/700, Body 18/500, Label 14/600. Grown-ups type is Nunito Sans, bundled, at the same sizes with weight 400 to 700 | Must |
| DES-03 | Touch targets follow NFR-05 and replace the style guide's rule: child targets 64 x 64 pt minimum, the primary action 96 pt or larger, 16 pt between targets; Grown-ups area 48 x 48 pt | Must |
| DES-04 | One Sunny primary button per screen. Primary: Sunny fill, Navy 4 pt outline, 6 pt Navy drop shadow. Secondary: white fill, Navy 3 pt outline. Icon button: round, white, Navy 3 pt outline | Must |
| DES-05 | Pressed state: drop the 6 pt shadow and move down 6 pt over 100 ms | Must |
| DES-06 | Part tiles are 96 pt minimum (WRK-02). Selected: pale Sunny fill and Navy 4 pt outline. Default: Cloud fill, light outline. Locked: Cloud fill, dashed outline, padlock icon and cost or map pin | Must |
| DES-07 | Navy 3 to 4 pt outlines on everything a child can touch; on dark overlays (Pause, reveal) the outline is white | Must |
| DES-08 | Motion 150 to 300 ms, ease-out. With Reduce Motion on, movement becomes fades (NFR-11) | Must |
| DES-09 | Text on child screens is always paired with an icon or picture, and every word that tells the child something has a voice clip (AUD-02). Titles may be text only | Must |
| DES-10 | Colour is never the only signal: pair it with an icon, shape, arrow or dashed border (NFR-09). Stat gains and losses use up and down arrows as well as colour | Must |
| DES-11 | The Grown-ups area uses Nunito Sans, no outlines, white cards on Cloud, and a calmer layout; toggles use Success when on | Must |
| DES-12 | Bolt counters use the hexagon bolt icon plus a number in a white pill with a Navy outline; they are read-only and not a button | Must |

---

## 4. Game design rules

Every obstacle is beaten by a stat or ability, and every stat comes from parts, so the child's build is the whole puzzle. Values here are starting points for tuning and live in JSON data files, not in code.

### 4.1 Stats

Each stat runs 0 to 5. Robot stat = base + sum of equipped part modifiers, clamped to 0 to 5.

Base stats: Speed 2, Climb 0, Jump 0, Weight 0, Fuel 0.

| Stat | Effect in a run |
|---|---|
| Speed | Horizontal speed: 120 + 40 x Speed px/s (Helper mode: x 0.8) |
| Climb | Highest single step the robot can climb: Climb x 24 px |
| Jump | Jump height: 60 + 30 x Jump px |
| Weight | 4 or more presses heavy switches and sinks in mud (unless mudproof) |
| Fuel | Jetpack thrust time: Fuel x 0.6 s, refilled on landing |

### 4.2 Parts for v1.0

All values are modifiers added to base stats.

| Slot | Part | Modifiers | Ability | Unlock |
|---|---|---|---|---|
| Moves | Wheels | Speed +2 | | Start |
| Moves | Legs | Climb +3 | | Start |
| Moves | Spring feet | Jump +3, Speed +1 | | Course 3 reward |
| Moves | Jetpack | Speed +1, Fuel +3, Weight -1 | Jetpack | Course 6 reward |
| Moves | Tank tracks | Climb +2, Weight +2, Speed +1 | Mudproof | 40 bolts |
| Body | Light frame | Weight +1 | | Start |
| Body | Heavy frame | Weight +4, Speed -1 | | Course 9 reward |
| Body | Battery body | Weight +1, Fuel +2 | | 30 bolts |
| Arms | Short arms | none | | Start |
| Arms | Grabber arms | none | Grab bars | Course 11 reward |
| Arms | Fan arms | none | Blow leaves | 35 bolts |
| Head | 6 heads (style only) | none | | 2 at start, 3 for 20 bolts each, Gold head from course 15 |

Resulting stats for common builds (Light frame, Short arms):

| Moves | Speed | Climb | Jump | Weight | Fuel |
|---|---|---|---|---|---|
| Wheels | 4 | 0 | 0 | 1 | 0 |
| Legs | 2 | 3 | 0 | 1 | 0 |
| Spring feet | 3 | 0 | 3 | 1 | 0 |
| Jetpack | 3 | 0 | 0 | 0 | 3 |
| Tank tracks | 3 | 2 | 0 | 3 | 0 |

### 4.3 Obstacles

| Obstacle | Icon shown | Beaten by | Fails with |
|---|---|---|---|
| Timed gate | Speed + pips | A pressure plate opens the gate for a set time, shown by a shrinking light ring. Speed 3+ reaches it in time | Gate closes first; a friendly spring pad bounces the robot back to the checkpoint (bump failure) |
| Steps | Climb + pips | Climb high enough for each step | Bump and stop. Steps can't be jumped onto: a jump into a step face bumps |
| Gap | Jump | Jump high and far enough, or Jetpack | Fall |
| Wide gap with bar | Grab | Grabber arms swing across | Jump alone falls short |
| Heavy switch | Weight + pips | Weight 4+ presses it and opens the door | Door stays shut; bump at door |
| Mud | Weight (crossed) | Weight 3 or less, or Mudproof | Robot sinks and mud pushes it back (bump failure) |
| Leaf pile | Fan | Fan arms blow it away, or Jetpack flies over it | Bump and stop |
| Low ceiling | Jetpack | Short controlled thrusts | Hitting the ceiling ends thrust; may fall |

### 4.4 Failures

- A **fall** (gap, water) returns the robot to the last checkpoint after 1 s and costs the no-falls star.
- A **bump** (steps, shut door, closed gate, mud, leaves) stops the robot; after 1.5 s it rolls back to the last checkpoint. Bumps do not cost a star.
- Each failure counts towards the hint ladder for that obstacle (RUN-13).

### 4.5 Course list, World 1 (Gear Garden)

One new idea per course; later courses combine two. Every course follows teach, twist, payoff: an easy first obstacle, a harder version, then a reward moment (bolt arcs over gaps, a ramp, a cluster of bolts). Each course takes 15 to 25 seconds with the intended build in Big Builder. Bolts are placed so all can be collected with the intended build. The last column says which parts reach the golden gear (RUN-16); a gear the intended build can reach is a first discovery, the rest reward coming back. The course files are generated by `tool/courses/make_courses.py`.

| # | Teach, twist, payoff | Intended build | Pit stop | Bolts on course | Reward | Golden gear |
|---|---|---|---|---|---|---|
| 1 | Flat ground, bolts (tutorial) | Any | No | 5 | 5 bolts | Spring feet |
| 2 | One step, two steps, a tall staircase | Legs | No | 6 | 5 bolts | Legs (on top) |
| 3 | A gap, a double gap, a splash gap | Any + jump | No | 6 | Spring feet | Spring feet |
| 4 | Steps, then two timed gates | Legs, swap to Wheels at the pit stop | Yes, between | 7 | 8 bolts | Spring feet |
| 5 | A big gap, then three bigger ones with bolt arcs | Spring feet | No | 8 | 8 bolts | Jetpack |
| 6 | A hop, then two ramp jumps | Wheels (speed off the ramp) | No | 8 | Jetpack | Jetpack |
| 7 | Wide gaps, one under a low roof | Jetpack with fuel control | No | 9 | 10 bolts | Jetpack |
| 8 | Steps and a hop, then longer gaps | Legs; or Legs then Spring feet at the pit stop | Yes | 9 | 10 bolts | Spring feet |
| 9 | Mud, then mud with gaps | Light frame | No | 9 | Heavy frame | Spring feet |
| 10 | Heavy switches, with a hop between | Heavy frame | No | 10 | 12 bolts | Spring feet + Heavy frame |
| 11 | Switches, then mud | Heavy frame, swap to Light frame at the pit stop | Yes, between | 10 | Grabber arms | Spring feet |
| 12 | One bar, two bars, a hop | Grabber arms | No | 10 | 12 bolts | Spring feet + Grabber arms |
| 13 | Leaf piles, a double pile, a gap | Jetpack, or Fan arms | No | 11 | 15 bolts | Jetpack, or Spring feet + Fan arms |
| 14 | Steps, gaps, switches | Legs, then Spring feet, then Heavy frame | Yes, 2 | 12 | 15 bolts | Spring feet + Heavy frame |
| 15 | Finale, all obstacle types | Legs, Wheels, Jetpack, then Wheels + Heavy frame + Grabber arms | Yes, 3 | 12 | Gold head + celebration parade | Spring feet + Heavy frame + Grabber arms |

### 4.6 Bolt economy

- Sources: course rewards 100 bolts (first finish only); about 132 bolts on courses per full pass; course bolts pay on every run, including replays.
- Sinks: Tank tracks 40, Battery body 30, Fan arms 35, 3 heads at 20 (60), 6 decals at 15 to 30 (about 130). Total about 295.
- Target: a child who finishes World 1 once with most bolts can afford all parts and about half the decals; replays and Test Track fun fill the rest. Test Track gives no bolts.

### 4.7 Fairness rules

- Every course has at least one solution using parts the child owns when it unlocks, possibly using its pit stops. The solver test (NFR-18) proves this for every course.
- No randomness in runs: the same build and the same taps always give the same result.
- No timer pressure except visible timed gates.
- Helper mode never changes which builds can beat an obstacle.

---

## 5. Non-functional requirements

The bar: a 3-year-old can play alone within a minute of first launch, and the game never stutters, never crashes and never surprises a parent.

| ID | Area | Requirement |
|---|---|---|
| NFR-01 | Performance | 60 fps in runs on target devices; menus at 60 fps with no dropped frames during transitions |
| NFR-02 | Performance | Cold start to Home in under 3 s on iPhone 11 |
| NFR-03 | Performance | Memory under 300 MB during a run |
| NFR-04 | Size | Install size under 150 MB, with art in WebP or vector formats |
| NFR-05 | Usability | Child-facing touch targets at least 64 x 64 pt; primary actions 96 pt or larger; 16 pt spacing between targets. Grown-ups area targets at least 48 x 48 pt |
| NFR-06 | Usability | No screen requires reading to progress; every instruction is voiced or animated |
| NFR-07 | Usability | Any child-facing screen reaches Home in 2 taps or fewer |
| NFR-08 | Usability | No dead ends: every failure offers a retry or a hint within 3 s |
| NFR-09 | Accessibility | Text contrast at least 4.5:1; colour is never the only signal (shapes and icons too) |
| NFR-10 | Accessibility | VoiceOver labels on all buttons in menus and the Grown-ups area |
| NFR-11 | Accessibility | Respect Reduce Motion: replace bounces, camera pans and confetti with fades |
| NFR-12 | Reliability | Crash-free sessions 99.5% or higher in TestFlight before release (from Xcode Organizer, no third-party SDK) |
| NFR-13 | Reliability | App is fully playable in Airplane mode |
| NFR-14 | Localisation | All strings in ARB files (flutter_localizations) from the first screen; voice clips keyed by locale; English (UK) at launch |
| NFR-15 | Maintainability | Game data (parts, stats, courses, stickers, decals) in JSON assets so tuning needs no code change |
| NFR-16 | Maintainability | Unit tests cover stat calculation, star rules, unlock rules, the simulator, save migration and the parent gate; widget tests cover each screen |
| NFR-17 | Content | No violence, no scary characters, no time-limited offers, no social features, no streaks |
| NFR-18 | Quality | A solver test runs every course in the headless simulator with every build owned at unlock (including pit-stop swaps) and fails if any course has no solution or the intended build fails |
| NFR-19 | Toddler input | Child screens need taps only (plus hold for Jetpack in Big Builder): no swipes, drags, double taps or multi-finger gestures. Touches with 3 or more fingers are ignored (palm guard). Navigation buttons ignore repeat taps for 400 ms |
| NFR-20 | Toddler input | System edge gestures are deferred (`preferredScreenEdgesDeferringSystemGestures`) so a stray swipe does not leave the app; the home indicator auto-hides during runs |
| NFR-21 | Safety | No flashing faster than 3 times per second; celebrations and reveals are skippable by tap and last 4 s at most |

---

## 6. Privacy and compliance

The app collects no personal data at all, which is the simplest way to satisfy Apple's Kids Category, COPPA and the UK Children's Code together. Rules here override any feature request.

| ID | Requirement | Why |
|---|---|---|
| PRV-01 | No third-party advertising, analytics, attribution or crash SDKs in the binary | Apple Kids Category rule |
| PRV-02 | No account, login, email, name, age, birthday or photo collection. Play style is stored on device only | COPPA and Children's Code data minimisation |
| PRV-03 | No network requests in v1.0. Fonts and all assets are bundled; no runtime downloads. (v1.1: StoreKit is the only network use) | Kids Category and data minimisation |
| PRV-04 | Parent gate before settings and every external link (and, in v1.1, purchases and Restore) | Apple Kids Category rule |
| PRV-05 | No App Tracking Transparency prompt and no IDFA access | Nothing to track |
| PRV-06 | App Privacy label in App Store Connect: "Data Not Collected" | Must match the binary |
| PRV-07 | Privacy policy hosted on a public URL, in plain language, stating no data is collected | App Store requirement |
| PRV-08 | Progress and play-time stats stay on device; no iCloud sync in v1.0 | Children's Code default to high privacy |
| PRV-09 | No push notifications | Children's Code: no nudges |
| PRV-10 | Before each release, audit pubspec.lock and the iOS Podfile.lock for any package that sends data | Keeps PRV-01 true as dependencies change |

Kids Category age band: **Ages 5 and Under** is recommended because the youngest players (3 to 5) are the core audience; Ages 6 to 8 remains possible. Decide at submission.

---

## 7. Architecture and tech stack

Flutter widgets run every screen except the obstacle run, which is a Flame game embedded in a widget. Game rules **and run physics** live in pure Dart so they can be unit-tested and run headless by the solver test.

```
PRESENTATION   Flutter screens (Home, Workshop, Map, Result, Test Track, Stickers, Parent gate, Grown-ups)
               Flame game (renders RunSimulator state: robot, obstacles, HUD, pit stop panel)
                    | watch and update state
STATE          Riverpod providers: robotConfig, wallet, progress, stickers, settings; go_router guards Grown-ups routes
                    | apply rules
DOMAIN         Pure Dart, no Flutter imports: stat_calculator, star_rules, unlock_rules, sticker_rules,
               RunSimulator (fixed 1/120 s step), course_solver (tests only), freezed models
                    | load and save via repositories
DATA           Game data JSON (parts, courses, stickers, decals) | Local storage (Hive) | StoreKit (v1.1 only)
```

Screens never compute stats, stars or physics themselves; they ask the domain layer, so the same rules drive the Workshop's "Good at" panel, the Flame run, Test Track and the solver test.

The RunSimulator takes a Course, Stats, a play style and a list of input events (tap and hold times) and steps deterministically. Flame reads its state each frame and interpolates for smooth rendering. This makes fairness rule 4.7 testable.

### 7.1 Stack

| Concern | Choice | Notes |
|---|---|---|
| Framework | Flutter stable 3.x, Dart 3 | iOS target; Android kept buildable |
| Game engine | flame | Rendering and input only; physics in RunSimulator |
| Level authoring | Hand-written course JSON (decided in build step 3) | Courses are a line of obstacles, so JSON stays readable, needs no package, and the pure Dart solver reads it directly. Flame draws tiles from the obstacle list |
| State | flutter_riverpod (with riverpod_generator) | Providers for config, wallet, progress, stickers, settings |
| Navigation | go_router | Parent gate as a redirect guard on /grown-ups |
| Storage | hive_ce | Versioned box with migrations and a backup copy |
| Models | freezed + json_serializable | Immutable models, JSON game data |
| Audio | flame_audio (runs) and audioplayers (menus) | Ambient audio context (AUD-03); preload clips per screen |
| Haptics | Flutter's built-in HapticFeedback | No package needed |
| Animation | flutter_animate; Rive optional for the robot | Respect Reduce Motion |
| Fonts | Fredoka (child screens) and Nunito Sans (Grown-ups) bundled as font assets in pubspec.yaml, both SIL OFL 1.1 variable fonts with the weight set through font variations | No google_fonts package: it fetches at runtime by default (PRV-03) |
| Purchases (v1.1) | in_app_purchase | StoreKit 2 |
| Testing | flutter_test, mocktail, golden tests for screens | Solver test runs in `flutter test` |
| Lint | very_good_analysis | Zero warnings policy |

### 7.2 Folder structure

```
lib/
  main.dart
  app/            router.dart, theme.dart, app.dart
  core/           audio/, storage/, haptics/, l10n/, utils/
  data/           repositories (progress, parts, courses, stickers, decals, settings)
  domain/
    models/       Part, RobotConfig, Stats, Course, Obstacle, Progress, Sticker, Decal, Settings
    rules/        stat_calculator.dart, star_rules.dart, unlock_rules.dart, sticker_rules.dart
    sim/          run_simulator.dart, run_state.dart, input_event.dart
  features/
    onboarding/   first_run_screen.dart
    home/         home_screen.dart, widgets/
    workshop/     workshop_screen.dart, robot_preview.dart, part_tile.dart, good_at_panel.dart
    course_map/   course_map_screen.dart, course_node.dart
    run/          run_screen.dart, pit_stop_panel.dart, hint_bubble.dart,
                  game/ (Flame: robot_component.dart, obstacles/, hud/)
    result/       result_screen.dart, reveal.dart
    test_track/   test_track_screen.dart
    stickers/     sticker_book_screen.dart
    parent_gate/  parent_gate_screen.dart, question_generator.dart
    grown_ups/    settings_screen.dart, rest_screen.dart
assets/
  data/           parts.json, physics.json, stickers.json, decals.json, world1/course_01.json ... course_15.json
  images/         robot/, parts/, decals/, stickers/, tiles/, ui/
  audio/          music/, sfx/, voice/en_GB/
  fonts/          Fredoka
test/             mirrors lib/; test/domain/sim/course_solver_test.dart
```

### 7.3 Data model

```
Part        { id, slot (head|body|arms|moves), nameKey, spriteAsset,
              mods { speed, climb, jump, weight, fuel }, ability? (jetpack|grab|fan|mudproof),
              unlock { type: start|reward|bolts, value } }
RobotConfig { headId, bodyId, armsId, movesId, colour, decalId? }
Stats       { speed, climb, jump, weight, fuel, abilities[] }   // derived, never stored
Obstacle    steps { x, stepWidth, stepHeights[], topWidth }    // one shape per type, keyed by "type"
            | gap { x, width } | timedGate { plateX, x, openSeconds } | ... (more in build step 12)
Course      { id, world, index, lengthPx, obstacles[], bolts[ { x, y } ],
              checkpoints[ { x, pitStop } ], hintKey, rewardPartId?, rewardBolts,
              intendedBuilds[ { parts[], pitStops[ parts[] ] } ],  // intendedBuilds used by the solver test
              gear? { x, y } }                                     // RUN-16 golden gear
SimTuning   physics.json: speed, climb, jump, fuel and gravity constants, Helper time scale,
            respawn delays, robot size, jump buffer
Sticker     { id, iconAsset, clueKey, rule }
Decal       { id, spriteAsset, cost }
Progress    { schemaVersion, activeProfile, profiles[ ProfileData ] }
ProfileData { robot: RobotConfig, unlockedPartIds[], unlockedDecalIds[], bolts,
              courseResults { courseId: { stars, bestBolts, completed, rewardClaimed, foundGear } },
              stickerIds[], partsTried[], playSecondsByDay {} }
Settings    { playStyle (little|big), music, sfx, voice, haptics, dailyLimitMinutes,
              onboardingDone }
Purchases   { world2Unlocked }                                   // v1.1; source of truth is StoreKit
```

---

## 8. Release plan and acceptance criteria

v1.0 ships in five phases over about 13 weeks of part-time work, each ending in a build a child can play. A phase starts only when the gate under the previous phase is met. If the date matters more than scope, Should items (stickers, decals, course preview, wind-down) slip to v1.1 first.

| Phase | Weeks | Work | Gate |
|---|---|---|---|
| 1. Foundations | 1 to 2 | Scaffold, l10n, models, rules, RunSimulator, Hive storage | Rule and simulator tests pass |
| 2. Core loop | 3 to 6 | First-run setup, Home, Workshop, Map, run with courses 1 to 5, pit stops, hint ladder, Helper mode, Result | Three children (at least one aged 3 to 4) play courses 1 to 5 |
| 3. Content | 7 to 9 | All obstacles, courses 6 to 15, Test Track, Parent gate, Grown-ups area | Solver test passes for all 15 courses |
| 4. Sound and feel | 10 to 11 | Music, voice-over, personality, haptics, stickers, decals | Sounds and hints complete for every screen |
| 5. Polish and release | 12 to 13 | Accessibility, toddler input, performance, TestFlight, submission | Checklist 8.1 met |

### 8.1 Release acceptance checklist

- [ ] All Must requirements in sections 3, 5 and 6 pass their tests
- [ ] Solver test (NFR-18) passes for all 15 courses
- [ ] Six children play for 10 minutes each without adult help: at least two aged 3 to 4 (Little Builder) finish course 2, and the rest (Big Builder) finish course 3
- [ ] Runs hold 60 fps on iPhone 11 and iPad 9th gen (Flutter DevTools performance overlay)
- [ ] App works in Airplane mode, and a network proxy shows zero requests during a full session
- [ ] Dependency audit PRV-10 done
- [ ] App Privacy label set to Data Not Collected; privacy policy URL live
- [ ] Kids Category age band chosen; screenshots for 6.7 inch iPhone and 13 inch iPad made from real builds
- [ ] TestFlight crash-free sessions at 99.5% or higher across at least 2 weeks

---

## 9. Working with Claude Code

This file lives at `docs/SRS.md`. `CLAUDE.md` at the project root points every Claude Code session here. Build one step at a time and check each step runs on the simulator before the next.

### 9.1 Build order

1. Scaffold the project, lints, folder structure, l10n setup, router with placeholder screens, landscape lock, theme (DES-01 to DES-12 with bundled Fredoka and Nunito Sans)
2. Domain: freezed models, stat_calculator, star_rules, unlock_rules, with unit tests (sections 4.1 to 4.2, RES-02)
3. RunSimulator for flat ground, steps, gaps and timed gates, with tests; course_solver test skeleton (sections 4.3 to 4.4, NFR-18). Decided: hand-written course JSON (7.1)
4. Data: load parts.json and course JSON; Hive storage with schema version, backup and migration test (SAV-01 to SAV-04)
5. First-run setup and Home (ONB-01, HOM-01 to HOM-06)
6. Workshop with live robot preview and "Good at" panel (WRK-01 to WRK-05, WRK-07, WRK-09, WRK-11, WRK-12)
7. Course map with unlock logic (MAP-01 to MAP-05, MAP-07)
8. Flame run rendering the simulator: robot, steps, gaps, gates, bolts, checkpoints, HUD, jump zone, stat icons (RUN-01 to RUN-10, RUN-12, RUN-15); courses 1 to 5
9. Pit stops, hint ladder and Helper mode (RUN-11, RUN-13, HLP-01 to HLP-05); tutorial (ONB-02)
10. Result screen and rewards (RES-01 to RES-06)
11. Parent gate and Grown-ups settings (PAR-01 to PAR-11)
12. Remaining obstacles in the simulator and courses 6 to 15; solver test green for all
13. Test Track (TRK-01 to TRK-04) and course preview (RUN-14)
14. Audio, voice-over and feel (AUD-01 to AUD-05, FEEL-01 to FEEL-03)
15. Sticker book and decals (STK-01 to STK-04, WRK-06, WRK-10)
16. Accessibility, toddler input, Reduce Motion, performance pass (NFR-01 to NFR-21)
17. Release checklist (section 8.1), TestFlight, submission

Example prompt for step 8: "Read docs/SRS.md sections 3.5, 4 and 7. Build the Flame run screen in lib/features/run/game. It renders RunSimulator state from lib/domain/sim and sends tap and hold events to it. Implement steps and gaps for course_01 to course_03 JSON. Add widget tests for the HUD. Do not add new packages without asking."

---

## 10. Open questions

1. v1.0 price: paid upfront or free. (Does not change requirements.)
2. Kids Category age band: Ages 5 and Under (recommended) or Ages 6 to 8.
3. Art and voice-over source and budget (in-house, commissioned or licensed TTS).
4. iOS bundle identifier. The scaffold uses a placeholder (`com.example.little_builder_robots`), which App Store Connect rejects; set the real one before the first TestFlight build.

---

## 11. Mockup changes from the revision 3 review

The mockups were reviewed against this document on Oct 31, 2026. Build to the requirements; the design canvas should be updated to match.

| Mockup | Change needed | Requirement |
|---|---|---|
| Style guide | Replace "48pt minimum; main action 64 to 92pt" with 64 pt / 96 pt / 16 pt spacing; part tiles 96 pt; locked tile shows cost or map pin, not the word "Locked"; gains in Mint with an up arrow | DES-03, DES-06, DES-10 |
| Splash | Remove "Skip to Home" | HOM-01 |
| Home | Add Test Track and Sticker book buttons; Courses button to 64 pt; fix the speech bubble overlapping the cloud; the "Let's build!" line needs a voice clip | HOM-02, DES-09 |
| Workshop | Home button instead of the back arrow; slot icons instead of colour squares; parts tiles 96 pt; locked tiles use map pin and bolt icon, not "Course 6" / "40 bolts"; "Good at" shows stat pips; paint swatches 64 pt with patterns; add decal picker; Test it! 96 pt | HOM-06, WRK-01, WRK-02, WRK-04, WRK-06, WRK-10 |
| Unlock a part | Tank tracks against Wheels is Climb 0 to 2, Weight 1 to 3, Speed 4 to 3 (a loss) plus the Mudproof icon; stat names as icons; tick 96 pt; remove "you have 52" | WRK-05, DES-10 |
| Course map | Remove the World 2 chip; Home button instead of the back arrow; nodes 64 pt, next node 96 pt with bouncing robot marker; remove the backwards arrow; hint replay button 64 pt | MAP-02, MAP-07, MAP-08, HOM-06 |
| Obstacle run | Replace the Jump button with the right-40% jump zone and a 120 pt icon; add Climb icon with pips on the steps; checkpoint dots on the progress bar; Pause 64 pt; robot drawn with its arms; fix feet overlapping the step | RUN-07, RUN-12, RUN-15, WRK-13 |
| Run paused | Large buttons are Resume, Restart and Workshop; Map, Home and sound are smaller 64 pt buttons; bolts as icons instead of the sentence | RUN-08 |
| Hint bubble | Small bubble next to the robot, course not covered; only the wrench button; remove "Keep trying" and the three-dot indicator; spiral eyes instead of X eyes; robot drawn with its arms | RUN-13, FEEL-01, WRK-13 |
| Result | Rule icons instead of "Finished / All bolts / No falls"; add Play again; Next 96 pt; Home button top left | RES-01, RES-05, HOM-06 |
| New part reveal | Show every stat change (Spring feet: Jump +3 and Speed +1); Try it on 96 pt | RES-04, DES-03 |
| Parent gate | Move the close button off the "3" key; remove "and purchases" from the copy | PAR-01 |
| Grown-ups | Add play style and haptics; add stickers to the progress summary; add the learning card and Guided Access tip; remove the World 2 card and "Restore purchases"; full-width toggle rows | PAR-04, PAR-05, PAR-08, PAR-09, PAR-12 |
| World 2 purchase | v1.1 only; not built in v1.0 | IAP-01 to IAP-05, PAR-12 |
| Rest time | Matches; the message needs a voice clip | PAR-07, DES-09 |
