import RealityKit
import simd

struct RackPart: Identifiable, Hashable {
    let id: String
    let entityName: String
    let title: String
    let detail: String
    let offset: SIMD3<Float>
}

enum RackParts {
    static let all: [RackPart] = [
        // We'll populate this after loading the Rack model and inspecting its structure
        // This will be dynamically updated based on the actual Rack.usdz model contents
    ]
}
