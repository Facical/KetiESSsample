# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a visionOS application for monitoring and controlling Energy Storage Systems (ESS). The app provides both 2D dashboard interfaces and immersive 3D visualizations of ESS battery cabinets with real-time monitoring capabilities.

## Build and Run Commands

### Building the Project
```bash
# Open in Xcode
open KetiESSsample.xcodeproj

# Build from command line (requires xcodebuild)
xcodebuild -project KetiESSsample.xcodeproj -scheme KetiESSsample -destination 'platform=visionOS Simulator,name=Apple Vision Pro'
```

### Platform Requirements
- **Target Platform**: visionOS 2.0+, macOS 15+, iOS 18+
- **Swift Version**: 6.0+
- **Dependencies**: RealityKit, SwiftUI, Charts, Combine

## Architecture Overview

### App Structure

The application follows a multi-space architecture with two main immersive experiences:

1. **MainView** (`KetiESSsample/Views/MainView.swift`)
   - Entry point window displaying system controls and navigation
   - Manages immersive space lifecycle (opening/dismissing spaces)
   - Default window size: 1500x900 (window), 1200x900 (frame)
   - Two primary buttons: ESSView toggle and RackView launcher
   - Automatically dismisses previous immersive space when switching

2. **ESSView** (Real-time Monitoring - `KetiESSsample/Views/ESSView.swift`)
   - Immersive mixed reality space showing 3D ESS cabinet
   - **Procedurally generated** RealityKit 3D model (created in code, not loaded from assets)
   - Real-time data visualization with live battery module monitoring
   - Interactive gestures: drag to translate, magnify to scale
   - Attachments system for displaying module info bubbles and system status panel
   - 10 battery modules displayed in 5x2 grid configuration
   - Toggle controls for door animation (commented out) and label visibility

3. **RackView** (AR Model Viewer - `KetiESSsample/Views/RackView.swift`)
   - Immersive AR space for placing and exploring ESS rack models
   - **Asset-based**: Loads 3D models from Reality Composer Pro (.usdz files)
   - Two-phase interaction: placement mode → exploration mode
   - Features: AR placement, callout labels with leader lines, exploded view
   - Memory-optimized collision detection (root bounding box only)
   - Billboard components for always-facing labels

### Data Model

**ESSSystemModel** (`KetiESSsample/Models/ESSModel.swift`)
- Observable class managing system-wide state
- Monitors 10 battery modules with real-time updates (0.5s interval)
- Tracks: voltage, current, temperature, SoC (State of Charge), module status
- Maintains 50-point rolling history for power, voltage, and temperature graphs
- Module statuses: normal (green), warning (yellow), critical (red), offline (gray)

**BatteryModule**
- Individual module state with position, voltage, current, temperature, SoC
- Status evaluation: critical if temp > 40°C, warning if temp > 35°C or SoC < 20%

**RackPart** (`KetiESSsample/Models/RackParts.swift`)
- Data model for rack component metadata (entity name, title, detail, offset)
- Currently unpopulated - designed to be filled after inspecting loaded Rack.usdz structure
- Used by RackView for callout attachments and leader lines

### UI Components

**ESSControlPanel** (`KetiESSsample/Views/ESSControlPanel.swift`)
- 2D dashboard with 4 tabs: Overview, Power, Modules, Analytics
- Charts integration for real-time data visualization
- Power flow diagrams showing input → ESS → output
- Temperature analysis with threshold indicators
- Accessed via NavigationLink from MainView

**CalloutBubble** (`KetiESSsample/UI/CalloutBubble.swift`)
- Reusable UI component for AR annotations in RackView
- Displays title and detail text with material background

**Immersive Space Configuration**
- ESSView: Mixed immersion style, registered as "ESSView"
- RackView: Mixed immersion style, registered as "RackView"
- Only one immersive space active at a time (MainView handles dismissal when switching)

### 3D Model Systems

**ESSView - Procedural Generation** (`createESSCabinet()` in ESSView.swift)

The ESS cabinet is built entirely in code using RealityKit primitives:
- **Frame**: 0.8m × 2.0m × 0.6m dark metallic exterior box
- **Interior**: Slightly smaller interior space (0.75m × 1.95m × 0.55m)
- **Battery Modules**: 10 modules in 5×2 grid, each with 8 blue cylindrical cells
- **Control Panel**: Top-mounted panel with LED indicators (5 LEDs) and glowing screen
- **Cooling Vents**: 3 horizontal vents at bottom
- **Internal Cabling**: 5 colored cables (yellow, black, red, blue)
- **Door**: Currently commented out with handle and window components

