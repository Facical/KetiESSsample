import SwiftUI
import RealityKit
import RealityKitContent
import simd
import ARKit

private let targetCalloutWidth: Float = 0.35

// MARK: - Entity Extensions
extension Entity {
    func forEachDescendant(_ body: (Entity) -> Void) {
        body(self)
        for c in children { c.forEachDescendant(body) }
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

// MARK: - Rack View
struct RackView: View {
    // Environment for dismissing immersive space and opening window
    @Environment(\.dismissImmersiveSpace) var dismissImmersiveSpace
    @Environment(\.openWindow) var openWindow

    // Placement state
    @State private var isPlaced = false
    @State private var placementPosition: SIMD3<Float> = [0, 0, -2.0]

    // Entity state
    @State private var rackEntity: Entity?
    @State private var showCallouts: Bool = false
    @State private var showProblemAnalysis: Bool = false  // 문제 분석 모드
    @State private var updateSub: EventSubscription?

    // Interaction state (배치 전 전용)
    @State private var initialPosition: SIMD3<Float>?
    @State private var initialScale: SIMD3<Float>?
    @State private var explodedView: Bool = false
    @State private var explosionAmount: Float = 0.0

    // Loading state
    @State private var loadingError: String? = nil

    // Data model
    @StateObject private var rackDataModel = RackSystemModel()

    // Module interaction
    @StateObject private var moduleManager = ModuleInteractionManager()
    @State private var moduleEntities: [String: Entity] = [:]
    @State private var moduleSetupComplete = false  // 모듈 설정 완료 플래그

    // Hand Tracking
    @State private var handTrackingSession: ARKitSession?
    @State private var handTracking: HandTrackingProvider?
    @State private var leftHandAnchor: HandAnchor?
    @State private var rightHandAnchor: HandAnchor?

    // Two-hand rotation gesture state (두 손 핀치 회전)
    @State private var isTwoHandPinching: Bool = false
    @State private var initialRotationAngle: Float? = nil
    @State private var initialModelRotation: simd_quatf? = nil
    @State private var lastTwoHandAngle: Float? = nil

    // Object Tracking
    @State private var objectTrackingSession: ARKitSession?
    @State private var objectTracking: ObjectTrackingProvider?
    @State private var isObjectTracking: Bool = false
    @State private var detectedObjectAnchor: ObjectAnchor?

    // 드래그 관련 상태 (fallback)
    @State private var moduleInitialPosition: SIMD3<Float>?
    @State private var draggedModuleId: String?

    // Hand tracking 드래그 상태 (안정화용)
    @State private var handDragStartPosition: SIMD3<Float>?  // 핀치 시작 시 손 위치
    @State private var handDragStartModuleOffset: Float = 0  // 핀치 시작 시 모듈의 현재 offset
    @State private var lastSmoothedOffset: Float = 0         // 마지막 smoothed offset (lerp용)

    // 원래 Material 저장 (문제 분석 모드 토글 시 복원용)
    @State private var originalMaterials: [String: [[RealityKit.Material]]] = [:]
    @State private var colorAppliedModules: Set<String> = []  // 색상이 적용된 모듈 추적
    @State private var lastAnalysisState: Bool = false  // 이전 분석 모드 상태 추적

    // Cell Material 저장 (꺼낸 모듈의 셀 색상 복원용)
    @State private var originalCellMaterials: [String: [String: [RealityKit.Material]]] = [:]  // [moduleId: [cellEntityName: materials]]
    @State private var cellColorAppliedModules: Set<String> = []  // 셀 색상이 적용된 모듈 추적

    // 데이터 패널에서 선택된 모듈 (하이라이트 및 연결선용)
    @State private var dataPanelSelectedTab: Int = 0  // 0: Rack, 1: Module, 2: Cell
    @State private var dataPanelSelectedModuleIndex: Int = 0  // 선택된 모듈 인덱스 (0-10)
    // Note: highlightBoxEntity와 leaderLineEntity는 이름으로 찾아서 관리 (State 수정 경고 방지)

    // Control panel position (사용자 앞쪽 왼쪽에 배치)
    private let controlPanelOffset: SIMD3<Float> = [-0.8, 1.2, -1.5]

    // MARK: - Body
    var body: some View {
        ZStack {
            RealityView { content, attachments in
                // Load Rack model
                if rackEntity == nil {
                    do {
                        print("🔄 Loading Rack model...")

                        let rack = try await Entity(named: "Rack", in: realityKitContentBundle)
                        print("✅ Rack model loaded successfully")

                        // DEBUG: Rack 구조 출력
                        printEntityHierarchy(rack, indent: 0)

                        // Position the rack
                        let bounds = rack.visualBounds(relativeTo: nil)
                        rack.position = placementPosition
                        rack.position.y -= bounds.min.y

                        // Add root collision box for initial placement
                        let size = bounds.extents
                        let boxShape = ShapeResource.generateBox(size: size)
                        rack.components.set(CollisionComponent(shapes: [boxShape]))
                        rack.components.set(InputTargetComponent(allowedInputTypes: [.direct, .indirect]))

                        content.add(rack)
                        rackEntity = rack
                        loadingError = nil

                        print("✅ Rack model added to scene")
                    } catch {
                        loadingError = "Error loading model: \(error.localizedDescription)"
                        print("❌ Error loading Rack model: \(error)")
                        return
                    }
                }

                guard let rack = rackEntity else { return }

                // Setup module interactions after placement (async Task로 이동)
                if isPlaced && !moduleSetupComplete {
                    print("🔧 [MAKE] Triggering module setup via Task...")
                    // 플래그를 먼저 설정하여 중복 호출 방지
                    Task { @MainActor in
                        await setupModuleInteractionsAsync(rack: rack)
                    }
                }

                // Setup attachments for parts
                if isPlaced && showCallouts {
                    setupCallouts(rack: rack, attachments: attachments)
                }

                // Update loop - 항상 실행 (배치 전 회전, 배치 후 모듈 인터랙션)
                if updateSub == nil {
                    updateSub = content.subscribe(to: SceneEvents.Update.self) { event in
                        Task { @MainActor in
                            updateHandTracking()  // 배치 전: 두 손 회전, 배치 후: 모듈 인터랙션
                            if isPlaced {
                                updateModulePositions()
                                updateModuleColors(showAnalysis: showProblemAnalysis)
                                updateCellColorsForPulledOutModules()  // 꺼낸 모듈의 셀 색상 업데이트
                                updateLeaderLines(rack: rack)
                            }
                        }
                    }
                }
            } update: { content, attachments in
                // Control Panel - 항상 표시 (사용자 앞쪽 왼쪽에 고정)
                if #available(visionOS 2.0, *) {
                    if let controlPanel = attachments.entity(for: "controlPanel") {
                        if controlPanel.parent == nil {
                            content.add(controlPanel)
                        }
                        // 사용자 앞쪽 왼쪽에 고정 위치 배치
                        controlPanel.setPosition(controlPanelOffset, relativeTo: nil)
                        controlPanel.components.set(BillboardComponent())
                        controlPanel.isEnabled = true
                    }
                }

                guard let rack = rackEntity else { return }

                // 배치 후 모듈 상호작용 설정 (async Task로 이동 - update에서 직접 호출 안함)
                // moduleSetupComplete 플래그로 한번만 설정되도록 함
                if isPlaced && !moduleSetupComplete {
                    print("🔧 [UPDATE] Module setup pending, triggering via Task...")
                    Task { @MainActor in
                        await setupModuleInteractionsAsync(rack: rack)
                    }
                }

                guard isPlaced else { return }

                // 모듈 색상 업데이트는 SceneEvents.Update에서만 처리 (중복 호출 방지)

                // Update data panel position - 랙 오른쪽에 가깝게 배치
                if #available(visionOS 2.0, *) {
                    if let dataPanel = attachments.entity(for: "rackDataPanel") {
                        if dataPanel.parent == nil {
                            content.add(dataPanel)
                        }

                        let rackPos = rack.position(relativeTo: nil)
                        let bounds = rack.visualBounds(relativeTo: nil)

                        // 랙 오른쪽에 더 가깝게 배치 (0.4m 간격)
                        let panelWorldPos = SIMD3<Float>(
                            rackPos.x + bounds.extents.x * 0.5 + 0.9,
                            rackPos.y + bounds.extents.y * 0.6,  // 랙 중앙 높이
                            rackPos.z
                        )

                        dataPanel.setPosition(panelWorldPos, relativeTo: nil)
                        dataPanel.components.set(BillboardComponent())
                        dataPanel.isEnabled = true

                        // Module 탭 선택 시 해당 모듈에 하이라이트 박스 및 연결선 표시
                        updateModuleHighlight(rack: rack, dataPanel: dataPanel, content: content)
                    }

                    // Update module data bubbles
                    for (moduleId, state) in moduleManager.moduleStates {
                        if state.isPulledOut && !state.isBeingDragged {
                            if let bubble = attachments.entity(for: "moduleBubble_\(moduleId)") {
                                if bubble.parent == nil {
                                    content.add(bubble)
                                }

                                // 모든 모듈 데이터 버블을 오른쪽에 표시
                                let bubblePos = SIMD3<Float>(
                                    state.currentPosition.x + 0.55,  // 오른쪽으로
                                    state.currentPosition.y,          // 같은 높이
                                    state.currentPosition.z + 0.1     // 약간 앞으로
                                )

                                bubble.setPosition(bubblePos, relativeTo: nil)
                                bubble.components.set(BillboardComponent())
                                bubble.isEnabled = true
                            }
                        } else {
                            // Hide bubble when not pulled out or being dragged
                            if let bubble = attachments.entity(for: "moduleBubble_\(moduleId)") {
                                bubble.isEnabled = false
                            }
                        }
                    }
                }
            } attachments: {
                // Control Panel Attachment (MainView 역할 대체)
                Attachment(id: "controlPanel") {
                    ControlPanelAttachment(
                        isPlaced: $isPlaced,
                        showCallouts: $showCallouts,
                        showProblemAnalysis: $showProblemAnalysis,
                        isObjectTracking: $isObjectTracking,
                        onPlaceHere: {
                            withAnimation(.spring()) {
                                isPlaced = true
                                // Object Tracking 중지
                                if isObjectTracking {
                                    stopObjectTracking()
                                }
                                // 모듈 위치를 현재 rack 위치/회전 기준으로 재초기화
                                if let rack = rackEntity {
                                    moduleManager.reinitializeModulePositions(from: rack)
                                }
                                print("✅ Rack placed via control panel!")
                            }
                        },
                        onResetModules: {
                            withAnimation(.spring()) {
                                // 셀 색상 복원
                                if let rack = rackEntity {
                                    for moduleId in cellColorAppliedModules {
                                        restoreCellColorsForModule(moduleId: moduleId, rack: rack)
                                    }
                                }
                                cellColorAppliedModules.removeAll()

                                moduleManager.returnAllModulesToOriginal()
                                for (moduleId, entity) in moduleEntities {
                                    if let state = moduleManager.moduleStates[moduleId] {
                                        entity.setWorldPosition(state.originalPosition)
                                    }
                                }
                            }
                        },
                        onReposition: {
                            withAnimation(.spring()) {
                                isPlaced = false
                                showCallouts = false
                                showProblemAnalysis = false
                                moduleSetupComplete = false
                                moduleManager.returnAllModulesToOriginal()
                                moduleEntities.removeAll()
                                // 원래 Material로 복원 (모듈 + 셀)
                                restoreOriginalMaterials()
                                if let rack = rackEntity {
                                    for moduleId in cellColorAppliedModules {
                                        restoreCellColorsForModule(moduleId: moduleId, rack: rack)
                                    }
                                    rack.components.set(InputTargetComponent(allowedInputTypes: [.direct, .indirect]))
                                }
                                cellColorAppliedModules.removeAll()
                                originalCellMaterials.removeAll()
                                print("🔄 [REPOSITION] Reset via control panel")
                            }
                        },
                        onCloseXR: {
                            Task {
                                // Object Tracking 중지
                                stopObjectTracking()
                                await dismissImmersiveSpace()
                                // MainWindow 다시 열기
                                openWindow(id: "MainWindow")
                            }
                        },
                        onToggleObjectTracking: {
                            Task {
                                if isObjectTracking {
                                    stopObjectTracking()
                                } else {
                                    await startObjectTracking()
                                }
                            }
                        },
                        moduleCount: moduleEntities.count,
                        pulledOutCount: moduleManager.pulledOutModules.count,
                        problemModuleCount: countProblemModules()
                    )
                }

                // Data Panel Attachment
                Attachment(id: "rackDataPanel") {
                    RackDataPanel(
                        rackModel: rackDataModel,
                        selectedTab: $dataPanelSelectedTab,
                        selectedModuleIndex: $dataPanelSelectedModuleIndex
                    )
                }

                // Module data bubbles - 개별 생성
                Attachment(id: "moduleBubble_Module1_001") {
                    ModuleDataBubble(moduleId: "Module1_001", moduleData: getModuleData(for: "Module1_001"), onReturnTap: { returnModule("Module1_001") })
                }
                Attachment(id: "moduleBubble_Module2_001") {
                    ModuleDataBubble(moduleId: "Module2_001", moduleData: getModuleData(for: "Module2_001"), onReturnTap: { returnModule("Module2_001") })
                }
                Attachment(id: "moduleBubble_Module3_001") {
                    ModuleDataBubble(moduleId: "Module3_001", moduleData: getModuleData(for: "Module3_001"), onReturnTap: { returnModule("Module3_001") })
                }
                Attachment(id: "moduleBubble_Module4_001") {
                    ModuleDataBubble(moduleId: "Module4_001", moduleData: getModuleData(for: "Module4_001"), onReturnTap: { returnModule("Module4_001") })
                }
                Attachment(id: "moduleBubble_Module5_001") {
                    ModuleDataBubble(moduleId: "Module5_001", moduleData: getModuleData(for: "Module5_001"), onReturnTap: { returnModule("Module5_001") })
                }
                Attachment(id: "moduleBubble_Module6_001") {
                    ModuleDataBubble(moduleId: "Module6_001", moduleData: getModuleData(for: "Module6_001"), onReturnTap: { returnModule("Module6_001") })
                }
                Attachment(id: "moduleBubble_Module7_001") {
                    ModuleDataBubble(moduleId: "Module7_001", moduleData: getModuleData(for: "Module7_001"), onReturnTap: { returnModule("Module7_001") })
                }
                Attachment(id: "moduleBubble_Module8_001") {
                    ModuleDataBubble(moduleId: "Module8_001", moduleData: getModuleData(for: "Module8_001"), onReturnTap: { returnModule("Module8_001") })
                }
                Attachment(id: "moduleBubble_Module9_001") {
                    ModuleDataBubble(moduleId: "Module9_001", moduleData: getModuleData(for: "Module9_001"), onReturnTap: { returnModule("Module9_001") })
                }
                Attachment(id: "moduleBubble_Module10_001") {
                    ModuleDataBubble(moduleId: "Module10_001", moduleData: getModuleData(for: "Module10_001"), onReturnTap: { returnModule("Module10_001") })
                }
                Attachment(id: "moduleBubble_Module11_001") {
                    ModuleDataBubble(moduleId: "Module11_001", moduleData: getModuleData(for: "Module11_001"), onReturnTap: { returnModule("Module11_001") })
                }
            }
            // 배치 전에만 드래그 가능
            .gesture(placementGesture)
            // 배치 후 모듈 탭 (터치 인식 확인)
            .gesture(moduleTapGesture)
            // 배치 후 모듈 드래그 (Hand Tracking fallback)
            .simultaneousGesture(moduleGesture)

            // MARK: - UI Overlay (에러만 표시)
            GeometryReader { geometry in
                ZStack {
                    // Error message
                    if let error = loadingError {
                        errorOverlay(error: error)
                            .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .zIndex(1000)
            }
        }
        .task {
            await startHandTracking()
        }
        .onDisappear {
            stopHandTracking()
            stopObjectTracking()
        }
    }

    // MARK: - Gestures

    /// 배치 전 Rack 이동 제스처
    private var placementGesture: some Gesture {
        DragGesture()
            .targetedToAnyEntity()
            .onChanged { v in
                guard !isPlaced, let rack = rackEntity else { return }
                let move = v.convert(v.translation3D, from: .global, to: .scene)
                rack.position = placementPosition + move.grounded
            }
            .onEnded { v in
                guard !isPlaced else { return }
                let move = v.convert(v.translation3D, from: .global, to: .scene)
                placementPosition = placementPosition + move.grounded
            }
    }

    /// 모듈 탭 제스처 - SpatialTapGesture 사용
    private var moduleTapGesture: some Gesture {
        SpatialTapGesture()
            .targetedToAnyEntity()
            .onEnded { v in
                guard isPlaced, let rack = rackEntity else {
                    print("👆 [TAP] Tap detected but not placed yet or rack nil")
                    return
                }

                // 탭 위치를 scene 좌표로 변환
                let sceneLocation = v.convert(v.location3D, from: .local, to: .scene)
                print("👆 [TAP] Tap at scene location: \(sceneLocation)")

                // 가장 가까운 모듈 찾기
                if let nearestModule = findNearestModuleToPointSIMD(sceneLocation, in: rack) {
                    print("👆 [TAP] Found nearest module: \(nearestModule)")

                    // 모듈 토글 (꺼내기/넣기)
                    if let state = moduleManager.moduleStates[nearestModule] {
                        if state.isPulledOut {
                            returnModule(nearestModule)
                            print("👆 [TAP] Returning module: \(nearestModule)")
                        } else {
                            pullOutModule(nearestModule)
                            print("👆 [TAP] Pulling out module: \(nearestModule)")
                        }
                    }
                } else {
                    print("👆 [TAP] No module found near tap location")
                }
            }
    }

    /// 모듈 드래그 제스처 - 위치 기반으로 가장 가까운 모듈 찾기
    private var moduleGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .targetedToAnyEntity()
            .onChanged { v in
                guard isPlaced, let rack = rackEntity else {
                    return
                }

                // Rack의 회전을 고려한 로컬 forward 방향 계산
                let localForward = SIMD3<Float>(0, 0, 1)
                let worldForward = rack.orientation.act(localForward)

                // 드래그 시작 위치로 모듈 찾기
                if draggedModuleId == nil {
                    // 드래그 시작점을 scene 좌표로 변환 (핵심!)
                    let sceneStartLocation = v.convert(v.startLocation3D, from: .local, to: .scene)
                    print("🖐️ [DRAG] Drag started at scene location: \(sceneStartLocation)")

                    // 가장 가까운 모듈 찾기 (scene 좌표 사용)
                    if let nearestModule = findNearestModuleToPointSIMD(sceneStartLocation, in: rack) {
                        print("🖐️ [DRAG] Found nearest module: \(nearestModule)")

                        if moduleManager.startDragging(nearestModule) {
                            draggedModuleId = nearestModule
                            if let entity = moduleEntities[nearestModule] {
                                // 월드 좌표로 초기 위치 저장
                                let m = entity.transformMatrix(relativeTo: nil)
                                moduleInitialPosition = SIMD3<Float>(m.columns.3.x, m.columns.3.y, m.columns.3.z)
                                print("🖐️ [DRAG] Started dragging \(nearestModule) from world pos: \(moduleInitialPosition ?? .zero)")
                            }
                        }
                    } else {
                        print("🖐️ [DRAG] No module found near drag start location")
                        return
                    }
                }

                // 모듈 위치 업데이트
                guard let moduleId = draggedModuleId,
                      let initialWorldPos = moduleInitialPosition,
                      let entity = moduleEntities[moduleId],
                      let state = moduleManager.moduleStates[moduleId] else {
                    return
                }

                let move = v.convert(v.translation3D, from: .local, to: .scene)

                // 드래그 이동량을 forward 방향에 투영
                let dragMovement = simd_dot(SIMD3<Float>(Float(move.x), Float(move.y), Float(move.z)), worldForward)
                let clampedOffset = min(max(dragMovement, 0), moduleManager.maxPullOutDistance)

                // 원래 위치(originalPosition)에서 forward 방향으로 이동 (월드 좌표)
                let newWorldPos = state.originalPosition + worldForward * clampedOffset
                entity.setPosition(newWorldPos, relativeTo: nil)

                // 상태 업데이트 (worldForward 전달)
                moduleManager.updateModulePosition(moduleId, newZOffset: clampedOffset, worldForward: worldForward)

                print("🖐️ [DRAG] Moving \(moduleId): offset = \(clampedOffset)m")
            }
            .onEnded { _ in
                guard let moduleId = draggedModuleId,
                      let entity = moduleEntities[moduleId] else { return }

                // 드래그 종료 시 현재 엔티티 위치를 상태에 동기화
                let m = entity.transformMatrix(relativeTo: nil)
                let currentWorldPos = SIMD3<Float>(m.columns.3.x, m.columns.3.y, m.columns.3.z)

                if var state = moduleManager.moduleStates[moduleId] {
                    state.currentPosition = currentWorldPos
                    moduleManager.moduleStates[moduleId] = state
                }

                print("🖐️ [DRAG] Ended dragging \(moduleId) at \(currentWorldPos)")
                moduleManager.endDragging(moduleId)
                draggedModuleId = nil
                moduleInitialPosition = nil
            }
    }

    // MARK: - Hand Tracking

    private func startHandTracking() async {
        #if targetEnvironment(simulator)
        print("⚠️ Hand tracking not available in simulator, using gesture fallback")
        return
        #else
        guard HandTrackingProvider.isSupported else {
            print("⚠️ Hand tracking not supported, using gesture fallback")
            return
        }

        do {
            let session = ARKitSession()
            let handTrackingProvider = HandTrackingProvider()

            try await session.run([handTrackingProvider])
            self.handTrackingSession = session
            self.handTracking = handTrackingProvider

            print("✅ Hand tracking started")

            // Hand anchor updates
            Task {
                for await update in handTrackingProvider.anchorUpdates {
                    await MainActor.run {
                        switch update.anchor.chirality {
                        case .left:
                            leftHandAnchor = update.anchor
                        case .right:
                            rightHandAnchor = update.anchor
                        }
                    }
                }
            }
        } catch {
            print("❌ Failed to start hand tracking: \(error)")
        }
        #endif
    }

    private func stopHandTracking() {
        handTrackingSession = nil
        handTracking = nil
    }

    // MARK: - Object Tracking

    /// Reference Object 로드
    private func loadReferenceObject() async throws -> ReferenceObject {
        // 방법 1: RealityKitContent 번들에서 Reference Object 로드
        if let refObjectURL = Bundle.main.url(
            forResource: "Rack",
            withExtension: "referenceobject",
            subdirectory: "RealityKitContent_RealityKitContent.bundle/RefObject"
        ) {
            print("📦 Loading reference object from main bundle: \(refObjectURL)")
            return try await ReferenceObject(from: refObjectURL)
        }

        // 방법 2: RealityKitContent 번들 직접 접근
        if let bundleURL = Bundle.main.url(forResource: "RealityKitContent_RealityKitContent", withExtension: "bundle"),
           let bundle = Bundle(url: bundleURL),
           let refURL = bundle.url(forResource: "Rack", withExtension: "referenceobject", subdirectory: "RefObject") {
            print("📦 Loading reference object from RealityKitContent bundle: \(refURL)")
            return try await ReferenceObject(from: refURL)
        }

        // 방법 3: realityKitContentBundle 사용
        if let refURL = realityKitContentBundle.url(forResource: "Rack", withExtension: "referenceobject", subdirectory: "RefObject") {
            print("📦 Loading reference object from realityKitContentBundle: \(refURL)")
            return try await ReferenceObject(from: refURL)
        }

        print("❌ Reference object not found in any bundle location")
        throw NSError(domain: "ObjectTracking", code: 1, userInfo: [NSLocalizedDescriptionKey: "Reference object not found"])
    }

    /// Object Tracking 시작
    private func startObjectTracking() async {
        #if targetEnvironment(simulator)
        print("⚠️ Object tracking not available in simulator")
        return
        #else
        guard ObjectTrackingProvider.isSupported else {
            print("⚠️ Object tracking not supported")
            return
        }

        do {
            // Reference Object 로드
            let referenceObject = try await loadReferenceObject()
            print("✅ Reference object loaded: \(referenceObject)")

            // Object Tracking Provider 생성
            let objectTrackingProvider = ObjectTrackingProvider(referenceObjects: [referenceObject])

            // ARKit Session 시작
            let session = ARKitSession()
            try await session.run([objectTrackingProvider])

            await MainActor.run {
                self.objectTrackingSession = session
                self.objectTracking = objectTrackingProvider
                self.isObjectTracking = true
                print("✅ Object tracking started")
            }

            // Object Anchor 업데이트 처리
            Task {
                for await update in objectTrackingProvider.anchorUpdates {
                    await handleObjectAnchorUpdate(update)
                }
            }

        } catch {
            print("❌ Failed to start object tracking: \(error)")
            await MainActor.run {
                self.isObjectTracking = false
            }
        }
        #endif
    }

    /// Object Tracking 중지
    private func stopObjectTracking() {
        objectTrackingSession?.stop()
        objectTrackingSession = nil
        objectTracking = nil
        isObjectTracking = false
        detectedObjectAnchor = nil
        print("🛑 Object tracking stopped")
    }

    /// Object Anchor 업데이트 처리
    @MainActor
    private func handleObjectAnchorUpdate(_ update: AnchorUpdate<ObjectAnchor>) async {
        let anchor = update.anchor

        switch update.event {
        case .added, .updated:
            guard anchor.isTracked else {
                print("📍 Object anchor not tracked")
                return
            }

            detectedObjectAnchor = anchor

            // 감지된 오브젝트 위치로 Rack 모델 이동
            guard let rack = rackEntity, !isPlaced else { return }

            // Object Anchor의 transform에서 위치 추출
            let transform = anchor.originFromAnchorTransform
            let position = SIMD3<Float>(
                transform.columns.3.x,
                transform.columns.3.y,
                transform.columns.3.z
            )

            // Rack 모델 위치 업데이트
            let bounds = rack.visualBounds(relativeTo: nil)
            var adjustedPosition = position
            adjustedPosition.y -= bounds.min.y  // 바닥에 맞춤

            rack.position = adjustedPosition
            placementPosition = adjustedPosition

            // Object의 회전도 적용
            let rotation = simd_quatf(transform)
            rack.orientation = rotation

            print("📍 Object detected! Moving rack to: \(position)")
            print("   - Rotation: \(rotation)")

        case .removed:
            print("📍 Object anchor removed")
            detectedObjectAnchor = nil
        }
    }

    @MainActor
    private func updateHandTracking() {
        #if !targetEnvironment(simulator)
        var leftPinchPosition: SIMD3<Float>? = nil
        var rightPinchPosition: SIMD3<Float>? = nil
        var leftIsPinching = false
        var rightIsPinching = false

        // Left hand
        if let leftAnchor = leftHandAnchor,
           leftAnchor.isTracked,
           let indexTip = leftAnchor.handSkeleton?.joint(.indexFingerTip),
           let thumbTip = leftAnchor.handSkeleton?.joint(.thumbTip) {

            let indexPos = leftAnchor.originFromAnchorTransform * indexTip.anchorFromJointTransform
            let thumbPos = leftAnchor.originFromAnchorTransform * thumbTip.anchorFromJointTransform

            let indexPosition = SIMD3<Float>(indexPos.columns.3.x, indexPos.columns.3.y, indexPos.columns.3.z)
            let thumbPosition = SIMD3<Float>(thumbPos.columns.3.x, thumbPos.columns.3.y, thumbPos.columns.3.z)

            leftPinchPosition = (indexPosition + thumbPosition) / 2
            leftIsPinching = simd_length(indexPosition - thumbPosition) < 0.03

            moduleManager.leftHandPosition = leftPinchPosition
            moduleManager.leftHandPinching = leftIsPinching
        }

        // Right hand
        if let rightAnchor = rightHandAnchor,
           rightAnchor.isTracked,
           let indexTip = rightAnchor.handSkeleton?.joint(.indexFingerTip),
           let thumbTip = rightAnchor.handSkeleton?.joint(.thumbTip) {

            let indexPos = rightAnchor.originFromAnchorTransform * indexTip.anchorFromJointTransform
            let thumbPos = rightAnchor.originFromAnchorTransform * thumbTip.anchorFromJointTransform

            let indexPosition = SIMD3<Float>(indexPos.columns.3.x, indexPos.columns.3.y, indexPos.columns.3.z)
            let thumbPosition = SIMD3<Float>(thumbPos.columns.3.x, thumbPos.columns.3.y, thumbPos.columns.3.z)

            rightPinchPosition = (indexPosition + thumbPosition) / 2
            rightIsPinching = simd_length(indexPosition - thumbPosition) < 0.03

            moduleManager.rightHandPosition = rightPinchPosition
            moduleManager.rightHandPinching = rightIsPinching
        }

        // Two-hand rotation gesture (두 손 핀치 회전)
        if let leftPos = leftPinchPosition,
           let rightPos = rightPinchPosition,
           leftIsPinching && rightIsPinching,
           !isPlaced,
           let rack = rackEntity {

            // 두 손의 XZ 평면에서의 각도 계산
            let deltaX = rightPos.x - leftPos.x
            let deltaZ = rightPos.z - leftPos.z
            let currentAngle = atan2(deltaZ, deltaX)

            if !isTwoHandPinching {
                // 두 손 핀치 시작
                isTwoHandPinching = true
                initialRotationAngle = currentAngle
                initialModelRotation = rack.orientation
                lastTwoHandAngle = currentAngle
                print("🔄 Two-hand rotation started")
            } else if let initialAngle = initialRotationAngle,
                      let initialRotation = initialModelRotation {
                // 회전 중 - 각도 변화 적용
                let angleDelta = currentAngle - initialAngle

                // Y축 기준으로 회전
                let rotationQuat = simd_quatf(angle: -angleDelta, axis: SIMD3<Float>(0, 1, 0))
                rack.orientation = rotationQuat * initialRotation
            }
        } else {
            // 두 손 핀치 해제
            if isTwoHandPinching {
                isTwoHandPinching = false
                initialRotationAngle = nil
                initialModelRotation = nil
                lastTwoHandAngle = nil
                print("🔄 Two-hand rotation ended")
            }

            // 단일 손 인터랙션 처리 (두 손 회전 중이 아닐 때만)
            if let leftPos = leftPinchPosition {
                handleHandInteraction(handPosition: leftPos, isPinching: leftIsPinching, isLeft: true)
            }
            if let rightPos = rightPinchPosition {
                handleHandInteraction(handPosition: rightPos, isPinching: rightIsPinching, isLeft: false)
            }
        }
        #endif
    }

    @MainActor
    private func handleHandInteraction(handPosition: SIMD3<Float>, isPinching: Bool, isLeft: Bool) {
        guard isPlaced else { return }

        if isPinching {
            // 핀치 시작 - 가장 가까운 모듈 찾기
            if moduleManager.draggingModuleId == nil {
                // Y축 보정: 핀치 시 손이 위로 올라가는 것을 보정
                let adjustedHandPosition = SIMD3<Float>(
                    handPosition.x,
                    handPosition.y - 0.08,  // 8cm 아래로 보정
                    handPosition.z
                )
                if let nearestModuleId = moduleManager.findNearestModule(to: adjustedHandPosition) {
                    if moduleManager.startDragging(nearestModuleId) {
                        // 드래그 시작 시 손 위치와 현재 모듈 offset 저장
                        handDragStartPosition = handPosition
                        if let state = moduleManager.moduleStates[nearestModuleId] {
                            // 현재 모듈이 이미 나와있는 거리
                            handDragStartModuleOffset = simd_length(state.currentPosition - state.originalPosition)
                            lastSmoothedOffset = handDragStartModuleOffset
                        } else {
                            handDragStartModuleOffset = 0
                            lastSmoothedOffset = 0
                        }
                        print("✋ Started dragging \(nearestModuleId) with \(isLeft ? "left" : "right") hand")
                    }
                }
            }

            // 드래그 중 - 모듈 위치 업데이트
            if let moduleId = moduleManager.draggingModuleId,
               let entity = moduleEntities[moduleId],
               let state = moduleManager.moduleStates[moduleId],
               let rack = rackEntity,
               let startHandPos = handDragStartPosition {

                // Rack의 회전을 고려한 로컬 forward 방향 계산
                let localForward = SIMD3<Float>(0, 0, 1)
                let worldForward = rack.orientation.act(localForward)

                // 핀치 시작 위치 기준으로 손 이동량 계산 (상대 이동)
                let handDelta = handPosition - startHandPos

                // 손 이동량을 forward 방향에 투영
                let handMovement = simd_dot(handDelta, worldForward)

                // 시작 offset + 손 이동량 = 목표 offset
                let targetOffset = handDragStartModuleOffset + handMovement
                let clampedTarget = min(max(targetOffset, 0), moduleManager.maxPullOutDistance)

                // Smoothing (lerp) - 급격한 변화 완화 (값이 클수록 즉각 반응)
                let smoothFactor: Float = 0.7  // 0.0 ~ 1.0 (높을수록 빠른 반응)
                let smoothedOffset = lastSmoothedOffset + (clampedTarget - lastSmoothedOffset) * smoothFactor
                lastSmoothedOffset = smoothedOffset

                // Dead zone - 아주 작은 변화 무시 (떨림 방지)
                let deadZone: Float = 0.002  // 2mm (더 민감하게)
                let currentOffset = simd_length(state.currentPosition - state.originalPosition)
                if abs(smoothedOffset - currentOffset) < deadZone {
                    return  // 변화가 너무 작으면 업데이트 안 함
                }

                // 원래 위치에서 월드 forward 방향으로 이동
                let newPos = state.originalPosition + worldForward * smoothedOffset

                entity.setPosition(newPos, relativeTo: nil)
                moduleManager.updateModulePosition(moduleId, newZOffset: smoothedOffset, worldForward: worldForward)
            }
        } else {
            // 핀치 해제
            if let moduleId = moduleManager.draggingModuleId,
               let entity = moduleEntities[moduleId] {
                // 핀치 해제 시 현재 엔티티 위치를 상태에 동기화
                let m = entity.transformMatrix(relativeTo: nil)
                let currentWorldPos = SIMD3<Float>(m.columns.3.x, m.columns.3.y, m.columns.3.z)

                if var state = moduleManager.moduleStates[moduleId] {
                    state.currentPosition = currentWorldPos
                    moduleManager.moduleStates[moduleId] = state
                }

                moduleManager.endDragging(moduleId)
                // 드래그 상태 초기화
                handDragStartPosition = nil
                handDragStartModuleOffset = 0
                lastSmoothedOffset = 0
                print("✋ Stopped dragging \(moduleId) at \(currentWorldPos)")
            }
        }
    }

    // MARK: - Module Setup

    /// Async 버전의 모듈 설정 - @State 수정 문제를 피하기 위해 Task에서 호출
    @MainActor
    private func setupModuleInteractionsAsync(rack: Entity) async {
        // 이미 설정 완료되었으면 스킵
        guard !moduleSetupComplete else {
            print("🔧 [ASYNC] Module setup already complete, skipping...")
            return
        }

        // 플래그를 먼저 설정하여 중복 호출 방지
        moduleSetupComplete = true

        print("🔧 ====== Setting up module interactions (ASYNC) ======")
        print("🔧 Looking for modules in rack: '\(rack.name)'")

        // 먼저 rack의 모든 자식 엔티티 이름 출력 (디버그용)
        print("🔧 Rack children:")
        for child in rack.children {
            print("   - '\(child.name)'")
        }

        var foundModules: [String] = []
        var newModuleEntities: [String: Entity] = [:]

        for moduleName in ModuleInteractionManager.moduleEntityNames {
            print("🔧 Searching for module: '\(moduleName)'")

            if let moduleEntity = rack.findEntityRecursive(named: moduleName) {
                print("✅ Found module entity: '\(moduleName)'")

                // 모듈에 개별 충돌 및 입력 컴포넌트 추가
                let bounds = moduleEntity.visualBounds(relativeTo: moduleEntity)
                var size = bounds.extents

                // USDZ 모델이 mm 단위인 경우 meters로 변환
                // bounds가 100mm 이상이면 mm 단위로 간주
                if size.x > 0.1 || size.y > 0.1 || size.z > 0.1 {
                    // 단위가 이미 meters인지 확인 (일반적으로 모듈은 0.5m 이하)
                    if size.x > 1.0 || size.y > 1.0 || size.z > 1.0 {
                        // mm 단위로 간주하여 변환
                        print("   - Bounds in mm: \(size), converting to meters...")
                        size = size / 1000.0
                        print("   - Bounds in meters: \(size)")
                    }
                }

                print("   - Final bounds size: \(size)")
                print("   - Bounds center (raw): \(bounds.center)")

                if size.x > 0 && size.y > 0 && size.z > 0 {
                    // ⭐️ 월드 좌표 기준 bounding box로 collision 생성
                    // relativeTo: nil로 월드 좌표 기준 bounds 획득
                    let worldBounds = moduleEntity.visualBounds(relativeTo: nil)

                    // 모듈의 월드 위치
                    let moduleWorldPos = moduleEntity.position(relativeTo: nil)

                    // collision box를 모듈의 로컬 좌표계로 변환
                    // bounds center는 월드 좌표, 모듈 위치도 월드 좌표
                    // 로컬 offset = 월드 center - 모듈 월드 위치
                    let localOffset = worldBounds.center - moduleWorldPos

                    print("   - World bounds center: \(worldBounds.center)")
                    print("   - Module world position: \(moduleWorldPos)")
                    print("   - Local offset for collision: \(localOffset)")

                    // 적절한 크기의 collision box 생성 (mm→m 변환된 size 사용)
                    let boxShape = ShapeResource.generateBox(size: size)
                        .offsetBy(translation: localOffset)

                    moduleEntity.components.set(CollisionComponent(shapes: [boxShape]))
                    moduleEntity.components.set(InputTargetComponent(allowedInputTypes: [.direct, .indirect]))

                    print("   - Collision box created with size: \(size), offset: \(localOffset)")

                    newModuleEntities[moduleName] = moduleEntity
                    foundModules.append(moduleName)
                    print("✅ Module setup complete: \(moduleName)")
                    print("   - CollisionComponent added: \(moduleEntity.components[CollisionComponent.self] != nil)")
                    print("   - InputTargetComponent added: \(moduleEntity.components[InputTargetComponent.self] != nil)")
                } else {
                    print("⚠️ Module \(moduleName) has zero size bounds, trying ModelEntity children...")

                    // ModelEntity 자식 찾기
                    if let modelChild = findFirstModelEntity(in: moduleEntity) {
                        let modelBounds = modelChild.visualBounds(relativeTo: modelChild)
                        var modelSize = modelBounds.extents

                        // mm → meters 변환
                        if modelSize.x > 1.0 || modelSize.y > 1.0 || modelSize.z > 1.0 {
                            modelSize = modelSize / 1000.0
                        }

                        print("   - Found ModelEntity child with size: \(modelSize)")

                        if modelSize.x > 0 && modelSize.y > 0 && modelSize.z > 0 {
                            let boxShape = ShapeResource.generateBox(size: modelSize)
                            moduleEntity.components.set(CollisionComponent(shapes: [boxShape]))
                            moduleEntity.components.set(InputTargetComponent(allowedInputTypes: [.direct, .indirect]))

                            newModuleEntities[moduleName] = moduleEntity
                            foundModules.append(moduleName)
                            print("✅ Module setup (via child): \(moduleName)")
                        }
                    }
                }
            } else {
                print("⚠️ Module not found: '\(moduleName)'")
            }
        }

        // @State 업데이트 (async context에서 안전하게)
        self.moduleEntities = newModuleEntities

        print("🔧 ====== Module setup summary ======")
        print("🔧 Found \(foundModules.count) modules: \(foundModules)")
        print("🔧 moduleEntities count: \(moduleEntities.count)")

        // 만약 모듈을 못 찾았으면, 이름에 "Module" 포함된 모든 엔티티 찾기
        if foundModules.isEmpty {
            print("⚠️ No modules found! Searching for any entity containing 'Module'...")
            findAllModuleLikeEntities(in: rack)
        }

        // ModuleManager 초기화
        moduleManager.initializeModules(from: rack)

        // ⭐️ 새로운 접근법: Rack 전체에 collision 생성 (recursive)
        // 그리고 gesture handler에서 hit된 엔티티의 부모 계층을 탐색하여 모듈 찾기
        print("🔧 ⭐️ Generating collision shapes for entire rack (recursive)...")
        rack.generateCollisionShapes(recursive: true)

        // Rack 전체에 InputTarget 추가
        rack.components.set(InputTargetComponent(allowedInputTypes: [.direct, .indirect]))

        // 모든 자식에도 InputTarget 추가
        addInputTargetRecursive(rack)

        print("🔧 ⭐️ Added InputTargetComponent to rack and all descendants")
        print("🔧 moduleSetupComplete = true")
        print("🔧 ====================================")
    }

    /// ModelEntity를 재귀적으로 찾기
    private func findFirstModelEntity(in entity: Entity) -> ModelEntity? {
        if let model = entity as? ModelEntity {
            return model
        }
        for child in entity.children {
            if let found = findFirstModelEntity(in: child) {
                return found
            }
        }
        return nil
    }

    /// 모듈의 모든 자손에 InputTargetComponent 추가
    private func addInputTargetToDescendants(_ entity: Entity) {
        for child in entity.children {
            child.components.set(InputTargetComponent(allowedInputTypes: [.direct, .indirect]))
            addInputTargetToDescendants(child)
        }
    }

    /// 엔티티와 모든 자손에 InputTargetComponent 추가 (재귀)
    private func addInputTargetRecursive(_ entity: Entity) {
        entity.components.set(InputTargetComponent(allowedInputTypes: [.direct, .indirect]))
        for child in entity.children {
            addInputTargetRecursive(child)
        }
    }

    /// 모듈이 아닌 엔티티에서 CollisionComponent 제거 (재귀)
    private func removeCollisionFromNonModules(in entity: Entity, moduleNames: Set<String>) {
        // 모듈이 아니면 Collision/Input 제거
        if !moduleNames.contains(entity.name) {
            if entity.components[CollisionComponent.self] != nil {
                entity.components.remove(CollisionComponent.self)
                print("🗑️ Removed Collision from: '\(entity.name)'")
            }
            if entity.components[InputTargetComponent.self] != nil {
                entity.components.remove(InputTargetComponent.self)
                print("🗑️ Removed InputTarget from: '\(entity.name)'")
            }
        } else {
            print("✅ Keeping Collision/Input for module: '\(entity.name)'")
        }

        // 자식들도 처리 (모듈의 자식은 건너뛰기)
        if !moduleNames.contains(entity.name) {
            for child in entity.children {
                removeCollisionFromNonModules(in: child, moduleNames: moduleNames)
            }
        }
    }

    /// "Module"을 포함하는 모든 엔티티 찾기 (디버그용)
    private func findAllModuleLikeEntities(in entity: Entity, depth: Int = 0) {
        let indent = String(repeating: "  ", count: depth)

        if entity.name.lowercased().contains("Module") || entity.name.lowercased().contains("Mod") {
            print("\(indent)🔍 Found module-like entity: '\(entity.name)'")

            // 이 엔티티에 상호작용 컴포넌트 추가 시도
            let bounds = entity.visualBounds(relativeTo: entity)
            if bounds.extents.x > 0 {
                let boxShape = ShapeResource.generateBox(size: bounds.extents)
                entity.components.set(CollisionComponent(shapes: [boxShape]))
                entity.components.set(InputTargetComponent(allowedInputTypes: [.direct, .indirect]))
                moduleEntities[entity.name] = entity
                print("\(indent)   ✅ Added interaction components to '\(entity.name)'")
            }
        }

        for child in entity.children {
            findAllModuleLikeEntities(in: child, depth: depth + 1)
        }
    }

    @MainActor
    private func updateModulePositions() {
        for (moduleId, state) in moduleManager.moduleStates {
            if let entity = moduleEntities[moduleId] {
                // 엔티티 위치를 상태에 맞게 업데이트
                if !state.isBeingDragged {
                    entity.setWorldPosition(state.currentPosition)
                }
            }
        }
    }

    // MARK: - Module Color Update (지표 기반)

    /// 모든 지표를 검사하여 문제가 있는 모듈만 색상 변경 (정상은 원래 Material 유지)
    @MainActor
    private func updateModuleColors(showAnalysis: Bool) {
        // moduleEntities 대신 moduleManager.moduleStates와 rackEntity 사용
        guard let rack = rackEntity, !moduleManager.moduleStates.isEmpty else {
            return
        }

        // 분석 모드가 꺼졌을 때 (ON → OFF 전환 시에만 복원)
        if !showAnalysis {
            if lastAnalysisState {
                // 이전에 켜져있었으면 복원 (비동기로 상태 변경하여 view update 경고 방지)
                DispatchQueue.main.async { [self] in
                    restoreOriginalMaterials()
                    lastAnalysisState = false
                    print("🔄 [ANALYSIS] Mode OFF - materials restored")
                }
            }
            return
        }

        // 분석 모드가 켜짐
        lastAnalysisState = true

        for (moduleName, _) in moduleManager.moduleStates {
            // 엔티티 이름에서 모듈 인덱스 추출
            guard let moduleIndex = ModuleMapping.moduleIndex(from: moduleName) else {
                continue
            }

            // 엔티티 찾기
            guard let entity = rack.findEntityRecursive(named: moduleName) else {
                continue
            }

            // 모듈 데이터 가져오기
            guard moduleIndex < rackDataModel.moduleData.count else {
                continue
            }
            let data = rackDataModel.moduleData[moduleIndex]

            // 모든 지표를 검사하여 최악의 상태 결정
            let overallStatus = getOverallModuleStatus(data: data)

            // 원래 Material 저장 (originalMaterials에 없는 경우에만 - 최초 1회만 저장)
            if originalMaterials[moduleName] == nil {
                saveOriginalMaterials(moduleName: moduleName, entity: entity)
                print("💾 [SAVE] \(moduleName) original materials saved")
            }

            // 상태에 따른 색상 적용 (정상: 초록, 경고: 주황, 위험: 빨강)
            let color = colorForStatus(overallStatus)
            let count = applyColorToEntity(entity, color: color)
            colorAppliedModules.insert(moduleName)

            // 디버그 (Module7, Module8)
            if moduleIndex == 6 || moduleIndex == 7 {
                print("🎨 [COLOR] \(moduleName) → \(overallStatus) → applied to \(count) meshes")
            }
        }
    }

    /// 원래 Material 저장
    private func saveOriginalMaterials(moduleName: String, entity: Entity) {
        var materialsArray: [[RealityKit.Material]] = []

        func collectMaterials(_ e: Entity) {
            if let modelComponent = e.components[ModelComponent.self] {
                materialsArray.append(modelComponent.materials)
            }
            for child in e.children {
                collectMaterials(child)
            }
        }

        collectMaterials(entity)
        originalMaterials[moduleName] = materialsArray
    }

    /// 특정 모듈의 원래 Material 복원
    private func restoreModuleMaterial(moduleName: String, entity: Entity) {
        guard let savedMaterials = originalMaterials[moduleName] else { return }

        var index = 0

        func restoreMaterials(_ e: Entity) {
            if var modelComponent = e.components[ModelComponent.self], index < savedMaterials.count {
                modelComponent.materials = savedMaterials[index]
                e.components[ModelComponent.self] = modelComponent
                index += 1
            }
            for child in e.children {
                restoreMaterials(child)
            }
        }

        restoreMaterials(entity)
        colorAppliedModules.remove(moduleName)
    }

    /// 모든 모듈의 원래 Material 복원
    private func restoreOriginalMaterials() {
        guard let rack = rackEntity else {
            print("❌ [RESTORE] rack is nil")
            return
        }

        print("🔄 [RESTORE] Starting restore - colorAppliedModules: \(colorAppliedModules.count), originalMaterials: \(originalMaterials.count)")

        // originalMaterials에 저장된 모든 모듈 복원
        for (moduleName, savedMaterials) in originalMaterials {
            guard let entity = rack.findEntityRecursive(named: moduleName) else {
                print("❌ [RESTORE] Entity not found: \(moduleName)")
                continue
            }

            var index = 0
            var restoredCount = 0

            func restore(_ e: Entity) {
                if var modelComponent = e.components[ModelComponent.self], index < savedMaterials.count {
                    modelComponent.materials = savedMaterials[index]
                    e.components[ModelComponent.self] = modelComponent
                    index += 1
                    restoredCount += 1
                }
                for child in e.children {
                    restore(child)
                }
            }

            restore(entity)
            print("🔄 [RESTORE] \(moduleName) - restored \(restoredCount) materials")
        }

        colorAppliedModules.removeAll()
        print("🔄 [RESTORE] Complete")
    }

    /// 문제가 있는 모듈 수 계산
    private func countProblemModules() -> Int {
        var count = 0
        for moduleIndex in 0..<rackDataModel.moduleData.count {
            let data = rackDataModel.moduleData[moduleIndex]
            let status = getOverallModuleStatus(data: data)
            if status == .warning || status == .critical {
                count += 1
            }
        }
        return count
    }

    /// 모듈 데이터의 모든 지표를 검사하여 최악의 상태 반환
    private func getOverallModuleStatus(data: ModuleData) -> ModuleHealthStatus {
        var hasCritical = false
        var hasWarning = false

        // 온도 체크 (높을수록 나쁨)
        if data.maxCellTemp > 40 { hasCritical = true }
        else if data.maxCellTemp > 35 { hasWarning = true }

        if data.avgTemp > 40 { hasCritical = true }
        else if data.avgTemp > 35 { hasWarning = true }

        // 전압 체크 (낮을수록 나쁨)
        if data.minCellVoltage < 3.4 { hasCritical = true }
        else if data.minCellVoltage < 3.6 { hasWarning = true }

        // 전류 체크 (낮을수록 나쁨) - 정상 범위: 35A 이상
        if data.avgCurrent < 25 { hasCritical = true }
        else if data.avgCurrent < 35 { hasWarning = true }

        // SOC 체크 (낮을수록 나쁨)
        if data.soc < 50 { hasCritical = true }
        else if data.soc < 65 { hasWarning = true }

        // SOH 체크 (낮을수록 나쁨)
        if data.soh < 60 { hasCritical = true }
        else if data.soh < 80 { hasWarning = true }

        if hasCritical { return .critical }
        if hasWarning { return .warning }
        return .normal
    }

    /// 상태에 따른 UIColor 반환
    private func colorForStatus(_ status: ModuleHealthStatus) -> UIColor {
        switch status {
        case .normal:
            return UIColor(red: 0.2, green: 0.8, blue: 0.3, alpha: 1.0)  // 녹색
        case .warning:
            return UIColor(red: 1.0, green: 0.7, blue: 0.0, alpha: 1.0)  // 주황색
        case .critical:
            return UIColor(red: 1.0, green: 0.2, blue: 0.2, alpha: 1.0)  // 빨간색
        case .unknown:
            return UIColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1.0)  // 회색
        }
    }

