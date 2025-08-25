// KetiESSsample/Views/ESSView.swift

import SwiftUI
import RealityKit
import simd

struct ESSView: View {
    @State private var essEntity: Entity?
    @State private var doorOpen = false
    @State private var showLabels = true
    @State private var selectedModule: Int? = nil
    @StateObject private var systemModel = ESSSystemModel()
    @State private var initialPosition: SIMD3<Float>? = nil
    @State private var initialScale: SIMD3<Float>? = nil
    
    var translationGesture: some Gesture {
        DragGesture()
            .targetedToAnyEntity()
            .onChanged { v in
                guard let ess = essEntity else { return }
                if initialPosition == nil { initialPosition = ess.position }
                let move = v.convert(v.translation3D, from: .global, to: .scene)
                ess.position = (initialPosition ?? .zero) + move.grounded
            }
            .onEnded { _ in initialPosition = nil }
    }
    
    var scaleGesture: some Gesture {
        MagnifyGesture()
            .targetedToAnyEntity()
            .onChanged { v in
                guard let ess = essEntity else { return }
                if initialScale == nil { initialScale = ess.scale }
                ess.scale = (initialScale ?? .one) * Float(v.gestureValue.magnification)
            }
            .onEnded { _ in initialScale = nil }
    }
    
    var body: some View {
        ZStack {
            // 3D View
            RealityView { content, attachments in
                // Create ESS Cabinet Entity
                let cabinet = await createESSCabinet()
                
                // Position cabinet
                cabinet.position = SIMD3<Float>(0, 1, -2)
                cabinet.scale = SIMD3<Float>(repeating: 1.2)
                
                // Add collision for interaction
                cabinet.generateCollisionShapes(recursive: true)
                cabinet.components.set(InputTargetComponent(allowedInputTypes: .indirect))
                
                content.add(cabinet)
                essEntity = cabinet
                
                // Add lighting
                let lightEntity = DirectionalLight()
                lightEntity.light.intensity = 5000
                lightEntity.look(at: [0, 0, 0], from: [2, 2, 2], relativeTo: nil)
                content.add(lightEntity)
                
                // Add additional point light for better illumination
                let pointLight = PointLight()
                pointLight.light.intensity = 10000
                pointLight.light.attenuationRadius = 5
                pointLight.position = SIMD3<Float>(0, 2, 0)
                content.add(pointLight)
                
                // Add attachments for module info
                if #available(visionOS 2.0, *) {
                    for i in 0..<10 {
                        if let attachment = attachments.entity(for: "module_\(i)") {
                            cabinet.addChild(attachment)
                            let row = i / 2
                            let col = i % 2
                            attachment.position = SIMD3<Float>(
                                -0.15 + Float(col) * 0.3,
                                0.8 - Float(row) * 0.35,
                                0.35
                            )
                            attachment.components.set(BillboardComponent())
                            attachment.isEnabled = showLabels
                        }
                    }
                    
                    // System info attachment
                    if let systemInfo = attachments.entity(for: "systemInfo") {
                        cabinet.addChild(systemInfo)
                        systemInfo.position = SIMD3<Float>(0, 1.5, 0)
                        systemInfo.components.set(BillboardComponent())
                    }
                }
                
            } attachments: {
                // Module attachments
                ForEach(0..<10, id: \.self) { index in
                    if index < systemModel.modules.count {
                        Attachment(id: "module_\(index)") {
                            ModuleInfoBubble(module: systemModel.modules[index])
                                .scaleEffect(1.25)
                        }
                    }
                }
                
                // System info attachment
                Attachment(id: "systemInfo") {
                    SystemInfoPanel(systemModel: systemModel)
                }
            }
            .gesture(translationGesture)
            .simultaneousGesture(scaleGesture)
            
            // Control Panel Overlay
            VStack {
                HStack {
                    // Controls
                    VStack(alignment: .leading, spacing: 15) {
                        Text("ESS Cabinet Control")
                            .font(.headline)
                        
                        Toggle("Open Door", isOn: $doorOpen)
                            .onChange(of: doorOpen) { _, newValue in
                                animateDoor(open: newValue)
                            }
                        
                        Toggle("Show Labels", isOn: $showLabels)
                            .onChange(of: showLabels) { _, newValue in
                                updateLabelsVisibility(show: newValue)
                            }
                        
                        Divider()
                        
                        // Quick Stats
                        VStack(alignment: .leading, spacing: 8) {
                            Label(String(format: "%.2f kW", systemModel.totalPower),
                                  systemImage: "bolt.fill")
                            Label(String(format: "%.1f°C", systemModel.systemTemperature),
                                  systemImage: "thermometer")
                            Label(String(format: "%.1f%%", systemModel.systemEfficiency),
                                  systemImage: "chart.line.uptrend.xyaxis")
                        }
                        .font(.caption)
                    }
                    .padding()
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    
                    Spacer()
                }
                
                Spacer()
            }
            .padding()
        }
    }
    
    // Create ESS Cabinet 3D Model
    func createESSCabinet() async -> Entity {
        let cabinet = Entity()
        cabinet.name = "ESSCabinet"
        
        // Cabinet Frame (외부 케이스)
        let frameSize = SIMD3<Float>(0.8, 2.0, 0.6)
        let frameMesh = MeshResource.generateBox(size: frameSize)
        let frameMaterial = SimpleMaterial(color: .init(white: 0.15, alpha: 1.0), isMetallic: true)
        let frameEntity = ModelEntity(mesh: frameMesh, materials: [frameMaterial])
        frameEntity.name = "Frame"
        cabinet.addChild(frameEntity)
        
        // Cabinet Interior (내부 공간)
        let interiorSize = SIMD3<Float>(0.75, 1.95, 0.55)
        let interiorMesh = MeshResource.generateBox(size: interiorSize)
        let interiorMaterial = SimpleMaterial(color: .init(white: 0.25, alpha: 1.0), isMetallic: false)
        let interiorEntity = ModelEntity(mesh: interiorMesh, materials: [interiorMaterial])
        interiorEntity.name = "Interior"
        interiorEntity.position.z = -0.02
        cabinet.addChild(interiorEntity)
        
//        // Door (문)
//        let doorSize = SIMD3<Float>(0.76, 1.96, 0.02)
//        let doorMesh = MeshResource.generateBox(size: doorSize)
//        let doorMaterial = SimpleMaterial(color: .init(white: 0.2, alpha: 0.9), isMetallic: true)
//        let doorEntity = ModelEntity(mesh: doorMesh, materials: [doorMaterial])
//        doorEntity.name = "Door"
//        doorEntity.position = SIMD3<Float>(-frameSize.x/2 + 0.01, 0, frameSize.z/2)
//        cabinet.addChild(doorEntity)
//        
//        // Door Handle
//        let handleMesh = MeshResource.generateBox(size: [0.02, 0.15, 0.03])
//        let handleMaterial = SimpleMaterial(color: .gray, isMetallic: true)
//        let handleEntity = ModelEntity(mesh: handleMesh, materials: [handleMaterial])
//        handleEntity.position = SIMD3<Float>(doorSize.x/2 - 0.05, 0, 0.025)
//        doorEntity.addChild(handleEntity)
//        
//        // Window on door (문의 창)
//        let windowMesh = MeshResource.generateBox(size: [0.5, 0.3, 0.005])
//        let windowMaterial = SimpleMaterial(color: .init(white: 0.1, alpha: 0.3), isMetallic: false)
//        let windowEntity = ModelEntity(mesh: windowMesh, materials: [windowMaterial])
//        windowEntity.position = SIMD3<Float>(0, 0.3, 0.01)
//        doorEntity.addChild(windowEntity)
        
        // Battery Modules (10개 모듈 - 5행 2열)
        for i in 0..<10 {
            let module = createBatteryModule(index: i)
            let row = i / 2
            let col = i % 2
            
            module.position = SIMD3<Float>(
                -0.15 + Float(col) * 0.3,
                0.7 - Float(row) * 0.35,
                0
            )
            cabinet.addChild(module)
        }
        
        // Control Panel (상단 제어 패널)
        let panelMesh = MeshResource.generateBox(size: [0.6, 0.15, 0.05])
        let panelMaterial = SimpleMaterial(color: .init(white: 0.3, alpha: 1.0), isMetallic: false)
        let panelEntity = ModelEntity(mesh: panelMesh, materials: [panelMaterial])
        panelEntity.name = "ControlPanel"
        panelEntity.position = SIMD3<Float>(0, 0.85, 0.25)
        cabinet.addChild(panelEntity)
        
        // Display Screen on panel
        let screenMesh = MeshResource.generateBox(size: [0.3, 0.1, 0.01])
        let screenMaterial = UnlitMaterial(color: .init(red: 0, green: 0.8, blue: 1.0, alpha: 1.0))
        let screenEntity = ModelEntity(mesh: screenMesh, materials: [screenMaterial])
        screenEntity.position = SIMD3<Float>(0, 0, 0.03)
        panelEntity.addChild(screenEntity)
        
        // LED Indicators
        for i in 0..<5 {
            let ledMesh = MeshResource.generateSphere(radius: 0.01)
            let ledColor = i < 3 ? UIColor.green : UIColor.yellow
            let ledMaterial = UnlitMaterial(color: ledColor)
            let ledEntity = ModelEntity(mesh: ledMesh, materials: [ledMaterial])
            ledEntity.position = SIMD3<Float>(-0.2 + Float(i) * 0.05, -0.05, 0.03)
            panelEntity.addChild(ledEntity)
        }
        
        // Cooling Vents (냉각 통풍구)
        for i in 0..<3 {
            let ventMesh = MeshResource.generateBox(size: [0.7, 0.02, 0.1])
            let ventMaterial = SimpleMaterial(color: .darkGray, isMetallic: true)
            let ventEntity = ModelEntity(mesh: ventMesh, materials: [ventMaterial])
            ventEntity.position = SIMD3<Float>(0, -0.85 + Float(i) * 0.05, 0.25)
            cabinet.addChild(ventEntity)
        }
        
        // Cables (내부 케이블)
        for i in 0..<5 {
            let cableMesh = MeshResource.generateCylinder(height: 0.3, radius: 0.005)
            let cableColors: [UIColor] = [.yellow, .yellow, .black, .red, .blue]
            let cableMaterial = SimpleMaterial(color: cableColors[i], isMetallic: false)
            let cableEntity = ModelEntity(mesh: cableMesh, materials: [cableMaterial])
            cableEntity.position = SIMD3<Float>(
                -0.3 + Float(i) * 0.02,
                0.5,
                -0.2
            )
            cableEntity.orientation = simd_quatf(angle: .pi/2, axis: [1, 0, 0])
            cabinet.addChild(cableEntity)
        }
        
        return cabinet
    }
    
    // Create individual battery module
    func createBatteryModule(index: Int) -> Entity {
        let module = Entity()
        module.name = "Module_\(index)"
        
        // Module case
        let caseMesh = MeshResource.generateBox(size: [0.25, 0.3, 0.4])
        let caseMaterial = SimpleMaterial(color: .darkGray, isMetallic: true)
        let caseEntity = ModelEntity(mesh: caseMesh, materials: [caseMaterial])
        module.addChild(caseEntity)
        
        // Battery cells (visible part)
        for row in 0..<2 {
            for col in 0..<4 {
                let cellMesh = MeshResource.generateCylinder(height: 0.25, radius: 0.02)
                let cellMaterial = SimpleMaterial(color: .init(red: 0.2, green: 0.3, blue: 0.8, alpha: 1.0),
                                                 isMetallic: true)
                let cellEntity = ModelEntity(mesh: cellMesh, materials: [cellMaterial])
                cellEntity.position = SIMD3<Float>(
                    -0.08 + Float(col) * 0.05,
                    -0.05 + Float(row) * 0.1,
                    0.15
                )
                cellEntity.orientation = simd_quatf(angle: .pi/2, axis: [1, 0, 0])
                module.addChild(cellEntity)
            }
        }
        
        // Status LED
        let statusMesh = MeshResource.generateBox(size: [0.2, 0.02, 0.01])
        let statusMaterial = UnlitMaterial(color: index < 8 ? .green : .yellow)
        let statusEntity = ModelEntity(mesh: statusMesh, materials: [statusMaterial])
        statusEntity.position = SIMD3<Float>(0, 0.1, 0.21)
        module.addChild(statusEntity)
        
        // Module label
        let labelMesh = MeshResource.generateBox(size: [0.08, 0.03, 0.001])
        let labelMaterial = SimpleMaterial(color: .white, isMetallic: false)
        let labelEntity = ModelEntity(mesh: labelMesh, materials: [labelMaterial])
        labelEntity.position = SIMD3<Float>(0, -0.1, 0.21)
        module.addChild(labelEntity)
        
        return module
    }
    
    // Animate door opening/closing
    func animateDoor(open: Bool) {
        guard let cabinet = essEntity,
              let door = cabinet.findEntity(named: "Door") else { return }
        
        var transform = door.transform
        if open {
            // Rotate door 90 degrees on Y axis (open)
            transform.rotation = simd_quatf(angle: -.pi/2, axis: [0, 1, 0])
            transform.translation.x = -0.4
            transform.translation.z = 0.1
        } else {
            // Reset to closed position
            transform.rotation = simd_quatf()
            transform.translation.x = -0.39
            transform.translation.z = 0.3
        }
        
        door.move(to: transform, relativeTo: door.parent, duration: 0.5)
    }
    
    // Update labels visibility
    func updateLabelsVisibility(show: Bool) {
        guard let cabinet = essEntity else { return }
        
        for i in 0..<10 {
            if let attachment = cabinet.findEntity(named: "Attachment:module_\(i)") {
                attachment.isEnabled = show
            }
        }
    }
}

