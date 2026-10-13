# ByeByeSleep on iPhone

There is no Apple developer account yet, so the iPhone build is **unsigned**.
You sign it yourself with your free Apple ID when you install it.

## What you need

- An iPhone with **iOS 26 or later** (alarms use Apple's AlarmKit).
- A Mac or Windows computer with [Sideloadly](https://sideloadly.io) or
  [AltStore](https://altstore.io), and a USB cable.

## Install

1. Download `ByeByeSleep.ipa` from the
   [latest build](https://github.com/MrGardener/ByeByeSleep/releases/tag/latest-apk)
   (or from a version release).
2. Connect the iPhone and open Sideloadly (or AltStore).
3. Drop the `.ipa` in, enter your Apple ID and press Start.
4. On the iPhone: Settings → General → VPN & Device Management → your Apple ID →
   Trust. Then turn on Settings → Privacy & Security → Developer Mode if asked.
5. Open ByeByeSleep and allow **Alarms** when it asks (or Settings → ByeByeSleep →
   Alarms).

A free Apple ID signature lasts **7 days**. Re-install (AltStore can refresh it
automatically) before it runs out, or the app will not open. Your alarms are kept.

## How alarms work on iPhone

iOS does not let an app hide the Stop button of an alarm, so ByeByeSleep uses a
**backup chain**:

- At the alarm time iOS shows the alarm, even in silent mode or a Focus.
- Tap **Challenges** to open the app on the alarm's challenges.
- If you tap **Stop** instead, it rings again 2 minutes later, and again every 2
  minutes (up to 10 times, within "Stop ringing after"), until the challenges
  are done.
- Opening the app while an alarm is ringing always goes straight to its
  challenges.

Repeating alarms are armed two rings ahead. Opening the app (finishing the
challenges does this) arms the next ones.

## What is different from Android

| | Android | iPhone |
|---|---|---|
| Stop hidden until the challenges are done | Yes | No: backup chain instead |
| Alarm volume forced up | Yes | No: iOS alarm volume |
| Lights on, climbing stairs, NFC sticker | Yes | Replaced by a fallback challenge (no light sensor or barometer access; NFC needs a paid account) |
| Pixel Watch challenges | Yes | Not yet |
