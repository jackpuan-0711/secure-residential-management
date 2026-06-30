# Firebase-connected ESP32 charger demo

This is the Android app's physical charger simulator. It publishes one of two
physical states to Firestore every five seconds:

- `idle`: ESP32 is online and the battery is not inserted.
- `charging`: ESP32 is online and the battery is detected.

The app determines `Device: Not connected` when no heartbeat has arrived for
20 seconds. The ESP32 does not publish a disconnected value because it cannot
send data after losing power or Wi-Fi.

## Arduino IDE setup

Install these libraries:

- `ArduinoJson`
- `hd44780` by Bill Perry
- ESP32 board support, which supplies `WiFi`, `HTTPClient`, and
  `WiFiClientSecure`

Copy `secrets.example.h` to a new Arduino tab named `secrets.h`, then fill in
the Wi-Fi and Firebase device account values. Open and upload
`ev_charger_firebase.ino` using `ESP32 Dev Module` and a 115200 baud serial
monitor.

The firmware uses the Firestore REST commit API with a `REQUEST_TIME`
transform. This makes `lastSeenAt` a trusted server timestamp and satisfies
the deployed Firestore rule.

## Expected test sequence

1. Leave the ESP32 without USB power. Within 20 seconds the app shows
   `Device: Not connected`.
2. Power the ESP32 and wait for heartbeat HTTP code `200`. The app shows
   `Device: Idle`.
3. Insert the demo battery so GPIO34 exceeds 2.0 V. The app shows
   `Device: Charging`.
4. Remove the battery. The app returns to `Device: Idle`.
