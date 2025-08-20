import SwiftUI
import RealityKit
import simd

// ===== 말풍선 목표 폭(미터) =====
private let targetCalloutWidth: Float = 0.35

// ===== 디버그: 엔티티 이름 덤프 =====
func dumpTurbineEntityNames(_ entity: Entity, indent: String = "") {
    print("\(indent)ENTITY:", entity.name)
    for child in entity.children { dumpTurbineEntityNames(child, indent: indent + "  ") }
}

// ===== 유틸: 말풍선 폭 맞추기 =====
@inline(__always)
func fitTurbineAttachmentWidth(_ e: Entity, targetWidth: Float) {
    let vb = e.visualBounds(relativeTo: nil)
    let current = max(0.0001, vb.extents.x * 2)
    let s = targetWidth / current
    e.setScale(e.scale * SIMD3<Float>(repeating: s), relativeTo: e.parent)
}

struct TurbineView: View {
    @State var initialPosition: SIMD3<Float>? = nil
    @State var initialScale: SIMD3<Float>? = nil

    @State private var turbineEntity: Entity?
    @State private var showCallouts: Bool = true
    @State private var didDumpNames = false
    @State private var updateSub: EventSubscription?

    // ===== 제스처: 항상 루트(turbineEntity)만 조작 =====
    var translationGesture: some Gesture {
        DragGesture()
            .targetedToAnyEntity()
            .onChanged { v in
                guard let turbine = turbineEntity else { return }
                if initialPosition == nil { initialPosition = turbine.position }
                let move = v.convert(v.translation3D, from: .global, to: .scene)
                turbine.position = (initialPosition ?? .zero) + move.grounded
            }
            .onEnded { _ in initialPosition = nil }
    }

    var scaleGesture: some Gesture {
        MagnifyGesture()
            .targetedToAnyEntity()
            .onChanged { v in
                guard let turbine = turbineEntity else { return }
                if initialScale == nil { initialScale = turbine.scale }
                turbine.scale = (initialScale ?? .one) * Float(v.gestureValue.magnification)
            }
            .onEnded { _ in initialScale = nil }
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            RealityView { content, attachments in
                let fileName = "Turbine__Turbofan_Engine__Jet_Engine"

                // 1) 모델 1회 로드
                if turbineEntity == nil {
                    guard let turbine = try? await Entity(named: fileName) else {
                        assertionFailure("Failed to load model: \(fileName)")
                        return
                    }

                    // 계층 전체 충돌/입력 활성화
                    turbine.generateCollisionShapes(recursive: true)
                    turbine.forEachDescendant { entity in
                        var inputTarget = InputTargetComponent()
                        inputTarget.allowedInputTypes = .indirect
                        entity.components.set(inputTarget)
                    }

                    // 배치 - 터빈 모델에 맞게 조정
                    let bounds = turbine.visualBounds(relativeTo: nil)
                    turbine.position = SIMD3<Float>(-bounds.center.x, -bounds.min.y, -bounds.center.z - 2.0)
                    turbine.scale *= 0.8 // 터빈은 크기를 더 작게

                    // 루트에 큰 충돌박스
                    let size = bounds.extents
                    let boxShape = ShapeResource.generateBox(size: size)
                    turbine.components.set(CollisionComponent(shapes: [boxShape]))

                    content.add(turbine)
                    turbineEntity = turbine
                    print("✅ Turbine loaded and added to scene:", fileName)
                }

                guard let turbine = turbineEntity else { return }

                // 2) 엔티티 이름 덤프(1회)
                if !didDumpNames {
                    print("——— TURBINE ENTITY NAME DUMP START ———")
                    dumpTurbineEntityNames(turbine)
                    print("——— TURBINE ENTITY NAME DUMP END ———")
                    didDumpNames = true
                }

                // 3) 루트 테스트 말풍선
                if #available(visionOS 2.0, *) {
                    if let rootCallout = attachments.entity(for: "root") {
                        if rootCallout.parent == nil { turbine.addChild(rootCallout) }
                        let vbW = turbine.visualBounds(relativeTo: nil)
                        let worldPos = vbW.center + SIMD3<Float>(0, vbW.extents.y * 0.7, 0)
                        rootCallout.setWorldPosition(worldPos)
                        rootCallout.components.set(BillboardComponent())
                        fitTurbineAttachmentWidth(rootCallout, targetWidth: targetCalloutWidth)
                        rootCallout.isEnabled = showCallouts
                        print("✅ Turbine root callout created @", worldPos)
                    }
                }

                // 4) 각 파트 말풍선 + 리더라인 + 프로브
                for part in TurbineParts.all {
                    guard let host = turbine.findEntityRecursive(named: part.entityName) else {
                        print("❌ Cannot find turbine entity:", part.entityName)
                        continue
                    }
                    
                    print("🔍 Found turbine part: \(part.id) (\(part.entityName))")
                    
                    // 부품 위치 계산
                    let worldBounds = host.visualBounds(relativeTo: nil)
                    let hostWorldPos = worldBounds.center
                    
                    // 말풍선 위치
                    let worldTarget = hostWorldPos +
                        SIMD3<Float>(0, worldBounds.extents.y * 0.5 + 0.15, 0) +
                        part.offset
                    
                    // 디버그용 빨간 구
                    let probeName = "Probe:\(part.id)"
                    if turbine.findEntity(named: probeName) == nil {
                        let probe = ModelEntity(
                            mesh: .generateSphere(radius: 0.02),
                            materials: [SimpleMaterial(color: .red, isMetallic: false)]
                        )
                        probe.name = probeName
                        turbine.addChild(probe)
                    }
                    if let probe = turbine.findEntity(named: probeName) {
                        probe.setWorldPosition(worldTarget)
                        probe.isEnabled = showCallouts
                    }
                    
                    // visionOS 2: attachments 말풍선
                    if #available(visionOS 2.0, *), let callout = attachments.entity(for: part.id) {
                        callout.name = "Attachment:\(part.id)"
                        if callout.parent == nil { turbine.addChild(callout) }
                        callout.setWorldPosition(worldTarget)
                        callout.components.set(BillboardComponent())
                        
                        var inputTarget = InputTargetComponent()
                        inputTarget.allowedInputTypes = [.direct, .indirect]
                        callout.components.set(inputTarget)
                        
                        fitTurbineAttachmentWidth(callout, targetWidth: targetCalloutWidth)
                        callout.isEnabled = showCallouts
                    } else {
                        // 폴백: 3D 텍스트
                        let labelName = "FallbackLabel:\(part.id)"
                        if turbine.findEntity(named: labelName) == nil {
                            let mesh = try? MeshResource.generateText(
                                "\(part.title)",
                                extrusionDepth: 0.002,
                                font: .systemFont(ofSize: 0.06),
                                containerFrame: .zero,
                                alignment: .left,
                                lineBreakMode: .byWordWrapping
                            )
                            let textE = ModelEntity(
                                mesh: mesh ?? .generateBox(size: .one * 0.05),
                                materials: [UnlitMaterial(color: .white)]
                            )
                            textE.name = labelName
                            turbine.addChild(textE)
                        }
                        if let textE = turbine.findEntity(named: labelName) {
                            textE.setWorldPosition(worldTarget)
                            fitTurbineAttachmentWidth(textE, targetWidth: targetCalloutWidth)
                            textE.isEnabled = showCallouts
                        }
                    }

                    // 리더라인 생성
                    if turbine.findEntity(named: "Leader:\(part.id)") == nil {
                        let stick = ModelEntity(
                            mesh: .generateBox(size: [0.002, 0.002, 1.0]),
                            materials: [SimpleMaterial(color: .white, isMetallic: false)]
                        )
                        stick.name = "Leader:\(part.id)"
                        turbine.addChild(stick)

                        let tipMesh: MeshResource = (try? .generateCone(height: 0.02, radius: 0.008))
                            ?? .generateSphere(radius: 0.009)
                        let tip = ModelEntity(
                            mesh: tipMesh,
                            materials: [SimpleMaterial(color: .white, isMetallic: false)]
                        )
                        tip.name = "Arrow:\(part.id)"
                        turbine.addChild(tip)
                    }
                }

