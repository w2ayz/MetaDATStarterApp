# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This workspace is for building iOS apps using the **Meta Wearables Device Access Toolkit (DAT) SDK** — an SDK for accessing Ray-Ban Meta glasses camera and sensors from third-party iOS apps. The SDK is distributed via Swift Package Manager at `https://github.com/facebook/meta-wearables-dat-ios`.

## Build Commands

The project uses [xcodegen](https://github.com/yonaskolb/XcodeGen) to generate the `.xcodeproj` from `project.yml`.

```bash
# First time: install xcodegen and generate the project
brew install xcodegen
xcodegen generate

# Simulator build
xcodebuild -scheme MetaDATStarterApp -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 15' build

# Device build
xcodebuild -scheme MetaDATStarterApp -destination 'platform=iOS,id=YOUR_DEVICE_UDID' build
```

Re-run `xcodegen generate` after modifying `project.yml` or adding/removing source files.

**Requirements:** Xcode 15.0+, iOS 16.0+ deployment target.

**Common build failures:**
- Missing package → Add `https://github.com/facebook/meta-wearables-dat-ios` via Xcode > File > Add Package Dependencies
- Wrong deployment target → SDK requires iOS 16.0+
- Missing entitlements → Enable `bluetooth-peripheral` and `external-accessory` background modes

## Testing

Use `MWDATMockDevice` to test without physical hardware. Base test class pattern:

```swift
import XCTest
import MWDATMockDevice

@MainActor
class MockDeviceKitTestCase: XCTestCase {
    private var mockDevice: MockRaybanMeta?

    override func setUp() async throws {
        try? Wearables.configure()
        mockDevice = MockDeviceKit.shared.pairRaybanMeta()
        await mockDevice?.powerOn()
        await mockDevice?.unfold()
        await mockDevice?.don()
    }

    override func tearDown() async throws {
        MockDeviceKit.shared.pairedDevices.forEach { MockDeviceKit.shared.unpairDevice($0) }
        mockDevice = nil
    }
}
```

Mock camera feeds support HEVC video and JPEG/PNG images.

## SDK Architecture

Three SPM modules:
- **MWDATCore** — `Wearables` entry point, registration, device discovery, permissions, selectors
- **MWDATCamera** — `StreamSession`, `VideoFrame`, photo capture
- **MWDATMockDevice** — `MockDeviceKit`, `MockRaybanMeta`, `MockCameraKit` for testing

**Entry point:** Call `Wearables.configure()` once at app launch, then use `Wearables.shared` everywhere.

## App Architecture Pattern

```
MyDATApp/
├── MyDATApp.swift                    # Wearables.configure() + .onOpenURL handler
├── ViewModels/
│   ├── WearablesViewModel.swift      # Registration, device list (@MainActor)
│   └── StreamSessionViewModel.swift  # Streaming, photo capture (@MainActor)
└── Views/
    ├── RegistrationView.swift
    └── StreamView.swift
```

## Key Flows

### Initialization + Registration

```swift
// App entry point
try Wearables.configure()

// Handle Meta AI callback
.onOpenURL { url in
    Task { _ = try? await Wearables.shared.handleUrl(url) }
}

// Start registration (opens Meta AI app)
try Wearables.shared.startRegistration()

// Observe registration state
for await state in Wearables.shared.registrationStateStream() { ... }
```

### Camera Streaming

```swift
let config = StreamSessionConfig(videoCodec: .raw, resolution: .medium, frameRate: 24)
let session = StreamSession(streamSessionConfig: config, deviceSelector: AutoDeviceSelector(wearables: Wearables.shared))

session.statePublisher.listen { state in ... }
session.videoFramePublisher.listen { frame in
    guard let image = frame.makeUIImage() else { return }
    Task { @MainActor in self.currentFrame = image }
}

Task { await session.start() }
```

**Resolution options:** `.high` (720×1280), `.medium` (504×896), `.low` (360×640)
**Frame rate options:** 2, 7, 15, 24, 30 FPS. Lower = higher visual quality per frame.

### StreamSession State Machine

```
stopped → waitingForDevice → starting → streaming → paused → stopped
```

Do **not** attempt to restart during `paused` — wait for the system to resume or stop.

### Permissions

```swift
let status = try await Wearables.shared.checkPermissionStatus(.camera)
let status = try await Wearables.shared.requestPermission(.camera)  // Opens Meta AI
```

## Required Info.plist Configuration

```xml
<key>CFBundleURLTypes</key>  <!-- Your URL scheme for Meta AI callbacks -->
<key>LSApplicationQueriesSchemes</key>  <!-- fb-viewapp -->
<key>UISupportedExternalAccessoryProtocols</key>  <!-- com.meta.ar.wearable -->
<key>UIBackgroundModes</key>  <!-- bluetooth-peripheral, external-accessory -->
<key>NSBluetoothAlwaysUsageDescription</key>
<key>MWDAT</key>  <!-- AppLinkURLScheme, MetaAppID (use "0" in Developer Mode) -->
```

## Debugging Checklist

- Developer Mode enabled in Meta AI app (Settings → Your glasses → Developer Mode) — **resets after firmware updates**
- Meta AI app and glasses firmware on compatible versions (see [version dependencies](https://wearables.developer.meta.com/docs/version-dependencies))
- Internet connection available (required for registration)
- Correct URL scheme in Info.plist

**Known:** Avoid using `DeviceStateSession` concurrently with a camera stream — it is unreliable.

## Links

- [iOS API Reference](https://wearables.developer.meta.com/docs/reference/ios_swift/dat/0.5)
- [Developer Documentation](https://wearables.developer.meta.com/docs/develop/)
- [GitHub / CameraAccess sample](https://github.com/facebook/meta-wearables-dat-ios/tree/main/samples)
