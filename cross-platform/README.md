# NyxWatch Cross-Platform (macOS • Windows • Linux • Android • iOS)

## 1. macOS (Native Swift — Production Ready)
Built in the root directory (`./build.sh` -> `NyxWatch.app`).

## 2. Windows & Linux (`cross-platform/desktop/`)
```bash
cd cross-platform/desktop
pip install -r requirements.txt
python3 nyxwatch_desktop.py --mode flag --arm-now --mac-studio http://192.168.1.50:8787/alert
```
- **Windows**: locks via `LockWorkStation()`, captures 3s video + `BUSTED` stamp, voice alert via `pyttsx3`.
- **Linux**: locks via `loginctl lock-session` / `gnome-screensaver-command` / `xdg-screensaver`.

## 3. Android (`cross-platform/android/`)
- `NyxWatchService.kt` + `AndroidManifest.xml`: foreground sentinel service using `SensorManager` (pickup/motion), `DevicePolicyManager.lockNow()`, `TextToSpeech` (Flag Mode), and JSON/GPS exfiltration to Mac Studio.

## 4. iOS (`cross-platform/ios/`)
- `NyxWatchIOSApp.swift`: SwiftUI sentinel using `CMMotionManager`, `CLLocationManager`, `AVSpeechSynthesizer`, and Mac Studio JSON/GPS alert.
- *iOS Platform Note*: Apple's iOS sandbox does not allow third-party apps to lock the screen programmatically or access the camera while locked, so iOS runs as an active foreground desk sentinel.