    /// 모듈 외형에만 색상 적용 (내부 셀 제외)
    @discardableResult
    private func applyColorToEntity(_ entity: Entity, color: UIColor) -> Int {
        var appliedCount = 0

        // 셀 관련 엔티티는 색상 적용 제외
        let entityNameLower = entity.name.lowercased()
        let isCellEntity = entityNameLower.contains("cell") ||
                           entityNameLower.contains("battery") ||
                           entityNameLower.contains("cylinder") ||
                           entityNameLower.contains("내부") ||
                           entityNameLower.contains("inside")

        // 셀이 아닌 엔티티에만 색상 적용
        if !isCellEntity {
            if var modelComponent = entity.components[ModelComponent.self] {
                // 기존 materials 개수만큼 새 material 생성
                let materialCount = max(modelComponent.materials.count, 1)
                var newMaterials: [RealityKit.Material] = []

                for _ in 0..<materialCount {
                    var material = SimpleMaterial()
                    material.color = .init(tint: color)
                    material.metallic = .float(0.3)
                    material.roughness = .float(0.6)
                    newMaterials.append(material)
                }

                modelComponent.materials = newMaterials
                entity.components[ModelComponent.self] = modelComponent
                appliedCount += 1
            }
        }

        // 자식 엔티티들도 재귀적으로 처리 (셀 내부는 건너뛰기)
        if !isCellEntity {
            for child in entity.children {
                appliedCount += applyColorToEntity(child, color: color)
            }
        }

        return appliedCount
    }

