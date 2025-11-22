import SwiftUI
import RealityKit
import RealityKitContent
import simd

private let targetCalloutWidth: Float = 0.35

// MARK: - Entity Extensions
extension Entity {
    func forEachDescendant(_ body: (Entity) -> Void) {
        body(self)
        for c in children { c.forEachDescendant(body) }
    }

    var worldPosition: SIMD3<Float> {
        let m = transformMatrix(relativeTo: nil)
        return .init(m.columns.3.x, m.columns.3.y, m.columns.3.z)
    }

    func setWorldPosition(_ p: SIMD3<Float>) {
        var m = transformMatrix(relativeTo: nil)
        m.columns.3 = SIMD4<Float>(p.x, p.y, p.z, 1)
        setTransformMatrix(m, relativeTo: nil)
    }

    func findEntityRecursive(named name: String) -> Entity? {
        if self.name == name {
            return self
        }
        for child in children {
            if let found = child.findEntityRecursive(named: name) {
                return found
            }
        }
        return nil
    }
}

// MARK: - Utility Functions
@inline(__always)
func fitRackAttachmentWidth(_ e: Entity, targetWidth: Float) {
    let vb = e.visualBounds(relativeTo: nil)
    let current = max(0.0001, vb.extents.x * 2)
    let s = targetWidth / current
    e.setScale(e.scale * SIMD3<Float>(repeating: s), relativeTo: e.parent)
}

// Entity dump removed for memory optimization

// MARK: - Rack View
struct RackView: View {
    // Placement state
    @State private var isPlaced = false
    @State private var placementPosition: SIMD3<Float> = [0, 0, -2.0]

    // Entity state
    @State private var rackEntity: Entity?
    @State private var showCallouts: Bool = false
    @State private var updateSub: EventSubscription?

    // Interaction state
    @State private var initialPosition: SIMD3<Float>?
    @State private var initialScale: SIMD3<Float>?
    @State private var explodedView: Bool = false
    @State private var explosionAmount: Float = 0.0

    // Loading state
    @State private var isLoading = true
    @State private var loadingError: String? = nil

    // Data model
    @StateObject private var rackDataModel = RackSystemModel()

