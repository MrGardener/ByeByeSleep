# Installing the ByeByeSleep watch app (Pixel Watch 3)

The heart-rate challenge ("Get your heart going") and the Sensor Quest world
"Pulse Run" read your heart rate live from a small ByeByeSleep app on the watch.
Without a Play Store listing, the watch app has to be installed once from a
computer (Windows, Mac or Linux). Updates later need the same steps.

You need: the watch paired with your phone, the phone app installed, a computer on
the same Wi-Fi, and Android's free `adb` tool
([Platform tools](https://developer.android.com/tools/releases/platform-tools)).

1. **Download the watch app** on the computer:
   https://github.com/MrGardener/ByeByeSleep/releases/download/latest-apk/ByeByeSleep-watch.apk
2. **Turn on developer options on the watch:** Settings → System → About → Versions
   → tap **Build number** 7 times.
3. **Turn on Wi-Fi debugging:** Settings → Developer options → **ADB debugging** on,
   then **Wireless debugging** on. Keep the watch on Wi-Fi (not only Bluetooth).
4. In Wireless debugging tap **Pair new device**. The watch shows an IP:port and a
   6-digit code. On the computer, in the platform-tools folder:
   ```
   adb pair <IP>:<pairing port>      (enter the 6-digit code)
   adb connect <IP>:<port shown on the Wireless debugging screen>
   adb install ByeByeSleep-watch.apk
   ```
5. Open **ByeByeSleep** on the watch once and allow **body sensors**.
6. Turn **Wireless debugging** off again (it uses battery).

**Check it works:** on the phone, Practice → *Get your heart going* → Start. The watch
opens the heart-rate screen by itself and the phone shows your bpm.

**Notes**
- The watch app and phone app must come from the same build source (both from this
  repository's releases): the watch only talks to a phone app signed with the same key.
- During the challenge the watch screen stays on so the sensor keeps reading; it
  closes itself when the challenge ends (or after 15 minutes).
