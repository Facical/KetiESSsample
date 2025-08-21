// KetiESSsample/App/EntryPoint.swift

import SwiftUI

@main
struct EntryPoint: App {
    var body: some Scene {
        WindowGroup {
            MainView()
        }
        .windowStyle(.plain)
        .defaultSize(width: 500, height: 700)
        
        // ESS View - 메인 기능
        ImmersiveSpace(id: "ESSView") {
            ESSView()
        }
        .immersionStyle(selection: .constant(.mixed), in: .mixed)
        
        // Sample Models - 기존 모델들
        ImmersiveSpace(id: "CarView") {
            CarView()
        }
        .immersionStyle(selection: .constant(.mixed), in: .mixed)
        
        ImmersiveSpace(id: "TurbineView") {
            TurbineView()
        }
        .immersionStyle(selection: .constant(.mixed), in: .mixed)
    }
}