    // MARK: - Cell Color Update (HeatMap 기반)

    /// 꺼낸 모듈의 셀들에 HeatMap 색상 적용
    @MainActor
    private func updateCellColorsForPulledOutModules() {
        guard let rack = rackEntity else { return }

        for (moduleId, state) in moduleManager.moduleStates {
            if state.isPulledOut {
                // 모듈이 꺼내진 상태면 셀 색상 적용
                if !cellColorAppliedModules.contains(moduleId) {
                    applyCellColorsForModule(moduleId: moduleId, rack: rack)
                    cellColorAppliedModules.insert(moduleId)
                }
            } else {
                // 모듈이 다시 들어가면 원래 색상 복원
                if cellColorAppliedModules.contains(moduleId) {
                    restoreCellColorsForModule(moduleId: moduleId, rack: rack)
                    cellColorAppliedModules.remove(moduleId)
                }
            }
        }
    }

    /// 특정 모듈의 셀들에 HeatMap 색상 적용
    private func applyCellColorsForModule(moduleId: String, rack: Entity) {
        guard let moduleIndex = ModuleMapping.moduleIndex(from: moduleId),
              let moduleEntity = rack.findEntityRecursive(named: moduleId) else {
            print("🔥 [CELL COLOR] Module not found: \(moduleId)")
            return
        }

        // 원래 Material 저장 (최초 1회)
        if originalCellMaterials[moduleId] == nil {
            originalCellMaterials[moduleId] = [:]
            saveCellMaterials(moduleId: moduleId, moduleEntity: moduleEntity)
        }

        // 셀 데이터 가져오기
        let cellDataForModule = rackDataModel.currentCellData.filter { $0.moduleNumber - 1 == moduleIndex }
            .sorted { $0.cellNumber < $1.cellNumber }
        print("🔥 [CELL COLOR] Found \(cellDataForModule.count) cell data for module \(moduleId)")

        // 직접 fallback 방식으로 처리 (엔티티 이름 기반 인덱싱이 불가능하므로)
        applyColorsToAllCellEntities(moduleEntity: moduleEntity, moduleIndex: moduleIndex)
    }

