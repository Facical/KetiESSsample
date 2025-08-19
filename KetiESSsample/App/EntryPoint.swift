import SwiftUI

@main
struct EntryPoint: App {
    var body: some Scene {
        WindowGroup {
            MainView()
        }
        
        ImmersiveSpace(id: "CarView") {
            CarView()
        }
        
        ImmersiveSpace(id: "TurbineView") {
            TurbineView()
        }
    }
}
