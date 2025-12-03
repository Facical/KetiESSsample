// KetiESSsample/Utilities/ModuleMapping.swift

import Foundation

/// 모듈 ID와 3D 엔티티 이름 간의 매핑을 관리하는 유틸리티
struct ModuleMapping {

    // MARK: - 상수
    static let moduleCount = 11
    static let cellsPerModule = 48

    // MARK: - 3D 엔티티 이름 → CSV 모듈 ID

    /// 3D 엔티티 이름을 CSV 모듈 ID로 변환
    /// - Parameter entityName: 3D 모델의 엔티티 이름 (예: "Module1_001")
    /// - Returns: CSV 모듈 ID (예: "M01") 또는 nil
    static func csvModuleId(from entityName: String) -> String? {
        // "Module1_001" → "M01"
        // "Module10_001" → "M10"
        guard entityName.hasPrefix("Module") else { return nil }

        let stripped = entityName.replacingOccurrences(of: "Module", with: "")
        // "1_001" 또는 "10_001"에서 숫자 추출
        if let underscoreIndex = stripped.firstIndex(of: "_") {
            let numberPart = String(stripped[..<underscoreIndex])
            if let number = Int(numberPart), number >= 1 && number <= moduleCount {
                return String(format: "M%02d", number)
            }
        }
        return nil
    }

    /// 3D 엔티티 이름을 모듈 인덱스(0-based)로 변환
    /// - Parameter entityName: 3D 모델의 엔티티 이름 (예: "Module1_001")
    /// - Returns: 모듈 인덱스 (0~10) 또는 nil
    static func moduleIndex(from entityName: String) -> Int? {
        guard entityName.hasPrefix("Module") else { return nil }

        let stripped = entityName.replacingOccurrences(of: "Module", with: "")
        if let underscoreIndex = stripped.firstIndex(of: "_") {
            let numberPart = String(stripped[..<underscoreIndex])
            if let number = Int(numberPart), number >= 1 && number <= moduleCount {
                return number - 1  // 0-based index
            }
        }
        return nil
    }

    // MARK: - CSV 모듈 ID → 3D 엔티티 이름

    /// CSV 모듈 ID를 3D 엔티티 이름으로 변환
    /// - Parameter moduleId: CSV 모듈 ID (예: "M01")
    /// - Returns: 3D 엔티티 이름 (예: "Module1_001") 또는 nil
    static func entityName(from moduleId: String) -> String? {
        // "M01" → "Module1_001"
        guard moduleId.hasPrefix("M"), moduleId.count >= 2 else { return nil }

        let numberPart = String(moduleId.dropFirst())  // "01"
        if let number = Int(numberPart), number >= 1 && number <= moduleCount {
            return "Module\(number)_001"
        }
        return nil
    }

    /// 모듈 인덱스(0-based)를 3D 엔티티 이름으로 변환
    /// - Parameter index: 모듈 인덱스 (0~10)
    /// - Returns: 3D 엔티티 이름 (예: "Module1_001")
    static func entityName(from index: Int) -> String? {
        guard index >= 0 && index < moduleCount else { return nil }
        return "Module\(index + 1)_001"
    }

    /// 모듈 인덱스(0-based)를 CSV 모듈 ID로 변환
    /// - Parameter index: 모듈 인덱스 (0~10)
    /// - Returns: CSV 모듈 ID (예: "M01")
    static func csvModuleId(from index: Int) -> String? {
        guard index >= 0 && index < moduleCount else { return nil }
        return String(format: "M%02d", index + 1)
    }

    // MARK: - 셀 ID 변환

    /// 셀 인덱스(0-based)를 CSV 셀 ID로 변환
    /// - Parameter index: 셀 인덱스 (0~47)
    /// - Returns: CSV 셀 ID (예: "C01")
    static func csvCellId(from index: Int) -> String? {
        guard index >= 0 && index < cellsPerModule else { return nil }
        return String(format: "C%02d", index + 1)
    }

    /// CSV 셀 ID를 셀 인덱스(0-based)로 변환
    /// - Parameter cellId: CSV 셀 ID (예: "C01")
    /// - Returns: 셀 인덱스 (0~47) 또는 nil
    static func cellIndex(from cellId: String) -> Int? {
        guard cellId.hasPrefix("C"), cellId.count >= 2 else { return nil }

        let numberPart = String(cellId.dropFirst())
        if let number = Int(numberPart), number >= 1 && number <= cellsPerModule {
            return number - 1
        }
        return nil
    }

    // MARK: - 전체 매핑 테이블

    /// 모든 모듈의 매핑 정보
    static let allModuleMappings: [(index: Int, csvId: String, entityName: String)] = {
        (0..<moduleCount).map { index in
            (
                index: index,
                csvId: String(format: "M%02d", index + 1),
                entityName: "Module\(index + 1)_001"
            )
        }
    }()
}
