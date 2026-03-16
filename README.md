# MetaDATStarterApp

A minimal iOS starter app demonstrating how to integrate the **Meta Wearables Device Access Toolkit (DAT) SDK** with Ray-Ban Meta glasses. Covers device registration, live camera streaming, photo capture, and video recording — end to end, on real hardware.

---

## What it does

| Feature | Details |
|---|---|
| **Device registration** | Registers your app with Meta AI via deep link, shows connected glasses |
| **Live camera stream** | Streams the glasses POV at 504×896 (medium), 24 fps, raw codec |
| **Photo capture** | Captures JPEG stills and saves them to the iOS Photos library |
| **Video recording** | Records H.264 MP4 while streaming and saves to Photos |
| **Error handling** | Friendly in-UI messages for permission denied, device not found, hinges closed, thermal throttle, etc. |
| **Mock device (debug)** | Wrench button in debug builds activates `MWDATMockDevice` — test without glasses |

---

## Requirements

- Xcode 15.0+
- iOS 16.0+ deployment target
- Physical iPhone to run on device (simulator cannot connect to glasses)
- Ray-Ban Meta glasses with Meta AI app installed
- A Meta Developer account with an app configured at [developers.facebook.com](https://developers.facebook.com)

---

## Quick start

### 1. Install dependencies

```bash
brew install xcodegen
```

### 2. Fill in credentials from the template

Copy the template:

```bash
cp Secrets.xcconfig.template Secrets.xcconfig
```

Open `Secrets.xcconfig` and replace the three placeholder values:

```
META_APP_ID      = YOUR_META_APP_ID       # from Meta Developer portal
META_CLIENT_TOKEN = YOUR_META_CLIENT_TOKEN # from Meta Developer portal
DEVELOPMENT_TEAM = YOUR_APPLE_TEAM_ID     # from Apple Developer portal
```

**Where to find each value:**

| Key | Where to find it |
|---|---|
| `META_APP_ID` | [Meta Developer portal](https://developers.facebook.com) → your app → Settings → Basic → **App ID** |
| `META_CLIENT_TOKEN` | Same page → **Client Token** (under App Secret) |
| `DEVELOPMENT_TEAM` | [Apple Developer portal](https://developer.apple.com/account) → Membership Details → **Team ID** (10-character string, e.g. `ABC123XYZ9`) |

> `Secrets.xcconfig` is gitignored and must never be committed. These values are injected at build time via `$(META_APP_ID)`, `$(META_CLIENT_TOKEN)`, and `$(DEVELOPMENT_TEAM)` in `project.yml`.

### 3. Generate the Xcode project

```bash
xcodegen generate
```

Re-run this command whenever you modify `project.yml` or add/remove source files.

### 4. Open in Xcode and resolve packages

```bash
open MetaDATStarterApp.xcodeproj
```

Xcode will automatically fetch the `MetaWearablesDAT` package from:
```
https://github.com/facebook/meta-wearables-dat-ios
```

### 5. Build and run on device

```bash
xcodebuild \
  -scheme MetaDATStarterApp \
  -destination 'platform=iOS,id=YOUR_DEVICE_UDID' \
  build
```

Or press **Cmd+R** in Xcode with a physical device selected.

---

## First-time setup on device

1. **Enable Developer Mode in Meta AI**
   Settings → Your glasses → Developer Mode
   *(This resets after firmware updates — re-enable if streaming stops working.)*

2. **Register the app**
   Open the app → **Wearables** tab → tap **Register**.
   This opens Meta AI to complete the authorization flow.

3. **Grant DAT camera permission**
   After registration, the Camera tab will prompt for permission the first time you start a stream. This also opens Meta AI.

4. **Start streaming**
   Camera tab → **Start Stream** → put on your glasses → the live feed appears.

---

## Project structure

```
MetaDATStarterApp/
├── App/
│   └── MetaDATStarterApp.swift     # App entry point — Wearables.configure() + URL handler
├── Core/
│   ├── WearablesManager.swift      # Registration state, device list (@MainActor ObservableObject)
│   ├── StreamManager.swift         # Stream session, photo capture, recording (@MainActor)
│   ├── VideoRecorder.swift         # AVAssetWriter H.264 recording (Swift actor)
│   └── StreamSessionError+UI.swift # Friendly error messages for all SDK error cases
├── Views/
│   ├── MainView.swift              # TabView: Wearables + Camera tabs
│   ├── RegistrationView.swift      # Registration flow and device list
│   └── StreamView.swift            # Live preview, record/capture controls, toast feedback
└── Dev/
    ├── MockDeviceService.swift     # Activates MWDATMockDevice in debug builds
    └── MockDevicePanel.swift       # Debug panel UI to control the mock device
```

---

## SDK modules used

| Module | Purpose |
|---|---|
| `MWDATCore` | `Wearables` entry point, device discovery, registration, permissions |
| `MWDATCamera` | `StreamSession`, `VideoFrame`, photo capture |
| `MWDATMockDevice` | Simulated device for testing without hardware (debug only) |

---

## Stream state machine

```
stopped → waitingForDevice → starting → streaming ⇄ paused → stopped
```

The app observes `statePublisher` to keep the UI in sync at every transition.

---

## Debugging checklist

- Developer Mode enabled in Meta AI (resets after firmware updates)
- Meta AI and glasses firmware on [compatible versions](https://wearables.developer.meta.com/docs/version-dependencies)
- `Secrets.xcconfig` present with real `META_APP_ID` and `META_CLIENT_TOKEN`
- URL scheme `metadatstarterapp://` matches what is configured in the Meta Developer portal
- Device connected to internet (required for registration)
- Glasses unfolded and worn (hinges-closed error if folded during stream)

---

## Building without a device

Use the mock device in debug builds. Tap the wrench button (bottom-right) to open the mock panel, activate the mock device, then use the Camera tab normally.

```bash
# Simulator build (mock device only — no real glasses)
xcodebuild \
  -scheme MetaDATStarterApp \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  build
```

---

## Changelog

### v1.0.1
- **Inline permission request** — DAT camera permission is now requested automatically on first stream start instead of failing early. The app opens Meta AI inline if permission has not yet been granted, matching the Meta sample flow.
- **Device gating** — Start Stream button is disabled until at least one device appears in `devicesStream()`. The preview pane shows "No glasses connected" when no device is present, so the button state is always self-explanatory.
- **Start timeout** — If the stream does not reach `.streaming` within 10 seconds of entering `.starting` / `.waitingForDevice`, the session is stopped automatically and an actionable error is shown: *"No active glasses detected. Make sure they're on, unfolded, and in range, then try again."*
- **Timestamped state logs** — Every stream state transition is logged with a `HH:mm:ss.SSS` timestamp (e.g. `[12:24:05.123] stream state → starting`), making the full startup sequence visible in a single Xcode console run.

### v1.0.0
Initial release — device registration, live camera stream, photo capture, video recording, mock device support.

---

## Links

- [Meta Wearables DAT SDK — iOS API Reference](https://wearables.developer.meta.com/docs/reference/ios_swift/dat/0.5)
- [Developer Documentation](https://wearables.developer.meta.com/docs/develop/)
- [SDK GitHub + CameraAccess sample](https://github.com/facebook/meta-wearables-dat-ios/tree/main/samples)
- [Meta Developer Portal](https://developers.facebook.com)
