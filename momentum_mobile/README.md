# momentum_mobile

Flutter client for Momentum. OBD/ELM327 data is read on the **device**; the app sends it to your backend over HTTP.

## API URL (dev)

| Where you run the app | Set `MOMENTUM_API_BASE` to |
|------------------------|----------------------------|
| **Android emulator** (server on same PC) | Omitted — defaults to `http://10.0.2.2:5001/api` |
| **Physical phone** (laptop on same Wi‑Fi) | `http://<your-pc-lan-ip>:5001/api` |

Example (replace with your PC’s address from System Settings / `ipconfig`):

```bash
flutter run --dart-define=MOMENTUM_API_BASE=http://192.168.1.42:5001/api
```

Bluetooth to the ELM327 dongle does **not** go through the laptop — only REST calls do.

## OBD-II (ELM327) on Android

- Open the **OBD** tab. Pair the dongle in Android Bluetooth settings first, then **Connect & read**.
- This build uses **Bluetooth Classic (SPP)** via `flutter_bluetooth_serial`, which matches most cheap **Bluetooth ELM327** adapters.
- If your adapter is **BLE-only**, this screen will not connect — you would need a BLE-based stack instead.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