    /// 모듈 내부 구조 디버그 출력
    private func printModuleStructure(_ entity: Entity, indent: Int) {
        let indentStr = String(repeating: "  ", count: indent)
        let hasModel = entity.components[ModelComponent.self] != nil
        print("\(indentStr)📦 '\(entity.name)' [Model: \(hasModel)]")

        // 최대 3레벨까지만 출력
        if indent < 3 {
            for child in entity.children {
                printModuleStructure(child, indent: indent + 1)
            }
        } else if !entity.children.isEmpty {
            print("\(indentStr)  ... (\(entity.children.count) more children)")
        }
    }

    /// 셀 인덱스 추출 (엔티티 이름에서)
    private func extractCellIndex(from entityName: String) -> Int? {
        // "Cell_01", "cell01", "C01" 등의 패턴에서 숫자 추출
        let nameLower = entityName.lowercased()

        // "cell" 또는 "c"로 시작하고 숫자가 따라오는 패턴
        if nameLower.contains("cell") || nameLower.hasPrefix("c") {
            let numbers = entityName.filter { $0.isNumber }
            if let num = Int(numbers), num >= 1 && num <= 48 {
                return num - 1  // 0-based index
            }
        }
        return nil
    }

    /// 모든 셀 엔티티에 색상 적용
    private func applyColorsToAllCellEntities(moduleEntity: Entity, moduleIndex: Int) {
        var cellEntities: [Entity] = []

        // 모듈의 모든 자손에서 ModelComponent가 있는 엔티티 수집 (재귀적으로 모든 레벨)
        collectAllModelEntitiesRecursive(from: moduleEntity, into: &cellEntities, skipModuleFrame: true)

        print("🔥 [CELL COLOR] All ModelComponent entities: \(cellEntities.count)")
        for (i, e) in cellEntities.prefix(5).enumerated() {
            print("🔥 [CELL COLOR]   [\(i)] \(e.name)")
        }

        // "cell"이 포함된 엔티티만 필터링 (Module 프레임 제외)
        cellEntities = cellEntities.filter { entity in
            let name = entity.name.lowercased()
            return name.contains("cell")
        }

        print("🔥 [CELL COLOR] Filtered cell entities: \(cellEntities.count)")

        // 셀 데이터 가져오기
        let cellDataForModule = rackDataModel.currentCellData.filter { $0.moduleNumber - 1 == moduleIndex }
            .sorted { $0.cellNumber < $1.cellNumber }

        print("🔥 [CELL COLOR] Cell data count: \(cellDataForModule.count)")

        // 셀 데이터가 없으면 시뮬레이션 데이터 사용
        if cellDataForModule.isEmpty {
            print("🔥 [CELL COLOR] No cell data, applying gradient colors...")
            for (index, entity) in cellEntities.enumerated() {
                let score = Double(index) / Double(max(cellEntities.count - 1, 1))
                let color = heatMapColor(for: score)
                applyColorDirectly(to: entity, color: color)
            }
            print("🔥 [CELL COLOR] Applied gradient colors to \(cellEntities.count) entities")
            return
        }

        // 엔티티와 데이터 매핑 (순서대로)
        var appliedCount = 0
        for (index, entity) in cellEntities.enumerated() {
            let dataIndex = index % cellDataForModule.count
            let cellData = cellDataForModule[dataIndex]
            let color = heatMapColorForCellData(cellData)
            applyColorDirectly(to: entity, color: color)
            appliedCount += 1

            // 디버그: 처음 5개 출력
            if index < 5 {
                let socRange = getSoCRange(cellData.soc)
                print("🔥 [CELL] [\(index)] \(entity.name): soc=\(String(format: "%.1f", cellData.soc))% → \(socRange)")
            }
        }

        print("🔥 [CELL COLOR] ✅ Applied colors to \(appliedCount) cell entities")
    }

