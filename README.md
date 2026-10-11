# ByeByeSleep

An Android + iPhone alarm clock you can't sleep through. A ringing alarm walks you
through up to four stages of sensor challenges (lights on, walk to a spot, solve a
maze, prove you're awake); Snooze and Stop only appear at the end. The app also
contains Sensor Quest, a game that uses every sensor of the phone.

- Design: [`docs/superpowers/specs/2026-10-11-byebyesleep-design.md`](docs/superpowers/specs/2026-10-11-byebyesleep-design.md)
- Plans: [`docs/superpowers/plans/`](docs/superpowers/plans/)

## Build

```sh
flutter pub get
flutter run
```

CI builds a downloadable debug APK on every pull request (see the run's artifacts).