**RackView - Asset Loading** (RackView.swift)

Loads pre-built 3D models from Reality Composer Pro:
- Uses `Entity(named: "Rack", in: realityKitContentBundle)` to load .usdz assets
- Models stored in `Packages/RealityKitContent/Sources/RealityKitContent/RealityKitContent.rkassets/`
- Auto-grounds model by subtracting `bounds.min.y` from position
- Applies 0.8x scale factor for appropriate sizing
- Generates single root collision box from visual bounds (memory-optimized)

**Interaction Features**
- **ESSView**: Drag to translate (grounded), magnify to scale, toggle labels, door animation (disabled)
- **RackView**: Two-phase (placement → exploration), drag to reposition, magnify to scale, callout toggle, exploded view
- Billboard components for info bubbles (always face user)
- Collision shapes for gesture targeting

### Extensions

**SIMD3 Extension** (`KetiESSsample/Extensions/SIMD3.swift`)
- Custom `.grounded` property: Projects 3D translations to ground plane (zeros Y-axis)
- Used for horizontal-only object movement in both ESSView and RackView drag gestures

**Entity Extensions** (RackView.swift)
- `forEachDescendant(_:)`: Recursive traversal of entity hierarchy
- `worldPosition`: Get/set entity position in world coordinates
- `findEntityRecursive(named:)`: Recursive name-based entity search
- `fitRackAttachmentWidth(_:targetWidth:)`: Scale attachments to target width based on visual bounds

### RealityKitContent Package

**Location**: `Packages/RealityKitContent/`
- Swift package for RealityKit assets created in Reality Composer Pro
- Platform compatibility: visionOS 2.0+, macOS 15+, iOS 18+
- Assets stored in `Sources/RealityKitContent/RealityKitContent.rkassets/`
- Contains Rack.usdz and Rack.usda models
- All large asset files (*.usdz, *.rcproject, *.reality, *.zip) tracked with Git LFS

## Git LFS Configuration

Large 3D assets are tracked with Git LFS:
- *.usdz files
- *.rcproject files
- *.reality files
- *.zip files

## Code Patterns

### State Management
- Use `@ObservedObject` for `ESSSystemModel` passed between views
- Use `@StateObject` for model initialization in root views
- Timer-based updates for real-time data simulation (0.5s interval)

### RealityKit Attachments
```swift
// Attachment pattern used throughout ESSView
Attachment(id: "identifier") {
    // SwiftUI content
}
// Then positioned and configured in RealityView update closure
attachment.components.set(BillboardComponent())
```

### Gesture Handling
- Store initial position/scale before gesture
- Reset to nil on gesture end
- Apply transformations relative to scene coordinate space

### Navigation Flow
- Window → NavigationStack → MainView
- NavigationLink for 2D dashboard (ESSControlPanel)
- Environment properties for immersive space management:
  - `@Environment(\.openImmersiveSpace)`
  - `@Environment(\.dismissImmersiveSpace)`

## Development Notes

### Modifying Battery Module Count
When changing the number of battery modules (currently 10):
1. Update module creation loop in `ESSSystemModel.init()` - line 53
2. Update attachment ForEach range in `ESSView.body` - line 97
3. Update attachment positioning loop in RealityView content - line 72
4. Adjust grid positioning calculations in `createESSCabinet()` - line 204

### Adding New Immersive Spaces
New immersive spaces must be registered in `EntryPoint.swift`:
```swift
ImmersiveSpace(id: "NewSpaceID") {
    NewSpaceView()
}
.immersionStyle(selection: .constant(.mixed), in: .mixed)
```
Then update MainView to handle opening/dismissing the new space.

### Real-time Data Configuration
- Update frequency: Change Timer interval in `ESSSystemModel.startMonitoring()` (default: 0.5s) - line 75
- Chart history length: Fixed at 50 data points, modify buffer management in `updateSystemData()` - lines 113-120

### Working with Rack Models
**Adding callouts to RackView**:
1. Inspect loaded Rack.usdz structure to identify entity names
2. Populate `RackParts.all` array with RackPart instances
3. Callouts will automatically generate with leader lines on next run

**Memory considerations**:
- RackView uses root-only collision detection to prevent memory crashes
- Avoid `generateCollisionShapes(recursive: true)` on complex models
- Use single bounding box collision instead

### 3D Asset Management
- Reality Composer Pro files (.rcproject) in `Packages/RealityKitContent/`
- Export assets as .usdz or .reality files
- Large assets auto-tracked by Git LFS (.gitattributes configured)
- Access via `realityKitContentBundle` and `Entity(named:in:)`