    /// 모든 ModelComponent 엔티티 수집 (완전 재귀)
    private func collectAllModelEntitiesRecursive(from entity: Entity, into array: inout [Entity], skipModuleFrame: Bool) {
        // ModelComponent가 있으면 추가 (모듈 프레임 제외)
        if entity.components[ModelComponent.self] != nil {
            let name = entity.name.lowercased()
            let isModuleFrame = name.hasPrefix("module") && !name.contains("cell")
            if !skipModuleFrame || !isModuleFrame {
                array.append(entity)
            }
        }

        // 모든 자식에 대해 재귀 호출
        for child in entity.children {
            collectAllModelEntitiesRecursive(from: child, into: &array, skipModuleFrame: skipModuleFrame)
        }
    }

    /// SoC 범위 문자열 반환 (디버그용)
    private func getSoCRange(_ soc: Double) -> String {
        if soc >= 95 {
            return "청록(95-100%)"
        } else if soc >= 85 {
            return "녹색(85-95%)"
        } else if soc >= 75 {
            return "노랑(75-85%)"
        } else if soc >= 65 {
            return "주황(65-75%)"
        } else {
            return "빨강(<65%)"
        }
    }

    /// 엔티티에 색상 직접 적용
    private func applyColorDirectly(to entity: Entity, color: UIColor) {
        guard var modelComponent = entity.components[ModelComponent.self] else { return }

        var material = SimpleMaterial()
        material.color = .init(tint: color)
        material.metallic = .float(0.2)
        material.roughness = .float(0.7)

        // 모든 materials를 새 색상으로 교체
        let materialCount = max(modelComponent.materials.count, 1)
        modelComponent.materials = Array(repeating: material, count: materialCount)
        entity.components[ModelComponent.self] = modelComponent
    }

