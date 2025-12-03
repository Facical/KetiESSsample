# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a visionOS application for monitoring and controlling Energy Storage Systems (ESS). The app provides both 2D dashboard interfaces and immersive 3D visualizations of ESS battery cabinets with real-time monitoring capabilities.

## Build and Run Commands

### Building the Project
```bash
# Open in Xcode
open KetiESSsample2.xcodeproj

# Build from command line (requires xcodebuild)
xcodebuild -project KetiESSsample2.xcodeproj -scheme KetiESSsample -destination 'platform=visionOS Simulator,name=Apple Vision Pro'

# Clean build
xcodebuild clean -project KetiESSsample2.xcodeproj -scheme KetiESSsample
```

### Platform Requirements
- **Target Platform**: visionOS 2.6+
- **Swift Version**: 5.0
- **Xcode**: 26.0+
- **Dependencies**: RealityKit, SwiftUI, Charts, Combine, ARKit

## Architecture Overview

### App Structure

The application follows a multi-space architecture with two main immersive experiences:

1. **MainView** (`KetiESSsample/Views/MainView.swift`)
   - Entry point window displaying system controls and navigation
   - Manages immersive space lifecycle (opening/dismissing spaces)
   - Default window size: 1500x900 (window), 1200x900 (frame)
   - Primary button: RackView launcher (opens AR view and auto-closes MainWindow)
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
   - Features: AR placement, hand tracking with pinch detection, ARKit object tracking
   - Module drag-out with visual feedback, exploded view mode, problem analysis highlighting
   - Two-hand rotation gesture support (dual pinch for rotation)
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

**RackDataModel** (`KetiESSsample/Models/RackDataModel.swift`)
- Comprehensive data structures for CSV data integration
- RackData: System-level metrics (voltage, current, SOC, SOH)
- ModuleData: Per-module aggregates (temp range, voltage range, current, SOC/SOH)
- CellData: Individual cell measurements (voltage, current, temp, SOC, SOH)
- ModuleHealthStatus enum: normal/warning/critical/unknown with color mappings

**ModuleInteractionState** (`KetiESSsample/Models/ModuleInteractionState.swift`)
- Module state tracking for RackView hand interactions
- ModuleState: Position tracking, drag state, pull-out distance (max 0.5m)
- ModuleInteractionManager: Observable class for all module states
- Supports hand tracking integration, collision detection for nearest module

### UI Components

**ESSControlPanel** (`KetiESSsample/Views/ESSControlPanel.swift`)
- 2D dashboard with 4 tabs: Overview, Power, Modules, Analytics
- Charts integration for real-time data visualization
- Power flow diagrams showing input → ESS → output
- Temperature analysis with threshold indicators
- Accessed via NavigationLink from MainView

**RackDataPanel** (`KetiESSsample/Views/RackDataPanel.swift`)
- Advanced data visualization panel with stream graphs
- Tab-based: Rack (system metrics), Module (per-module params), Cell (detailed cell data)
- Parameter selection enums: RackParameter (4), ModuleParameter (11 params)
- Real-time plotting of selected parameters with time range controls

**CalloutBubble** (`KetiESSsample/UI/CalloutBubble.swift`)
- Reusable UI component for AR annotations in RackView
- Displays title and detail text with material background

**ModuleDataBubble** (`KetiESSsample/UI/ModuleDataBubble.swift`)
- Data display for pulled-out modules showing temp, voltage, current, SOC/SOH
- Status indicators for each measurement category
- Return button to place module back in rack

**ControlPanelAttachment** (`KetiESSsample/UI/ControlPanelAttachment.swift`)
- 3D space-attached control panel for RackView
- Placement section (before placement) and control section (after placement)
- Status display: module count, pulled-out count, problem count
- Callbacks: place, reset modules, reposition, close, object tracking toggle

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

**Problem Analysis Mode** (RackView)
- Module status colors: Normal (original), Warning (orange), Critical (red)
- Multi-metric threshold support: SoC, SoH, Current, Voltage, Temperature
- Temperature inverse logic (higher = more dangerous)
- Cell-level coloring when module is pulled out (48 cells per module)
- Automatic material restoration when module returns to rack

**Module-Panel Visual Connection**
- Highlight boxes: Translucent highlight on selected module in Module tab
- Leader lines: 3D lines connecting selected module to data panel
- Dynamic updates: Lines track module and panel position changes

### Extensions

**SIMD3 Extension** (`KetiESSsample/Extensions/SIMD3.swift`)
- Custom `.grounded` property: Projects 3D translations to ground plane (zeros Y-axis)
- Used for horizontal-only object movement in both ESSView and RackView drag gestures

### Utilities

**CSVParser** (`KetiESSsample/Utilities/CSVParser.swift`)
- High-performance CSV parsing with manual date parsing (10x faster than DateFormatter)
- Thread-safe date cache (NSLock protected) for performance
- Supports formats: "2025.7.1 0:00" (CSV) and "yyyy-MM-dd HH:mm:ss"

**ModuleMapping** (`KetiESSsample/Utilities/ModuleMapping.swift`)
- ID mapping between entity names and CSV module IDs
- Constants: 11 modules, 48 cells per module
- Transformations: Entity name ↔ CSV ID (Module1_001 ↔ M01), index conversions
- Lookup table: `allModuleMappings` for all (index, csvId, entityName) tuples

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

### Data Files

**Location**: `DummyData/`
- `Rack_Data_1s.csv`: System-level rack metrics
- `Module_Data_M01_1s.csv`: Module M01 cell data
- `Cell_Data_M01_1s.csv`: Detailed cell telemetry (19MB, Git LFS tracked)

## Git LFS Configuration

Large assets tracked with Git LFS (configured in `.gitattributes`):
- `*.usdz` files
- `*.rcproject` files
- `*.reality` files
- `*.zip` files
- Large CSV data files in `DummyData/`

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

### Hand Tracking Pattern (RackView)
- ARKit hand anchors with left/right chirality detection
- Pinch detection via thumb tip to index tip distance (<0.03m threshold)
- Two-hand rotation via pinch angle tracking
- Module drag-out triggered by pinch on nearest module collision

### Navigation Flow
- Window → NavigationStack → MainView
- NavigationLink for 2D dashboard (ESSControlPanel)
- Environment properties for immersive space management:
  - `@Environment(\.openImmersiveSpace)`
  - `@Environment(\.dismissImmersiveSpace)`

## Development Notes

### Modifying Battery Module Count
When changing the number of battery modules (currently 10):
1. Update module creation loop in `ESSSystemModel.init()` (search: `for i in 0..<10`)
2. Update attachment ForEach range in `ESSView.body`
3. Update attachment positioning loop in RealityView content
4. Adjust grid positioning calculations in `createESSCabinet()`

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
- Update frequency: Change Timer interval in `ESSSystemModel.startMonitoring()` (default: 0.5s)
- Chart history length: Fixed at 50 data points, modify buffer management in `updateSystemData()`

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

### Adding CSV Data Integration
1. Place CSV files in `DummyData/` folder
2. Parse using `CSVParser` utility (supports date caching for performance)
3. Map module/cell IDs using `ModuleMapping` utility
4. Populate `RackDataModel` structures for visualization
5. Display in `RackDataPanel` stream graphs