                // 5) 매 프레임 리더라인 정렬 + 말풍선 크기 재보정
                if updateSub == nil {
                    updateSub = content.subscribe(to: SceneEvents.Update.self) { _ in
                        guard let turbine = turbineEntity else { return }

                        // 말풍선 크기 유지
                        if #available(visionOS 2.0, *) {
                            if let root = turbine.children.first(where: { $0.name == "Attachment:root" }) {
                                fitTurbineAttachmentWidth(root, targetWidth: targetCalloutWidth)
                            }
                            for part in TurbineParts.all {
                                if let callout = turbine.children.first(where: { $0.name == "Attachment:\(part.id)" }) {
                                    fitTurbineAttachmentWidth(callout, targetWidth: targetCalloutWidth)
                                }
                                if let fallback = turbine.findEntity(named: "FallbackLabel:\(part.id)") {
                                    fitTurbineAttachmentWidth(fallback, targetWidth: targetCalloutWidth)
                                }
                            }
                        }

                        // 리더라인 정렬
                        for part in TurbineParts.all {
                            guard let host = turbine.findEntityRecursive(named: part.entityName) else { continue }
                            
                            let worldBounds = host.visualBounds(relativeTo: nil)
                            let A = worldBounds.center

                            var b: SIMD3<Float>?
                            if #available(visionOS 2.0, *) {
                                if let callout = turbine.children.first(where: { $0.name == "Attachment:\(part.id)" }) {
                                    b = callout.worldPosition
                                }
                            }
                            if b == nil, let fallback = turbine.findEntity(named: "FallbackLabel:\(part.id)") {
                                b = fallback.worldPosition
                            }
                            guard let B = b else { continue }

                            guard
                                let stick = turbine.findEntity(named: "Leader:\(part.id)") as? ModelEntity,
                                let tip   = turbine.findEntity(named: "Arrow:\(part.id)") as? ModelEntity
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
            } attachments: {
                // 파트별 말풍선
                ForEach(TurbineParts.all) { part in
                    Attachment(id: part.id) {
                        CalloutBubble(title: part.title, detail: part.detail)
                            .frame(minWidth: 200)
                            .padding(4)
                    }
                }
            }
            .gesture(translationGesture)
            .simultaneousGesture(scaleGesture)
        }
    }
}