    /// Cell SoC 기반 색상 계산 (RackDataPanel의 SoCColorHelper와 동일한 임계값)
    /// - 청록색: 95-100%
    /// - 녹색: 85-95%
    /// - 노란색: 75-85%
    /// - 주황색: 65-75%
    /// - 빨간색: <65%
    private func heatMapColorForCellData(_ cellData: CellData) -> UIColor {
        return colorForSoC(cellData.soc)
    }

    /// SoC 값에 따른 UIColor 반환 (RackDataPanel의 SoCColorHelper와 동일)
    private func colorForSoC(_ soc: Double) -> UIColor {
        if soc >= 95 {
            return UIColor(red: 0.0, green: 0.7, blue: 0.7, alpha: 1.0)   // 청록색
        } else if soc >= 85 {
            return UIColor(red: 0.2, green: 0.7, blue: 0.3, alpha: 1.0)   // 녹색
        } else if soc >= 75 {
            return UIColor(red: 0.9, green: 0.8, blue: 0.2, alpha: 1.0)   // 노란색
        } else if soc >= 65 {
            return UIColor(red: 0.9, green: 0.5, blue: 0.1, alpha: 1.0)   // 주황색
        } else {
            return UIColor(red: 0.8, green: 0.2, blue: 0.2, alpha: 1.0)   // 빨간색
        }
    }