// Module Info Bubble
struct ModuleInfoBubble: View {
    let module: BatteryModule
    
    var body: some View {
        VStack(spacing: 4) {
            HStack {
                Circle()
                    .fill(module.status.color)
                    .frame(width: 10, height: 10)
                Text("M\(module.position + 1)")
                    .font(.caption)
                    .fontWeight(.bold)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text("\(Int(module.soc))%")
                    .font(.caption)
                Text(String(format: "%.1fV", module.voltage))
                    .font(.caption)
                Text(String(format: "%.1f°C", module.temperature))
                    .font(.caption)
            }
        }
        .padding(30)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// System Info Panel
struct SystemInfoPanel: View {
    @ObservedObject var systemModel: ESSSystemModel
    
    var body: some View {
        VStack(spacing: 10) {
            Text("ESS System Status")
                .font(.headline)
            
            HStack(spacing: 20) {
                VStack {
                    Text("Power")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(String(format: "%.2f kW", systemModel.totalPower))
                        .font(.title3)
                        .fontWeight(.bold)
                }
                
                VStack {
                    Text("Efficiency")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(String(format: "%.1f%%", systemModel.systemEfficiency))
                        .font(.title3)
                        .fontWeight(.bold)
                }
                
                VStack {
                    Text("Temperature")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(String(format: "%.1f°C", systemModel.systemTemperature))
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundStyle(systemModel.systemTemperature > 35 ? .orange : .green)
                }
            }
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
