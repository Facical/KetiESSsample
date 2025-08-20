import RealityKit
import simd

struct TurbinePart: Identifiable, Hashable {
    let id: String
    let entityName: String
    let title: String
    let detail: String
    let offset: SIMD3<Float>
}


enum TurbineParts {
    static let all: [TurbinePart] = [
        .init(id: "MainShaft", entityName: "Object_3",
              title: "메인 샤프트", detail: "터빈이 만든 토크를 압축기로 전달하고, \n 축베어링 위에서 고속으로 회전하는 역할", offset: [0, 0.3, 0]),
        .init(id: "FlameTube", entityName: "Object_13",
              title: "연소기 튜브", detail: "연료-공기 혼합이 연소되는 공간을 형성하고, \n 구멍을 통해 라이너 벽을 냉각하며 터빈 입구 온도 분포를 다듬음", offset: [0, -0.06, 0]),
        .init(id: "CombustorCase", entityName: "Object_4",
              title: "연소기 케이스", detail: "압력용 외피이자 구조물로, \n공기,연료,점화 계통을 지지하고 라이너로 들어갈 공기 흐름을\n 분배-유도하는 하우징", offset: [0, -0.05, 0]),
        
    ]
}
