# AR Height Measurement App

An iOS app that uses **ARKit** (and LiDAR if available) to measure human height with accuracy close to Apple’s built-in Measure app.

## Features

- High-precision height measurement (sub-centimeter on LiDAR devices)
- Automatic floor and surface detection
- Crosshair preview before placing measurement points
- Floating 3D measurement labels in AR space
- Supports both centimeters and feet/inches
- Works on all ARKit-compatible iPhones (iPhone 6s and newer)


## Requirements

**Hardware**

- iPhone 6s or newer (ARKit required)
- Recommended: iPhone 12 Pro or newer for LiDAR
- Requires a real device (not supported in simulator)

**Software**

- iOS 14.0 or later
- Xcode 12.0 or later
- Swift 5.0 or later


## Installation

1. Clone the repo
   ```bash
   git clone https://github.com/yourusername/height-measurement-app.git
   cd height-measurement-app
   ```
2. Open in Xcode
   ```bash
   open HeightMeasureApp.xcodeproj
   ```
3. Set up signing:
   - Select the project in Xcode
   - Go to **Signing & Capabilities**
   - Choose your Apple Developer Team
   - Make sure ARKit is enabled
4. Connect your iPhone, select it as the target, and run with `Cmd+R`


## Usage

1. Move the device slowly so ARKit detects the floor and surfaces.
2. Point the crosshair at the person’s feet and tap **+**.
3. Point the crosshair at the top of their head and tap **+** again.
4. The measurement will appear as floating 3D text and in the UI.


## Technical Details

- Uses **ARKit** with `ARWorldTrackingConfiguration` for plane detection
- Enables LiDAR scene reconstruction on supported devices
- Stores points as `simd_float3` for precise math
- Calculates distances with `simd_distance()`
- Validates placement using ARKit’s raycasting system

Rendering:
- 3D labels are created with SceneKit and always face the user
- Minimal scene updates are used to keep performance smooth


## Accuracy

- LiDAR devices (iPhone 12 Pro and newer): ±1–2 cm
- Non-LiDAR devices: ±3–5 cm depending on lighting and movement
- Best results achieved in good lighting and on textured surfaces



## Error Handling

- Provides guidance if surface detection fails
- Handles AR tracking loss with recovery instructions
- Manages camera permissions
- Handles session interruptions (e.g., phone calls)



## Project Structure

```
HeightMeasureApp/
├── ViewController.swift      # Main AR logic
├── Main.storyboard           # UI + ARSCNView
├── Info.plist                # Permissions/config
├── LaunchScreen.storyboard   # Launch screen
└── Assets.xcassets           # App icons and images
```


## Limitations

- Requires physical device testing (not available in simulator)
- Accuracy depends on environment conditions
- Works best at ranges under 5 meters