    // MARK: - Body
    var body: some View {
        ZStack {
            RealityView { content, attachments in
                // Load Rack model
                if rackEntity == nil {
                    isLoading = true

                    // Load Rack scene from Reality Composer Pro
                    do {
                        print("🔄 Loading Rack model (this may take a moment)...")

                        // Entity(named:in:) throws but returns a non-optional Entity
                        let rack = try await Entity(named: "Rack", in: realityKitContentBundle)

                        print("✅ Rack model loaded successfully")

                        // MEMORY OPTIMIZED: Use ONLY root bounding box collision
                        // No recursive collision generation to prevent memory crash

                        // Position the rack
                        let bounds = rack.visualBounds(relativeTo: nil)
                        rack.position = placementPosition
                        rack.position.y -= bounds.min.y // Ground the model
                        // rack.scale *= 0.5 // Reduced scale for better memory performance

                        // Add root collision box
                        let size = bounds.extents
                        let boxShape = ShapeResource.generateBox(size: size)
                        rack.components.set(CollisionComponent(shapes: [boxShape]))

                        // Add input target for gestures
                        rack.components.set(InputTargetComponent(allowedInputTypes: [.direct, .indirect]))

                        content.add(rack)
                        rackEntity = rack
                        isLoading = false
                        loadingError = nil

                        print("✅ Rack model added to scene")
                    } catch {
                        loadingError = "Error loading model: \(error.localizedDescription)"
                        isLoading = false
                        print("❌ Error loading Rack model: \(error)")
                        return
                    }
                }

                guard let rack = rackEntity else { return }

                // Setup attachments for parts (only if placed and callouts are shown)
                if isPlaced && showCallouts {
                    for part in RackParts.all {
                        guard let host = rack.findEntityRecursive(named: part.entityName) else {
                            print("❌ Cannot find entity:", part.entityName)
                            continue
                        }

                        let worldBounds = host.visualBounds(relativeTo: nil)
                        let hostWorldPos = worldBounds.center
                        let worldTarget = hostWorldPos +
                            SIMD3<Float>(0, worldBounds.extents.y * 0.5 + 0.15, 0) +
                            part.offset

                        // Debug probe
                        let probeName = "Probe:\(part.id)"
                        if rack.findEntity(named: probeName) == nil {
                            let probe = ModelEntity(
                                mesh: .generateSphere(radius: 0.02),
                                materials: [SimpleMaterial(color: .red, isMetallic: false)]
                            )
                            probe.name = probeName
                            rack.addChild(probe)
                        }
                        if let probe = rack.findEntity(named: probeName) {
                            probe.setWorldPosition(worldTarget)
                            probe.isEnabled = showCallouts
                        }

                        // Attachment callout
                        if #available(visionOS 2.0, *), let callout = attachments.entity(for: part.id) {
                            callout.name = "Attachment:\(part.id)"
                            if callout.parent == nil { rack.addChild(callout) }
                            callout.setWorldPosition(worldTarget)
                            callout.components.set(BillboardComponent())

                            var inputTarget = InputTargetComponent()
                            inputTarget.allowedInputTypes = [.direct, .indirect]
                            callout.components.set(inputTarget)

                            fitRackAttachmentWidth(callout, targetWidth: targetCalloutWidth)
                            callout.isEnabled = showCallouts
                        }

                        // Leader lines
                        if rack.findEntity(named: "Leader:\(part.id)") == nil {
                            let stick = ModelEntity(
                                mesh: .generateBox(size: [0.002, 0.002, 1.0]),
                                materials: [SimpleMaterial(color: .white, isMetallic: false)]
                            )
                            stick.name = "Leader:\(part.id)"
                            rack.addChild(stick)

                            let tipMesh: MeshResource = (try? .generateCone(height: 0.02, radius: 0.008))
                                ?? .generateSphere(radius: 0.009)
                            let tip = ModelEntity(
                                mesh: tipMesh,
                                materials: [SimpleMaterial(color: .white, isMetallic: false)]
                            )
                            tip.name = "Arrow:\(part.id)"
                            rack.addChild(tip)
                        }
                    }
                }

                // Update loop for leader lines
                if updateSub == nil && isPlaced {
                    updateSub = content.subscribe(to: SceneEvents.Update.self) { _ in
                        guard let rack = rackEntity, showCallouts else { return }

                        // Update attachment sizes
                        if #available(visionOS 2.0, *) {
                            for part in RackParts.all {
                                if let callout = rack.children.first(where: { $0.name == "Attachment:\(part.id)" }) {
                                    fitRackAttachmentWidth(callout, targetWidth: targetCalloutWidth)
                                }
                            }
                        }

                        // Update leader lines
                        for part in RackParts.all {
                            guard let host = rack.findEntityRecursive(named: part.entityName) else { continue }

                            let worldBounds = host.visualBounds(relativeTo: nil)
                            let A = worldBounds.center

                            var b: SIMD3<Float>?
                            if #available(visionOS 2.0, *) {
                                if let callout = rack.children.first(where: { $0.name == "Attachment:\(part.id)" }) {
                                    b = callout.worldPosition
                                }
                            }
                            guard let B = b else { continue }

                            guard
                                let stick = rack.findEntity(named: "Leader:\(part.id)") as? ModelEntity,
                                let tip = rack.findEntity(named: "Arrow:\(part.id)") as? ModelEntity
                            else { continue }

                            let mid = (A + B) * 0.5
                            stick.setWorldPosition(mid)
                            stick.look(at: B, from: mid, relativeTo: nil)
                            let len = max(simd_length(B - A), 0.05)
                            stick.scale = [1, 1, len]

                            let dir = simd_normalize(B - A)
                            tip.setWorldPosition(B - dir * 0.015)
                            tip.look(at: B, from: tip.worldPosition, relativeTo: nil)
                        }
                    }
                }
            } update: { content, attachments in
                // Update data panel position
                guard let rack = rackEntity, isPlaced else { return }

                if #available(visionOS 2.0, *) {
                    if let dataPanel = attachments.entity(for: "rackDataPanel") {
                        if dataPanel.parent == nil {
                            content.add(dataPanel)
                            print("✅ Data panel attached to scene")
                        }

                        // Position panel to the right of the rack (independent position)
                        let rackPos = rack.position(relativeTo: nil)
                        let bounds = rack.visualBounds(relativeTo: nil)

                        // Place panel 1.5 meters to the right of rack, at same height
                        let panelWorldPos = SIMD3<Float>(
                            rackPos.x + bounds.extents.x * 0.6 + 1.2,  // Right side with gap
                            rackPos.y,                                  // Same height as rack
                            rackPos.z                                   // Same depth
                        )

                        dataPanel.setPosition(panelWorldPos, relativeTo: nil)
                        dataPanel.components.set(BillboardComponent())
                        dataPanel.isEnabled = true

                        print("📊 Data panel world position: \(panelWorldPos)")
                        print("📦 Rack position: \(rackPos)")
                    } else {
                        print("❌ Data panel attachment not found")
                    }
                }
            } attachments: {
                // Data Panel Attachment
                if #available(visionOS 2.0, *) {
                    Attachment(id: "rackDataPanel") {
                        RackDataPanel(rackModel: rackDataModel)
                    }

                    // Attachments for rack parts
                    ForEach(RackParts.all) { part in
                        Attachment(id: part.id) {
                            CalloutBubble(title: part.title, detail: part.detail)
                                .frame(minWidth: 200)
                                .padding(4)
                        }
                    }
                }
            }
            .gesture(
                DragGesture()
                    .targetedToAnyEntity()
                    .onChanged { v in
                        guard let rack = rackEntity else { return }
                        if isPlaced {
                            if initialPosition == nil { initialPosition = rack.position }
                            let move = v.convert(v.translation3D, from: .global, to: .scene)
                            rack.position = (initialPosition ?? .zero) + move.grounded
                        } else {
                            let move = v.convert(v.translation3D, from: .global, to: .scene)
                            rack.position = placementPosition + move.grounded
                        }
                    }
                    .onEnded { v in
                        if isPlaced {
                            initialPosition = nil
                        } else {
                            let move = v.convert(v.translation3D, from: .global, to: .scene)
                            placementPosition = placementPosition + move.grounded
                        }
                    }
            )
            .simultaneousGesture(
                isPlaced ? MagnifyGesture()
                    .targetedToAnyEntity()
                    .onChanged { v in
                        guard let rack = rackEntity else { return }
                        if initialScale == nil { initialScale = rack.scale }
                        rack.scale = (initialScale ?? .one) * Float(v.gestureValue.magnification)
                    }
                    .onEnded { _ in initialScale = nil } : nil
            )

            // MARK: - UI Overlay
            GeometryReader { geometry in
                ZStack {

                // Loading indicator
                if isLoading {
                    VStack(spacing: 20) {
                        ProgressView()
                            .scaleEffect(2.0)
                            .progressViewStyle(.circular)
                            .tint(.white)

                        Text("Loading Rack Model...")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)

                        Text("This may take a moment (272MB)")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .padding(40)
                    .frame(width: 400)
                    .background(.black.opacity(0.7))
                    .clipShape(RoundedRectangle(cornerRadius: 24))
                    .position(
                        x: geometry.size.width / 2,
                        y: geometry.size.height / 2
                    )
                }
                // Error message
                else if let error = loadingError {
                    VStack(spacing: 20) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(.orange)

                        Text("Failed to Load Model")
                            .font(.title2)
                            .fontWeight(.bold)

                        Text(error)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .padding(40)
                    .frame(width: 450)
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 24))
                    .position(
                        x: geometry.size.width / 2,
                        y: geometry.size.height / 2
                    )
                }
                // Placement mode - Clean UI
                else if !isPlaced {
                    VStack(spacing: 16) {
                        Image(systemName: "hand.point.up.left.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.blue)
                            .symbolEffect(.pulse)

                        Text("Position the Rack")
                            .font(.title2)
                            .fontWeight(.bold)

                        Text("Drag to move around")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Button(action: {
                            withAnimation(.spring()) {
                                isPlaced = true
                                print("✅ Rack placed! isPlaced = true")
                            }
                        }) {
                            HStack(spacing: 10) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.title2)
                                Text("Place Here")
                                    .font(.title3)
                                    .fontWeight(.bold)
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 32)
                            .padding(.vertical, 14)
                            .background(
                                LinearGradient(
                                    colors: [.blue, .cyan],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .clipShape(Capsule())
                            .shadow(color: .blue.opacity(0.5), radius: 10)
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 8)
                    }
                    .padding(24)
                    .background(.ultraThickMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .strokeBorder(.blue.opacity(0.3), lineWidth: 2)
                    )
                    .shadow(color: .black.opacity(0.2), radius: 15)
                    .position(
                        x: 120,
                        y: 120
                    )
                }

                // Controls after placement
                if isPlaced {
                    HStack(spacing: 16) {
                        Button(action: {
                            withAnimation(.spring()) {
                                showCallouts.toggle()
                            }
                        }) {
                            Label(showCallouts ? "Hide Labels" : "Show Labels",
                                  systemImage: showCallouts ? "eye.slash.fill" : "eye.fill")
                                .font(.caption)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(.regularMaterial)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)

                        Button(action: {
                            withAnimation(.spring()) {
                                explodedView.toggle()
                                explosionAmount = explodedView ? 1.0 : 0.0
                            }
                        }) {
                            Label(explodedView ? "Collapse" : "Explode View",
                                  systemImage: explodedView ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                                .font(.caption)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(.regularMaterial)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)

                        Button(action: {
                            withAnimation(.spring()) {
                                isPlaced = false
                                showCallouts = false
                            }
                        }) {
                            Label("Reposition", systemImage: "arrow.counterclockwise")
                                .font(.caption)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(.regularMaterial)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                    .position(x: 300, y: 60)
                }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .zIndex(1000)  // Force UI to be on top of everything
            }
        }
    }
}
