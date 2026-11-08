# Audio clips to record

Written for: whoever records or commissions the game's audio.

Every file below exists now, built by `python tool/audio/build_audio.py`:

- **Music and sound effects** are synthesised by `tool/audio/synth.py`. They are original, made from code with no samples, so they can ship as they are or be replaced.
- **Voice-over** is a placeholder read by the Windows text-to-speech voice (Microsoft Zira, US English). Replace it with a recorded en_GB voice before release (SRS 10, open question 3). Synthetic voice output may also have licence limits for a paid app. Drop recorded files in with the same names; nothing in the code changes.

The game skips any missing file, so clips can be replaced one at a time. Use AAC in an `.m4a` container. Loudness-normalise every clip (AUD-05) and avoid sudden loud sounds; failure sounds must be funny, never buzzers (FEEL-03).

## Music (AUD-01), looping

- `assets/audio/music/menus.m4a`
- `assets/audio/music/workshop.m4a`
- `assets/audio/music/run.m4a`
- `assets/audio/music/testTrack.m4a`

## Sound effects

- `assets/audio/sfx/tap.m4a`
- `assets/audio/sfx/snap.m4a`
- `assets/audio/sfx/bolt.m4a`
- `assets/audio/sfx/jump.m4a`
- `assets/audio/sfx/land.m4a`
- `assets/audio/sfx/boing.m4a`
- `assets/audio/sfx/splash.m4a`
- `assets/audio/sfx/honk.m4a`
- `assets/audio/sfx/cheer.m4a`
- `assets/audio/sfx/star.m4a`
- `assets/audio/sfx/reveal.m4a`
- `assets/audio/sfx/unlock.m4a`
- `assets/audio/sfx/swing.m4a`
- `assets/audio/sfx/door.m4a`
- `assets/audio/sfx/whoosh.m4a`
- `assets/audio/sfx/jetpack.m4a`
- `assets/audio/sfx/shake.m4a`
- `assets/audio/sfx/yawn.m4a`

## Voice-over, en_GB (108 clips, AUD-02)

Each file is named after the text it reads. Record the text exactly as written.

