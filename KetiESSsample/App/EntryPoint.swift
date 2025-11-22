// KetiESSsample/App/EntryPoint.swift

import SwiftUI

@main
struct EntryPoint: App {
    var body: some Scene {
        WindowGroup {
            MainView()
        }
        .windowStyle(.plain)
        .defaultSize(width: 1500, height: 900)
        
        // ESS View - 메인 기능
        ImmersiveSpace(id: "ESSView") {
            ESSView()
        }
        .immersionStyle(selection: .constant(.mixed), in: .mixed)

        // Rack View - ESS Rack 3D 모델
        ImmersiveSpace(id: "RackView") {
            RackView()
        }
        .immersionStyle(selection: .constant(.mixed), in: .mixed)
    }
}
