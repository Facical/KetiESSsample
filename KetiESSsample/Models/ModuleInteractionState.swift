// KetiESSsample/Models/ModuleInteractionState.swift

import Foundation
import RealityKit
import simd
import Combine

/// 모듈의 상호작용 상태를 추적하는 모델
struct ModuleState: Identifiable {
    let id: String              // 모듈 ID (예: "Module1_001")
    let entityName: String      // 엔티티 이름
    var originalPosition: SIMD3<Float>  // 원래 위치
    var currentPosition: SIMD3<Float>   // 현재 위치
    var isPulledOut: Bool = false       // 꺼내진 상태
    var isBeingDragged: Bool = false    // 드래그 중 상태

    /// 모듈이 원래 위치에서 얼마나 앞으로 나왔는지 (3D 거리)
    var pullOutDistance: Float {
        return simd_length(currentPosition - originalPosition)
    }
}

/// 모듈 상호작용을 관리하는 Observable 클래스
@MainActor
class ModuleInteractionManager: ObservableObject {
    /// 모든 모듈 상태
    @Published var moduleStates: [String: ModuleState] = [:]

    /// 현재 선택된 모듈 ID (한 번에 하나만)
    @Published var selectedModuleId: String? = nil

    /// 현재 드래그 중인 모듈 ID
    @Published var draggingModuleId: String? = nil

    /// 모듈이 꺼내질 수 있는 최대 거리 (미터)
    var maxPullOutDistance: Float = 0.5

    /// 손 위치 (Hand Tracking용)
    @Published var leftHandPosition: SIMD3<Float>?
    @Published var rightHandPosition: SIMD3<Float>?
    @Published var leftHandPinching: Bool = false
    @Published var rightHandPinching: Bool = false

    /// Rack 모델의 모듈 엔티티 이름 목록 (ModuleMapping에서 가져옴)
    static let moduleEntityNames: [String] = ModuleMapping.allModuleMappings.map { $0.entityName }

    /// 엔티티 이름으로 CSV 모듈 ID 가져오기
    static func csvModuleId(for entityName: String) -> String? {
        return ModuleMapping.csvModuleId(from: entityName)
    }

    /// 엔티티 이름으로 모듈 인덱스(0-based) 가져오기
    static func moduleIndex(for entityName: String) -> Int? {
        return ModuleMapping.moduleIndex(from: entityName)
    }

    /// 모듈 초기화
    func initializeModules(from rackEntity: Entity) {
        print("🔧 [ModuleManager] ====== Initializing modules ======")
        moduleStates.removeAll()

        for name in Self.moduleEntityNames {
            print("🔧 [ModuleManager] Looking for: '\(name)'")
            if let moduleEntity = rackEntity.findEntityRecursive(named: name) {
                // Get world position from transform matrix
                let m = moduleEntity.transformMatrix(relativeTo: nil)
                let worldPos = SIMD3<Float>(m.columns.3.x, m.columns.3.y, m.columns.3.z)
                let state = ModuleState(
                    id: name,
                    entityName: name,
                    originalPosition: worldPos,
                    currentPosition: worldPos,
                    isPulledOut: false,
                    isBeingDragged: false
                )
                moduleStates[name] = state
                print("✅ [ModuleManager] Module initialized: \(name) at \(worldPos)")
                print("   - Has Collision: \(moduleEntity.components[CollisionComponent.self] != nil)")
                print("   - Has InputTarget: \(moduleEntity.components[InputTargetComponent.self] != nil)")
            } else {
                print("⚠️ [ModuleManager] Module not found: '\(name)'")
            }
        }

        print("🔧 [ModuleManager] Total modules initialized: \(moduleStates.count)")
        print("🔧 [ModuleManager] ====================================")
    }

    /// 모듈 선택
    func selectModule(_ moduleId: String) -> Bool {
        // 이미 다른 모듈이 드래그 중이면 선택 불가
        if let dragging = draggingModuleId, dragging != moduleId {
            return false
        }

        selectedModuleId = moduleId
        return true
    }

    /// 모듈 선택 해제
    func deselectModule() {
        selectedModuleId = nil
    }