    /// 점수(0~1)를 HeatMap 색상으로 변환 (초록 → 노랑 → 빨강) - 테스트용
    private func heatMapColor(for score: Double) -> UIColor {
        let clampedScore = min(max(score, 0), 1)

        if clampedScore < 0.5 {
            let t = clampedScore * 2
            return UIColor(
                red: CGFloat(t),
                green: CGFloat(0.8),
                blue: CGFloat(0.2 * (1 - t)),
                alpha: 1.0
            )
        } else {
            let t = (clampedScore - 0.5) * 2
            return UIColor(
                red: CGFloat(1.0),
                green: CGFloat(0.8 * (1 - t)),
                blue: CGFloat(0),
                alpha: 1.0
            )
        }
    }

    /// 셀 엔티티에 색상 적용 (재귀적으로 모든 자식에게도 적용)
    private func applyCellColor(to entity: Entity, color: UIColor) {
        // 현재 엔티티에 적용
        if var modelComponent = entity.components[ModelComponent.self] {
            var material = SimpleMaterial()
            material.color = .init(tint: color)
            material.metallic = .float(0.1)
            material.roughness = .float(0.8)

            // 기존 materials 개수만큼 새 material 생성
            let materialCount = max(modelComponent.materials.count, 1)
            var newMaterials: [RealityKit.Material] = []
            for _ in 0..<materialCount {
                newMaterials.append(material)
            }

            modelComponent.materials = newMaterials
            entity.components[ModelComponent.self] = modelComponent
        }

        // 자식 엔티티에도 재귀적으로 적용
        for child in entity.children {
            applyCellColor(to: child, color: color)
        }
    }

    /// 모듈의 원래 셀 Material 저장
    private func saveCellMaterials(moduleId: String, moduleEntity: Entity) {
        moduleEntity.forEachDescendant { entity in
            if let modelComponent = entity.components[ModelComponent.self] {
                if originalCellMaterials[moduleId] == nil {
                    originalCellMaterials[moduleId] = [:]
                }
                originalCellMaterials[moduleId]?[entity.name] = modelComponent.materials
            }
        }
    }

    /// 모듈의 셀 색상 복원
    private func restoreCellColorsForModule(moduleId: String, rack: Entity) {
        guard let moduleEntity = rack.findEntityRecursive(named: moduleId),
              let savedMaterials = originalCellMaterials[moduleId] else {
            return
        }

        moduleEntity.forEachDescendant { entity in
            if var modelComponent = entity.components[ModelComponent.self],
               let materials = savedMaterials[entity.name] {
                modelComponent.materials = materials
                entity.components[ModelComponent.self] = modelComponent
            }
        }

        print("🔄 [CELL COLOR] Restored original colors for \(moduleId)")
    }

