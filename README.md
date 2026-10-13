# ByeByeSleep

An Android + iPhone alarm clock you can't sleep through. A ringing alarm walks you
through up to four stages of sensor challenges (lights on, walk to a spot, solve a
maze, prove you're awake); Snooze and Stop only appear at the end. The app also
contains Sensor Quest, a game that uses every sensor of the phone.

- Design: [`docs/superpowers/specs/2026-10-11-byebyesleep-design.md`](docs/superpowers/specs/2026-10-11-byebyesleep-design.md)
- Plans: [`docs/superpowers/plans/`](docs/superpowers/plans/)

## How it works

Each alarm has a list of stages (by default four challenges: orientation hopscotch,
tilt maze, broken calculator and colour words). When it rings you must finish every
stage; the next one starts straight away, unless the alarm has a pause between
challenges (Off, 5–60 s; the sound drops during it). Stop and Snooze only
appear after the last stage.

**Emergency stop.** Anyone can stop a ringing alarm without the challenges: tap
*Emergency stop* on the ring screen and, in any order, press a volume button, turn
Wi-Fi off, turn Bluetooth off and turn airplane mode on. The stop button appears once
all four are done.

Stuck? A hint appears after 2 minutes, a different challenge after 5, and after
15 minutes you can also type a fixed sentence to turn the alarm off. Stages are edited per alarm, and every challenge has
a "Try it" practice button.

## Tools

The app has three tabs: **Alarms**, **Sensor Quest** and **Practice**. Each alarm
combines these tools, in labelled sections of the editor:

| Tool | What it does |
|---|---|
| When | Time, days, label. |
| Challenges | What you must do before Stop/Snooze appear, with an estimate ("About 2–5 min to turn off") and an optional pause between challenges. |
| Series | One alarm that rings N times, every M minutes, starting or ending at its time. The others are listed under it and follow its changes; follow-ups need the same challenges or one quick sum. After Stop you can skip the rest of the series today. "Split into separate alarms" makes them independent. |
| Reminder | A photo and caption of what not to forget, shown while ringing and full screen after Stop. "Reminder only" = no challenges. |
| Watch | With the ByeByeSleep watch app (Pixel Watch 3, other Wear OS watches): "Get your heart going" (heart rate), "Wrist workout" (arm swings) and "Walk with your watch" (steps) use the watch's sensors live ([install guide](docs/watch-install.md)). |
| Check I'm awake | Optional: some minutes after Stop the alarm rings once more with one quick challenge, so dozing off again does not work. |
| Stop ringing after | Default 30 min: an alarm nobody stops (you are away) stops itself and leaves a "Missed alarm" notification. See [docs/safety.md](docs/safety.md). |
| Emergency stop | On the ring screen, for anyone: volume button + Wi-Fi off + Bluetooth off + airplane mode on, any order. |

## iPhone

An unsigned iPhone build (`ByeByeSleep.ipa`, iOS 26+) is published next to the
APK. Install it with a free Apple ID, see [docs/iphone-install.md](docs/iphone-install.md).
The system alarm keeps a Stop button, so it rings again every 2 minutes until
the challenges are done.

## Challenges

| Challenge | What you do | Setup needed |
|---|---|---|
| Orientation hopscotch | Turn the phone through the positions shown | — |
| Tilt maze (levels 1–5) | Roll the ball to the exit (drag, tilt, reversed tilt, rotating maze, compass) | — |
| Broken calculator | Solve sums on a keypad that reshuffles | — |
| Colour words | Tap the ink colour, not the word | — |
| Lights on | Switch on the room light | Measure the room with the light on (optional) |
| Walk | Walk to your spot | Walk bed → spot once (optional) |
| Photo match | Photograph your spot | Two reference photos |
| NFC sticker | Touch your sticker | Register the sticker |
| Barcode | Scan your product | Register the barcode |
| Battery guess | Guess the battery level with the status bar hidden (±25% → ±10%) | — |
| Compass runes | Face each direction shown and hold still | — |
| Climb the stairs | Climb one floor (barometer) | — |
| Time sense | Stop a hidden timer at exactly 20–45 s, counting in your head | — |
| Pulse code | Watch short/long flashes and tap them back | — |
| Colour hunt | Photograph something of the colour shown | — |
| Watch challenges | Wrist workout, walk with your watch, heart rate (own section, only after Settings → Smartwatch test) | Watch set up and tested |

"Use wake-up routine" in the alarm editor sets Lights → Walk → Photo → Maze → Calculator.
Before saving, and every evening at 21:00, ByeByeSleep checks that tomorrow's alarm can
work (permissions, setup). Turning off, deleting or moving an alarm that rings within 30
minutes asks for your fingerprint or PIN.

## Sensor Quest

A game whose worlds each use a different phone sensor (game-controller icon on the alarm list).
Worlds unlock in order; one the phone cannot play is skipped.

| World | Do this | Sensor |
|---|---|---|
| Battery Oracle | Guess the battery level (within 25%) with the status bar hidden | Battery |
| Labyrinth | Three tilt mazes: normal, reversed, turning | Accelerometer, gyroscope |
| Compass Temple | Face four directions in turn | Magnetometer |
| Solar Garden | Grow a plant with real light | Light sensor |
| Ghost Hide | Cover the top of the phone when the ghost looks | Proximity |
| Sky Tower | Climb one floor of real stairs | Barometer |
| Rune Hunt | Touch three different NFC tags | NFC |

**Practice** (dumbbell icon) runs any alarm challenge on demand.

## Build

```sh
flutter pub get
flutter run
```

CI builds a downloadable debug APK on every pull request (see the run's artifacts).

## Install on Android

1. On the phone, open **https://github.com/MrGardener/ByeByeSleep/releases/download/latest-apk/ByeByeSleep.apk**
   — a plain APK (no zip) rebuilt from `main` after every merge. Tagged versions are on the
   [Releases page](https://github.com/MrGardener/ByeByeSleep/releases).
2. Allow "Install unknown apps" for the browser or Files app you open it with.
3. Open the APK and install. Then follow [`docs/testing/pixel-checklist.md`](docs/testing/pixel-checklist.md).

### Release signing (one-time, owner)

Releases are built when a tag `v*` is pushed. Without a keystore they are signed with the shared
test key in `android/app/shared-debug.keystore` (committed on purpose, so every test build installs
over the previous one; it is public, so never ship a store build with it).
To sign them, create a keystore once and keep it safe — losing it means users must uninstall to update:

```sh
keytool -genkeypair -v -keystore release.jks -keyalg RSA -keysize 2048 -validity 10000 -alias byebyesleep
base64 -w0 release.jks   # paste the output into the ANDROID_KEYSTORE_BASE64 secret
```

Add repository secrets (Settings → Secrets and variables → Actions): `ANDROID_KEYSTORE_BASE64`,
`ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS` (`byebyesleep`), `ANDROID_KEY_PASSWORD`.