| File | Line |
|---|---|
| `assets/audio/voice/en_GB/firstRunQuestion.m4a` | Who is playing? |
| `assets/audio/voice/en_GB/goodAtClimb.m4a` | Your robot can climb tall steps. |
| `assets/audio/voice/en_GB/goodAtFan.m4a` | Your robot can blow leaves away. |
| `assets/audio/voice/en_GB/goodAtGrab.m4a` | Your robot can grab bars. |
| `assets/audio/voice/en_GB/goodAtHeavy.m4a` | Your robot is big and heavy. |
| `assets/audio/voice/en_GB/goodAtJetpack.m4a` | Whoosh! Your robot can fly. |
| `assets/audio/voice/en_GB/goodAtJump.m4a` | Boing! Your robot jumps high. |
| `assets/audio/voice/en_GB/goodAtMudproof.m4a` | Your robot rolls through mud. |
| `assets/audio/voice/en_GB/goodAtSpeed.m4a` | Zoom! Your robot is fast. |
| `assets/audio/voice/en_GB/hintClimb.m4a` | These steps are tall! Try legs that climb. |
| `assets/audio/voice/en_GB/hintClimbPuzzle.m4a` | Those steps are too tall for this robot! |
| `assets/audio/voice/en_GB/hintCourse1.m4a` | Roll along and collect the bolts! |
| `assets/audio/voice/en_GB/hintCourse10.m4a` | Press the big switches with a heavy robot. |
| `assets/audio/voice/en_GB/hintCourse10Puzzle.m4a` | Big switches! They need lots of weight. |
| `assets/audio/voice/en_GB/hintCourse11.m4a` | Heavy for the switches, then light for the mud. |
| `assets/audio/voice/en_GB/hintCourse11Puzzle.m4a` | Big switches, then sticky mud! |
| `assets/audio/voice/en_GB/hintCourse12.m4a` | Swing across on the bars with grabber arms! |
| `assets/audio/voice/en_GB/hintCourse12Puzzle.m4a` | Wide gaps with bars over them! |
| `assets/audio/voice/en_GB/hintCourse13.m4a` | Leaf piles! Blow them away or fly over. |
| `assets/audio/voice/en_GB/hintCourse13Puzzle.m4a` | Tall leaf piles block the way! |
| `assets/audio/voice/en_GB/hintCourse14.m4a` | Steps, gaps and switches. Use the pit stops! |
| `assets/audio/voice/en_GB/hintCourse14Puzzle.m4a` | Steps, gaps and switches! Plan your pit stops. |
| `assets/audio/voice/en_GB/hintCourse15.m4a` | The big finale! Everything at once. |
| `assets/audio/voice/en_GB/hintCourse15Puzzle.m4a` | The big finale! Everything at once. |
| `assets/audio/voice/en_GB/hintCourse1Puzzle.m4a` | Roll along and grab every bolt! |
| `assets/audio/voice/en_GB/hintCourse2.m4a` | Steps ahead! Legs are good at climbing. |
| `assets/audio/voice/en_GB/hintCourse2Puzzle.m4a` | Steps ahead, and they get taller! |
| `assets/audio/voice/en_GB/hintCourse3.m4a` | Little gaps! Jump over them. |
| `assets/audio/voice/en_GB/hintCourse3Puzzle.m4a` | Gaps ahead! Can your robot hop over? |
| `assets/audio/voice/en_GB/hintCourse4.m4a` | Climb the steps, then swap to something fast at the pit stop. |
| `assets/audio/voice/en_GB/hintCourse4Puzzle.m4a` | Steps first, then gates that close fast! |
| `assets/audio/voice/en_GB/hintCourse5.m4a` | Big gaps! Springy feet jump far. |
| `assets/audio/voice/en_GB/hintCourse5Puzzle.m4a` | These gaps are big. Who can jump that far? |
| `assets/audio/voice/en_GB/hintCourse6.m4a` | Zoom up the ramp and fly over the gap! |
| `assets/audio/voice/en_GB/hintCourse6Puzzle.m4a` | Ramps! Go fast to fly off them. |
| `assets/audio/voice/en_GB/hintCourse7.m4a` | Huge gaps and a low roof. Fly with the Jetpack! |
| `assets/audio/voice/en_GB/hintCourse7Puzzle.m4a` | Gaps too wide to jump, and a low roof! |
| `assets/audio/voice/en_GB/hintCourse8.m4a` | Climb first, then try springy feet at the pit stop! |
| `assets/audio/voice/en_GB/hintCourse8Puzzle.m4a` | Steps, then gaps that get longer. |
| `assets/audio/voice/en_GB/hintCourse9.m4a` | Sticky mud! Stay light. |
| `assets/audio/voice/en_GB/hintCourse9Puzzle.m4a` | Sticky mud! Heavy robots sink. |
| `assets/audio/voice/en_GB/hintFan.m4a` | Leaves in the way! Try Fan arms or fly over. |
| `assets/audio/voice/en_GB/hintFanPuzzle.m4a` | Those leaves are in the way! |
| `assets/audio/voice/en_GB/hintFlyTiming.m4a` | Hold to fly up, let go to float down! |
| `assets/audio/voice/en_GB/hintGrab.m4a` | Grab the bar! Try Grabber arms. |
| `assets/audio/voice/en_GB/hintGrabPuzzle.m4a` | Too far to jump. Look, a bar to hold! |
| `assets/audio/voice/en_GB/hintHeavy.m4a` | This switch needs a heavy robot! |
| `assets/audio/voice/en_GB/hintHeavyPuzzle.m4a` | This switch needs a heavier robot! |
| `assets/audio/voice/en_GB/hintJetpack.m4a` | Too far to jump! Try the Jetpack. |
| `assets/audio/voice/en_GB/hintJetpackPuzzle.m4a` | Too far for any jump! |
| `assets/audio/voice/en_GB/hintJump.m4a` | What a gap! Try parts that jump. |
| `assets/audio/voice/en_GB/hintJumpPuzzle.m4a` | That gap is too wide to jump! |
| `assets/audio/voice/en_GB/hintJumpTiming.m4a` | Tap jump right at the edge! |
| `assets/audio/voice/en_GB/hintLight.m4a` | Too heavy for the mud! Try a lighter body. |
| `assets/audio/voice/en_GB/hintLightPuzzle.m4a` | This robot is too heavy for the mud! |
| `assets/audio/voice/en_GB/hintSpeed.m4a` | Too slow! Try faster parts. |
| `assets/audio/voice/en_GB/hintSpeedPuzzle.m4a` | That gate closes too fast for this robot! |
| `assets/audio/voice/en_GB/homeGreeting.m4a` | Let's build! |
| `assets/audio/voice/en_GB/homeIdlePlay.m4a` | Tap Play to build your robot! |
| `assets/audio/voice/en_GB/needMoreBolts.m4a` | Collect more bolts on the courses! |
| `assets/audio/voice/en_GB/newPartTitle.m4a` | New part! |
| `assets/audio/voice/en_GB/newStickerTitle.m4a` | New sticker! |
| `assets/audio/voice/en_GB/partFromCourse.m4a` | Finish that course to win this part! |
| `assets/audio/voice/en_GB/pitStopHint.m4a` | Pit stop! Swap a part, then tap Go. |
| `assets/audio/voice/en_GB/restMessage.m4a` | Time to rest! The robot is recharging. |
| `assets/audio/voice/en_GB/sayBoing.m4a` | Boing! |
| `assets/audio/voice/en_GB/sayClunk.m4a` | Clunk! |
| `assets/audio/voice/en_GB/sayGear.m4a` | A golden gear! |
| `assets/audio/voice/en_GB/sayHooray.m4a` | Hooray! |
| `assets/audio/voice/en_GB/saySplash.m4a` | Splash! |
| `assets/audio/voice/en_GB/saySwing.m4a` | Swing! |
| `assets/audio/voice/en_GB/sayWhee.m4a` | Wheee! |
| `assets/audio/voice/en_GB/sayWhoops.m4a` | Whoops! |
| `assets/audio/voice/en_GB/sayWhoosh.m4a` | Whoosh! |
| `assets/audio/voice/en_GB/sayYum.m4a` | Yum, bolts! |
| `assets/audio/voice/en_GB/sayZoom.m4a` | Zoom zoom! |
| `assets/audio/voice/en_GB/screenResult.m4a` | You did it! |
| `assets/audio/voice/en_GB/stickerClueAllMoves.m4a` | Try every kind of Moves part. |
| `assets/audio/voice/en_GB/stickerClueBoing.m4a` | Bump into some tall steps. |
| `assets/audio/voice/en_GB/stickerClueBolt.m4a` | Pick up a bolt. |
| `assets/audio/voice/en_GB/stickerClueCeiling.m4a` | Bonk your head on a low roof. |
| `assets/audio/voice/en_GB/stickerClueDecal.m4a` | Put a sticker on your robot. |
| `assets/audio/voice/en_GB/stickerClueGate.m4a` | Make a gate open. |
| `assets/audio/voice/en_GB/stickerClueGear.m4a` | Find a golden gear. Some hide up high! |
| `assets/audio/voice/en_GB/stickerClueGoldHead.m4a` | Wear the Gold head. |
| `assets/audio/voice/en_GB/stickerClueHeadSwap.m4a` | Try on a new head. |
| `assets/audio/voice/en_GB/stickerClueHint.m4a` | Tap the wrench when you're stuck. |
| `assets/audio/voice/en_GB/stickerClueHop.m4a` | Tap to make your robot hop. |
| `assets/audio/voice/en_GB/stickerClueJetpack.m4a` | Fly with the Jetpack. |
| `assets/audio/voice/en_GB/stickerClueJump.m4a` | Make your robot jump! |
| `assets/audio/voice/en_GB/stickerClueLeaves.m4a` | Blow away a leaf pile. |
| `assets/audio/voice/en_GB/stickerClueMud.m4a` | Get stuck in the mud. |
| `assets/audio/voice/en_GB/stickerClueNewPart.m4a` | Get a new part. |
| `assets/audio/voice/en_GB/stickerCluePaint.m4a` | Paint your robot. |
| `assets/audio/voice/en_GB/stickerCluePitStop.m4a` | Swap a part at a pit stop. |
| `assets/audio/voice/en_GB/stickerClueRamp.m4a` | Zoom off a ramp. |
| `assets/audio/voice/en_GB/stickerClueSplash.m4a` | Fall in the water. Splash! |
| `assets/audio/voice/en_GB/stickerClueSwing.m4a` | Swing on a bar. |
| `assets/audio/voice/en_GB/stickerClueSwitch.m4a` | Press a heavy switch. |
| `assets/audio/voice/en_GB/stickerClueTestTrackLap.m4a` | Go all the way round the Test Track. |
| `assets/audio/voice/en_GB/stickerClueThreeStars.m4a` | Get 3 stars on a course. |
| `assets/audio/voice/en_GB/stickerClueWorld1.m4a` | Finish all of Gear Garden. |
| `assets/audio/voice/en_GB/testTrackHint.m4a` | Try your robot on every kind of obstacle! |
| `assets/audio/voice/en_GB/testTrackLocked.m4a` | Finish course 3 to open the Test Track! |
| `assets/audio/voice/en_GB/tryNewParts.m4a` | Try new parts? |
| `assets/audio/voice/en_GB/tutorialTapJump.m4a` | Tap here to jump! |
| `assets/audio/voice/en_GB/tutorialTapPart.m4a` | Tap a part to try it! |
| `assets/audio/voice/en_GB/tutorialTestIt.m4a` | Now tap Test it! |
