# When something goes wrong while an alarm rings

## A sensor stops working during the challenges

| What happens | What the app does |
|---|---|
| The phone lacks the sensor (no barometer, no NFC…) | The challenge is swapped for *Broken calculator* before it starts. |
| A sensor or the camera fails when the challenge starts (permission refused, camera busy, battery unreadable) | Swapped for the fallback at once. |
| The watch is not found, or goes quiet for 30 s at any point (taken off, out of range, flat) | Swapped for the fallback. |
| A challenge just does not work for you | After 2 min a hint, after 5 min a **Try a different challenge** button. |
| Nothing works at all | **Emergency stop** (below) at any time; after 15 min also *I can't finish — type to stop*. |

Watch challenges are only offered after Settings → Smartwatch has tested the watch, and only for
the sensors that passed that test.

## Emergency plan: the alarm rings and the owner is not there

1. **It stops by itself.** Every alarm has *Stop ringing after* (default 30 min, 10–60): after that
   the sound stops, the ring screen closes and a *Missed alarm* notification is left.
2. **Anyone nearby can stop it sooner** with the emergency protocol on the ring screen: tap
   *Emergency stop*, then in any order press a volume button, turn Wi-Fi off, turn Bluetooth off and
   turn airplane mode on (swipe down from the top of the screen; the phone may ask to unlock for
   some switches). A red *Emergency stop* button then stops the alarm. Turn Wi-Fi and Bluetooth back
   on afterwards.
3. **Before the first unlock after a restart**, the ring notification has a plain **Stop** button
   (the challenge screen cannot start before the phone is unlocked once).
4. Going away? Switch the alarm off beforehand (if it rings within 30 min the phone asks for its
   lock first), or keep *Stop ringing after* short.