    /// 모듈 드래그 시작
    func startDragging(_ moduleId: String) -> Bool {
        // 이미 다른 모듈이 드래그 중이면 시작 불가
        if let dragging = draggingModuleId, dragging != moduleId {
            return false
        }

        draggingModuleId = moduleId
        if var state = moduleStates[moduleId] {
            state.isBeingDragged = true
            moduleStates[moduleId] = state
        }
        return true
    }

    /// 모듈 드래그 종료
    func endDragging(_ moduleId: String) {
        if draggingModuleId == moduleId {
            draggingModuleId = nil
        }

        if var state = moduleStates[moduleId] {
            state.isBeingDragged = false
            // 일정 거리 이상 나왔으면 꺼내진 상태로 표시
            if state.pullOutDistance > 0.05 {
                state.isPulledOut = true
            }
            moduleStates[moduleId] = state
        }
    }

    /// 모듈 위치 업데이트 (앞으로만, 최대 거리 제한)
    /// - Parameters:
    ///   - moduleId: 모듈 ID
    ///   - newZOffset: 앞으로 나온 거리 (로컬 Z축 기준)
    ///   - worldForward: 월드 좌표계에서의 forward 방향 (회전 적용됨), nil이면 월드 Z축 사용
    func updateModulePosition(_ moduleId: String, newZOffset: Float, worldForward: SIMD3<Float>? = nil) {
        guard var state = moduleStates[moduleId] else { return }

        // 앞으로만 나올 수 있음 (양수 방향)
        let clampedOffset = min(max(newZOffset, 0), maxPullOutDistance)

        if let forward = worldForward {
            // 회전을 고려한 방향으로 이동
            state.currentPosition = state.originalPosition + forward * clampedOffset
        } else {
            // 기본 월드 Z축 방향
            state.currentPosition = SIMD3<Float>(
                state.originalPosition.x,
                state.originalPosition.y,
                state.originalPosition.z + clampedOffset
            )
        }
        moduleStates[moduleId] = state
    }

    /// 모듈을 원래 위치로 복귀
    func returnModuleToOriginal(_ moduleId: String) {
        guard var state = moduleStates[moduleId] else { return }

        state.currentPosition = state.originalPosition
        state.isPulledOut = false
        state.isBeingDragged = false
        moduleStates[moduleId] = state

        if selectedModuleId == moduleId {
            selectedModuleId = nil
        }
    }

    /// 모든 모듈을 원래 위치로 복귀
    func returnAllModulesToOriginal() {
        for moduleId in moduleStates.keys {
            returnModuleToOriginal(moduleId)
        }
        draggingModuleId = nil
    }

    /// 모듈의 원래 위치를 현재 엔티티 위치로 재초기화 (모델 이동/회전 후 사용)
    func reinitializeModulePositions(from rackEntity: Entity) {
        print("🔧 [ModuleManager] ====== Reinitializing module positions ======")

        for name in Self.moduleEntityNames {
            if let moduleEntity = rackEntity.findEntityRecursive(named: name) {
                // Get world position from transform matrix
                let m = moduleEntity.transformMatrix(relativeTo: nil)
                let worldPos = SIMD3<Float>(m.columns.3.x, m.columns.3.y, m.columns.3.z)

                if var state = moduleStates[name] {
                    state.originalPosition = worldPos
                    state.currentPosition = worldPos
                    state.isPulledOut = false
                    state.isBeingDragged = false
                    moduleStates[name] = state
                    print("✅ [ModuleManager] Module reinitialized: \(name) at \(worldPos)")
                }
            }
        }

        print("🔧 [ModuleManager] ====================================")
    }

    /// 꺼내진 모듈 목록
    var pulledOutModules: [ModuleState] {
        return moduleStates.values.filter { $0.isPulledOut }
    }

    /// 특정 위치에서 가장 가까운 모듈 찾기
    func findNearestModule(to position: SIMD3<Float>, maxDistance: Float = 0.15) -> String? {
        var nearestId: String?
        var nearestDistance: Float = maxDistance

        for (id, state) in moduleStates {
            let distance = simd_length(state.currentPosition - position)
            if distance < nearestDistance {
                nearestDistance = distance
                nearestId = id
            }
        }

        return nearestId
    }
}

// Note: worldPosition extension is defined in RackView.swift
