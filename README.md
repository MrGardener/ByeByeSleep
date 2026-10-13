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
stage; between stages the sound drops for a 20-second breather. Stop and Snooze only
appear after the last stage. Stuck? A hint appears after 2 minutes, a different
challenge after 5, and after 15 minutes an emergency stop lets you type a fixed
sentence to turn the alarm off. Stages are edited per alarm, and every challenge has
a "Try it" practice button.

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
| Charger | Plug in at a charger away from bed | — |

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