    private func setupCallouts(rack: Entity, attachments: RealityViewAttachments) {
        for part in RackParts.all {
            guard let host = rack.findEntityRecursive(named: part.entityName) else {
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

    private func updateLeaderLines(rack: Entity) {
        guard showCallouts else { return }

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
                    b = callout.position(relativeTo: nil)
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
            tip.look(at: B, from: tip.position(relativeTo: nil), relativeTo: nil)
        }
    }

    // MARK: - Helper Functions

    /// 3D 포인트에서 가장 가까운 모듈 찾기 (Point3D 버전)
    private func findNearestModuleToPoint(_ point: Point3D, in rack: Entity) -> String? {
        let pointF = SIMD3<Float>(Float(point.x), Float(point.y), Float(point.z))
        return findNearestModuleToPointSIMD(pointF, in: rack)
    }

    /// 3D 포인트에서 가장 가까운 모듈 찾기 (SIMD3<Float> 버전 - scene 좌표용)
    private func findNearestModuleToPointSIMD(_ point: SIMD3<Float>, in rack: Entity) -> String? {
        print("🔍 [findNearestModule] Looking for module near scene point: \(point)")

        var nearestModule: String? = nil
        var nearestDistance: Float = 0.5  // 최대 탐색 거리 0.5m

        for (moduleName, entity) in moduleEntities {
            let moduleWorldPos = entity.position(relativeTo: nil)
            let distance = simd_length(moduleWorldPos - point)

            print("🔍 [findNearestModule] Module \(moduleName) at \(moduleWorldPos), distance: \(distance)m")

            if distance < nearestDistance {
                nearestDistance = distance
                nearestModule = moduleName
            }
        }

        if let found = nearestModule {
            print("🔍 [findNearestModule] ✅ Nearest module: \(found) at distance \(nearestDistance)m")
        } else {
            print("🔍 [findNearestModule] ❌ No module within 0.5m range")
        }

        return nearestModule
    }

    private func findModuleName(for entity: Entity) -> String? {
        var current: Entity? = entity
        var depth = 0
        print("🔍 [findModuleName] Starting from entity: '\(entity.name)'")

        while let e = current {
            print("🔍 [findModuleName] Checking [\(depth)]: '\(e.name)'")

            // 정확한 이름 매칭
            if ModuleInteractionManager.moduleEntityNames.contains(e.name) {
                print("🔍 [findModuleName] ✅ Found exact match: '\(e.name)'")
                return e.name
            }

            // moduleEntities에 있는지 확인
            if moduleEntities.keys.contains(e.name) {
                print("🔍 [findModuleName] ✅ Found in moduleEntities: '\(e.name)'")
                return e.name
            }

            // "Module" 또는 "Mod"를 포함하는지 확인 (fallback)
            if e.name.lowercased().contains("module") || e.name.contains("Mod") {
                print("🔍 [findModuleName] ✅ Found module-like name: '\(e.name)'")
                return e.name
            }

            current = e.parent
            depth += 1
        }

        print("🔍 [findModuleName] ❌ No module found in hierarchy")
        return nil
    }

    private func getModuleData(for moduleId: String) -> ModuleData? {
        // moduleData가 비어있으면 nil 반환
        guard !rackDataModel.moduleData.isEmpty else {
            return nil
        }

        // 모듈 ID에서 숫자 추출
        if let range = moduleId.range(of: #"\d+"#, options: .regularExpression),
           let num = Int(moduleId[range]) {
            let index = (num - 1) % rackDataModel.moduleData.count
            if index >= 0 && index < rackDataModel.moduleData.count {
                return rackDataModel.moduleData[index]
            }
        }
        return rackDataModel.moduleData.first
    }

    private func returnModule(_ moduleId: String) {
        print("↩️ [RETURN] Returning module: \(moduleId)")
        moduleManager.returnModuleToOriginal(moduleId)
        if let entity = moduleEntities[moduleId],
           let state = moduleManager.moduleStates[moduleId] {
            entity.setWorldPosition(state.originalPosition)
            print("↩️ [RETURN] Module \(moduleId) returned to \(state.originalPosition)")
        }
    }

    /// 모듈을 앞으로 꺼내기 (탭으로 호출)
    private func pullOutModule(_ moduleId: String) {
        print("📤 [PULLOUT] Pulling out module: \(moduleId)")
        guard let entity = moduleEntities[moduleId],
              var state = moduleManager.moduleStates[moduleId],
              let rack = rackEntity else {
            print("📤 [PULLOUT] Failed - entity, state, or rack not found")
            return
        }

        // Rack의 회전을 고려한 로컬 forward 방향 계산
        let localForward = SIMD3<Float>(0, 0, 1)
        let worldForward = rack.orientation.act(localForward)

        // 앞으로 0.3m 이동
        let pullDistance: Float = 0.3
        let newPosition = state.originalPosition + worldForward * pullDistance

        entity.setWorldPosition(newPosition)
        moduleManager.updateModulePosition(moduleId, newZOffset: pullDistance, worldForward: worldForward)

        // 상태 업데이트
        state.isPulledOut = true
        state.currentPosition = newPosition
        moduleManager.moduleStates[moduleId] = state

        print("📤 [PULLOUT] Module \(moduleId) pulled out to \(newPosition)")
    }

    /// 디버그용 - 엔티티 계층 구조 출력
    private func printEntityHierarchy(_ entity: Entity, indent: Int) {
        let indentStr = String(repeating: "  ", count: indent)
        let hasCollision = entity.components[CollisionComponent.self] != nil
        let hasInput = entity.components[InputTargetComponent.self] != nil
        let bounds = entity.visualBounds(relativeTo: entity)

        print("\(indentStr)📦 '\(entity.name)' [Collision:\(hasCollision), Input:\(hasInput), Size:\(bounds.extents)]")

        for child in entity.children {
            printEntityHierarchy(child, indent: indent + 1)
        }
    }

    // MARK: - UI Components

    private func errorOverlay(error: String) -> some View {
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
    }

    // Note: placementOverlay, controlsOverlay, moduleHintOverlay는
    // ControlPanelAttachment로 이동되어 3D 공간에서 표시됨

    // MARK: - Module Highlight (데이터 패널 연동)

    /// 데이터 패널에서 선택된 모듈에 하이라이트 박스 표시
    private func updateModuleHighlight(rack: Entity, dataPanel: Entity, content: RealityViewContent) {
        let highlightBoxName = "ModuleHighlightBox"

        // 기존 하이라이트 엔티티 찾기
        let existingBox = content.entities.first { $0.name == highlightBoxName }

        // Module 탭(1)이 선택된 경우에만 하이라이트 표시
        guard dataPanelSelectedTab == 1 else {
            // 다른 탭이면 하이라이트 제거
            existingBox?.removeFromParent()
            return
        }

        // 선택된 모듈 인덱스로 엔티티 이름 생성 (0-based index → Module1_001 ~ Module11_001)
        let moduleNumber = dataPanelSelectedModuleIndex + 1
        let moduleName = "Module\(moduleNumber)_001"

        // 모듈 엔티티 찾기
        guard let moduleEntity = rack.findEntityRecursive(named: moduleName) else {
            existingBox?.removeFromParent()
            return
        }

        // 모듈 위치 및 바운딩 박스 계산
        let moduleBounds = moduleEntity.visualBounds(relativeTo: nil)
        let moduleCenter = moduleBounds.center
        let moduleSize = moduleBounds.extents

        // 하이라이트 박스 생성/업데이트
        if existingBox == nil {
            let boxEntity = createHighlightBox(size: moduleSize)
            boxEntity.name = highlightBoxName
            content.add(boxEntity)
            boxEntity.setPosition(moduleCenter, relativeTo: nil)
        } else {
            existingBox?.setPosition(moduleCenter, relativeTo: nil)
        }
    }

    /// 빨간색 와이어프레임 하이라이트 박스 생성
    private func createHighlightBox(size: SIMD3<Float>) -> Entity {
        let container = Entity()
        container.name = "HighlightBox"

        // 모듈보다 약간 큰 크기로 (외곽에 표시)
        let padding: Float = 0.015
        let boxSize = size + SIMD3<Float>(repeating: padding * 2)

        // 엣지 두께를 더 두껍게 (잘 보이도록)
        let thickness: Float = 0.015

        // 빨간색 Unlit Material (조명 영향 안 받음 - 항상 밝게 보임)
        var material = UnlitMaterial()
        material.color = .init(tint: .red)

        // 12개의 엣지 생성 (큐브의 모서리)
        // X축 방향 엣지 (4개)
        for y in [-1, 1] as [Float] {
            for z in [-1, 1] as [Float] {
                let edge = ModelEntity(
                    mesh: .generateBox(size: SIMD3<Float>(boxSize.x, thickness, thickness)),
                    materials: [material]
                )
                edge.position = SIMD3<Float>(0, Float(y) * boxSize.y / 2, Float(z) * boxSize.z / 2)
                container.addChild(edge)
            }
        }

        // Y축 방향 엣지 (4개)
        for x in [-1, 1] as [Float] {
            for z in [-1, 1] as [Float] {
                let edge = ModelEntity(
                    mesh: .generateBox(size: SIMD3<Float>(thickness, boxSize.y, thickness)),
                    materials: [material]
                )
                edge.position = SIMD3<Float>(Float(x) * boxSize.x / 2, 0, Float(z) * boxSize.z / 2)
                container.addChild(edge)
            }
        }

        // Z축 방향 엣지 (4개)
        for x in [-1, 1] as [Float] {
            for y in [-1, 1] as [Float] {
                let edge = ModelEntity(
                    mesh: .generateBox(size: SIMD3<Float>(thickness, thickness, boxSize.z)),
                    materials: [material]
                )
                edge.position = SIMD3<Float>(Float(x) * boxSize.x / 2, Float(y) * boxSize.y / 2, 0)
                container.addChild(edge)
            }
        }

        return container
    }

    /// 하이라이트 박스 크기 업데이트
    private func updateHighlightBoxSize(_ box: Entity, size: SIMD3<Float>) {
        // 간단히 전체 박스를 스케일 조정 (정확한 크기 조정이 필요하면 재생성)
        // 여기서는 위치만 업데이트하고 크기는 생성 시 고정
    }

    /// 연결선 생성
    private func createLeaderLine(from start: SIMD3<Float>, to end: SIMD3<Float>) -> Entity {
        let container = Entity()
        container.name = "LeaderLine"

        let direction = end - start
        let length = simd_length(direction)

        // 빨간색 Unlit Material (조명 영향 안 받음 - 항상 밝게 보임)
        var material = UnlitMaterial()
        material.color = .init(tint: .red)

        // 원통형 선 (두께 증가)
        let line = ModelEntity(
            mesh: .generateCylinder(height: length, radius: 0.008),
            materials: [material]
        )

        // 중간 위치에 배치
        let midPoint = (start + end) / 2
        container.setPosition(midPoint, relativeTo: nil)

        // 방향에 맞게 회전
        let defaultUp = SIMD3<Float>(0, 1, 0)
        let normalizedDir = simd_normalize(direction)
        let rotationAxis = simd_cross(defaultUp, normalizedDir)
        let rotationAngle = acos(simd_dot(defaultUp, normalizedDir))

        if simd_length(rotationAxis) > 0.001 {
            container.orientation = simd_quatf(angle: rotationAngle, axis: simd_normalize(rotationAxis))
        }

        container.addChild(line)

        return container
    }

    /// 연결선 업데이트
    private func updateLeaderLine(_ lineEntity: Entity, from start: SIMD3<Float>, to end: SIMD3<Float>) {
        let direction = end - start
        let length = simd_length(direction)

        // 중간 위치로 이동
        let midPoint = (start + end) / 2
        lineEntity.setPosition(midPoint, relativeTo: nil)

        // 방향에 맞게 회전
        let defaultUp = SIMD3<Float>(0, 1, 0)
        let normalizedDir = simd_normalize(direction)
        let rotationAxis = simd_cross(defaultUp, normalizedDir)
        let rotationAngle = acos(simd_clamp(simd_dot(defaultUp, normalizedDir), -1, 1))

        if simd_length(rotationAxis) > 0.001 {
            lineEntity.orientation = simd_quatf(angle: rotationAngle, axis: simd_normalize(rotationAxis))
        }

        // 자식 엔티티(선, 화살표) 크기 업데이트는 복잡하므로 생략
        // 필요시 재생성하는 방식으로 처리
    }
}
