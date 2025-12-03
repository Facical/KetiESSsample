// KetiESSsample/App/EntryPoint.swift

import SwiftUI

@main
struct EntryPoint: App {
    var body: some Scene {
        // Main Window (RackView가 열리면 자동으로 닫힘)
        WindowGroup(id: "MainWindow") {
            MainView()
        }
        .windowStyle(.plain)
        .defaultSize(width: 1500, height: 900)

        // ESS View - 메인 기능
        ImmersiveSpace(id: "ESSView") {
            ESSView()
        }
        .immersionStyle(selection: .constant(.mixed), in: .mixed)

        // Rack View - ESS Rack 3D 모델 (컨트롤 패널이 3D 공간에 표시됨)
        ImmersiveSpace(id: "RackView") {
            RackView()
        }
        .immersionStyle(selection: .constant(.mixed), in: .mixed)
    }
}
