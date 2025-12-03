// KetiESSsample/Models/RackDataModel.swift

import Foundation
import SwiftUI
import Combine

// MARK: - Rack Data
struct RackData: Identifiable, Codable {
    let id = UUID()
    let timestamp: Date
    let rackId: String
    let systemBusVoltage: Double
    let systemBusCurrent: Double
    let systemOnlineSOC: Double
    let systemOnlineSOH: Double

    enum CodingKeys: String, CodingKey {
        case timestamp
        case rackId = "rack_id"
        case systemBusVoltage = "system_bus_voltage"
        case systemBusCurrent = "system_bus_current"
        case systemOnlineSOC = "system_online_soc"
        case systemOnlineSOH = "system_online_soh"
    }
}

// MARK: - Cell Data
struct CellData: Identifiable {
    let id = UUID()
    let timestamp: Date
    let rackId: String
    let moduleId: String
    let cellId: String
    let voltage: Double
    let current: Double
    let temp: Double
    let soc: Double
    let soh: Double

    // 모듈 번호 추출 (M01 -> 1)
    var moduleNumber: Int {
        Int(moduleId.dropFirst()) ?? 0
    }

    // 셀 번호 추출 (C01 -> 1)
    var cellNumber: Int {
        Int(cellId.dropFirst()) ?? 0
    }
}

// MARK: - Module Data
struct ModuleData: Identifiable, Codable {
    let id = UUID()
    let timestamp: Date
    let rackId: String
    var moduleId: String
    let maxCellTemp: Double
    let minCellTemp: Double
    let avgTemp: Double
    let maxCellVoltage: Double
    let minCellVoltage: Double
    let avgVoltage: Double
    let stringMaxCurrent: Double
    let stringMinCurrent: Double
    let avgCurrent: Double
    let soc: Double
    let soh: Double
    let cellBalancingStatus: Int

    enum CodingKeys: String, CodingKey {
        case timestamp
        case rackId = "rack_id"
        case moduleId = "module_id"
        case maxCellTemp = "max_cell_temp"
        case minCellTemp = "min_cell_temp"
        case avgTemp = "avg_temp"
        case maxCellVoltage = "max_cell_voltage"
        case minCellVoltage = "min_cell_voltage"
        case avgVoltage = "avg_voltage"
        case stringMaxCurrent = "string_max_current"
        case stringMinCurrent = "string_min_current"
        case avgCurrent = "avg_current"
        case soc
        case soh
        case cellBalancingStatus = "cell_balancing_status"
    }
}

// MARK: - Module Health Status
enum ModuleHealthStatus {
    case normal    // 정상
    case warning   // 경고
    case critical  // 위험
    case unknown   // 데이터 없음

    var colorName: String {
        switch self {
        case .normal: return "green"
        case .warning: return "orange"
        case .critical: return "red"
        case .unknown: return "gray"
        }
    }

    var color: Color {
        switch self {
        case .normal: return .green
        case .warning: return .orange
        case .critical: return .red
        case .unknown: return .gray
        }
    }
}

// MARK: - Module Color Metric (3D 색상 기준 지표)
enum ModuleColorMetric: String, CaseIterable, Identifiable {
    case minSoC = "Min SoC"
    case avgSoC = "Avg SoC"
    case soh = "SoH"
    case avgCurrent = "Avg Current"
    case maxCurrent = "Max Current"
    case minCurrent = "Min Current"
    case avgVoltage = "Avg Voltage"
    case maxVoltage = "Max Voltage"
    case minVoltage = "Min Voltage"
    case avgTemp = "Avg Temp"
    case maxTemp = "Max Temp"
    case minTemp = "Min Temp"

    var id: String { rawValue }

    var unit: String {
        switch self {
        case .minSoC, .avgSoC, .soh:
            return "%"
        case .avgCurrent, .maxCurrent, .minCurrent:
            return "A"
        case .avgVoltage, .maxVoltage, .minVoltage:
            return "V"
        case .avgTemp, .maxTemp, .minTemp:
            return "°C"
        }
    }

    var icon: String {
        switch self {
        case .minSoC, .avgSoC:
            return "battery.75"
        case .soh:
            return "heart.fill"
        case .avgCurrent, .maxCurrent, .minCurrent:
            return "bolt.fill"
        case .avgVoltage, .maxVoltage, .minVoltage:
            return "powerplug.fill"
        case .avgTemp, .maxTemp, .minTemp:
            return "thermometer"
        }
    }

    /// 각 지표별 임계값 (normal, warning, critical)
    var thresholds: (normalMin: Double, warningMin: Double) {
        switch self {
        case .minSoC, .avgSoC:
            return (65.0, 50.0)  // >= 65: normal, >= 50: warning, < 50: critical
        case .soh:
            return (80.0, 60.0)  // >= 80: normal, >= 60: warning, < 60: critical
        case .avgCurrent, .maxCurrent, .minCurrent:
            return (50.0, 30.0)  // >= 50: normal, >= 30: warning, < 30: critical (방전 기준)
        case .avgVoltage, .maxVoltage, .minVoltage:
            return (3.6, 3.4)    // >= 3.6V: normal, >= 3.4V: warning, < 3.4V: critical
        case .avgTemp, .maxTemp, .minTemp:
            // 온도는 반대: 낮을수록 좋음
            return (35.0, 40.0)  // <= 35: normal, <= 40: warning, > 40: critical
        }
    }

    /// 온도처럼 높을수록 나쁜 지표인지
    var isInverseMetric: Bool {
        switch self {
        case .avgTemp, .maxTemp, .minTemp:
            return true
        default:
            return false
        }
    }
}

// MARK: - Rack System Model
class RackSystemModel: ObservableObject {
    @Published var currentRackData: RackData?
    @Published var rackDataHistory: [RackData] = []
    @Published var moduleData: [ModuleData] = []
    @Published var moduleDataHistory: [[ModuleData]] = []  // [moduleIndex][historyIndex] - 모듈별 히스토리
    @Published var cellSoCMatrix: [[Double]] = []  // [module][cell] SoC 값 (11x48)
    @Published var selectedModuleIndex: Int? = nil  // 선택된 모듈 인덱스 (0-based)
    @Published var selectedColorMetric: ModuleColorMetric = .minSoC  // 3D 색상 기준 지표
    @Published var currentCellData: [CellData] = []  // 현재 타임스탬프의 모든 셀 데이터 (528개)
    @Published var cellDataHistory: [[CellData]] = []  // 셀별 히스토리 [cellIndex][historyIndex]

    private var timer: Timer?
    private var allRackData: [RackData] = []
    private var allModuleData: [ModuleData] = []
    private var allCellData: [CellData] = []
    private var currentIndex = 0

    // 상수
    static let moduleCount = 11
    static let cellsPerModule = 48

    // 로딩 상태
    @Published var isDataLoaded: Bool = false

    init() {
        initializeModuleDataHistory()
        initializeCellDataHistory()
        // CSV 로딩을 백그라운드에서 수행 (메인 스레드 블로킹 방지)
        Task.detached(priority: .userInitiated) { [weak self] in
            self?.loadCSVData()
            await MainActor.run {
                self?.isDataLoaded = true
                self?.startSimulation()
            }
        }
    }

    private func initializeModuleDataHistory() {
        moduleDataHistory = Array(repeating: [], count: Self.moduleCount)
    }

    private func initializeCellDataHistory() {
        // 11 modules * 48 cells = 528 cells
        cellDataHistory = Array(repeating: [], count: Self.moduleCount * Self.cellsPerModule)
    }

    // MARK: - 모듈 선택 및 데이터 조회

    /// 3D 엔티티 이름으로 모듈 선택
    func selectModule(byEntityName entityName: String) {
        if let index = ModuleMapping.moduleIndex(from: entityName) {
            selectedModuleIndex = index
            print("📊 [RackModel] Selected module: \(entityName) → index \(index)")
        }
    }

    /// 모듈 선택 해제
    func deselectModule() {
        selectedModuleIndex = nil
    }

    /// 선택된 모듈의 SoC 배열 반환 (48개 셀)
    var selectedModuleCellSoCs: [Double]? {
        guard let index = selectedModuleIndex,
              index < cellSoCMatrix.count else { return nil }
        return cellSoCMatrix[index]
    }

    /// 선택된 모듈의 ModuleData 반환
    var selectedModuleData: ModuleData? {
        guard let index = selectedModuleIndex,
              index < moduleData.count else { return nil }
        return moduleData[index]
    }

    /// 특정 모듈의 평균 SoC 반환
    func averageSoC(forModuleIndex index: Int) -> Double? {
        guard index >= 0 && index < cellSoCMatrix.count else { return nil }
        let cells = cellSoCMatrix[index]
        guard !cells.isEmpty else { return nil }
        return cells.reduce(0, +) / Double(cells.count)
    }

    /// 특정 모듈의 최소 SoC 반환
    func minSoC(forModuleIndex index: Int) -> Double? {
        guard index >= 0 && index < cellSoCMatrix.count else { return nil }
        return cellSoCMatrix[index].min()
    }

    /// 특정 모듈의 상태 (정상/경고/위험) - 기본 SoC 기준
    func moduleStatus(forIndex index: Int) -> ModuleHealthStatus {
        guard let minSoc = minSoC(forModuleIndex: index) else { return .unknown }

        if minSoc < 50 {
            return .critical
        } else if minSoc < 65 {
            return .warning
        } else {
            return .normal
        }
    }

    /// 모든 모듈의 상태 배열
    var allModuleStatuses: [ModuleHealthStatus] {
        (0..<Self.moduleCount).map { moduleStatus(forIndex: $0) }
    }

    // MARK: - 지표별 모듈 상태 계산

    /// 특정 모듈의 지표 값 가져오기
    func metricValue(forModuleIndex index: Int, metric: ModuleColorMetric) -> Double? {
        switch metric {
        case .minSoC:
            return minSoC(forModuleIndex: index)
        case .avgSoC:
            return averageSoC(forModuleIndex: index)
        case .soh, .avgCurrent, .maxCurrent, .minCurrent, .avgVoltage, .maxVoltage, .minVoltage, .avgTemp, .maxTemp, .minTemp:
            // ModuleData에서 값 가져오기
            guard index >= 0 && index < moduleData.count else { return nil }
            let data = moduleData[index]
            switch metric {
            case .soh:
                return data.soh
            case .avgCurrent:
                return data.avgCurrent
            case .maxCurrent:
                return data.stringMaxCurrent
            case .minCurrent:
                return data.stringMinCurrent
            case .avgVoltage:
                return data.avgVoltage
            case .maxVoltage:
                return data.maxCellVoltage
            case .minVoltage:
                return data.minCellVoltage
            case .avgTemp:
                return data.avgTemp
            case .maxTemp:
                return data.maxCellTemp
            case .minTemp:
                return data.minCellTemp
            default:
                return nil
            }
        }
    }

    /// 특정 지표 기준 모듈 상태 계산
    func moduleStatus(forIndex index: Int, metric: ModuleColorMetric) -> ModuleHealthStatus {
        guard let value = metricValue(forModuleIndex: index, metric: metric) else {
            return .unknown
        }

        let thresholds = metric.thresholds

        if metric.isInverseMetric {
            // 온도: 낮을수록 좋음
            if value <= thresholds.normalMin {
                return .normal
            } else if value <= thresholds.warningMin {
                return .warning
            } else {
                return .critical
            }
        } else {
            // SoC, SoH, 전압, 전류: 높을수록 좋음
            if value >= thresholds.normalMin {
                return .normal
            } else if value >= thresholds.warningMin {
                return .warning
            } else {
                return .critical
            }
        }
    }

    /// 선택된 지표 기준 모든 모듈의 상태 배열
    var allModuleStatusesByMetric: [ModuleHealthStatus] {
        (0..<Self.moduleCount).map { moduleStatus(forIndex: $0, metric: selectedColorMetric) }
    }

    /// 모든 모듈의 현재 선택된 지표 값 배열
    var allModuleMetricValues: [Double?] {
        (0..<Self.moduleCount).map { metricValue(forModuleIndex: $0, metric: selectedColorMetric) }
    }

    // MARK: - CSV 데이터 로드

    func loadCSVData() {
        print("📂 [CSV] Searching for CSV files in bundle...")
        print("📂 [CSV] Bundle path: \(Bundle.main.bundlePath)")

        let rackURL = findCSVFile(named: "Rack_Data_1s")
        let moduleURL = findCSVFile(named: "Module_Data_M01_1s")
        let cellURL = findCSVFile(named: "Cell_Data_M01_1s")

        // Load Rack data
        if let url = rackURL {
            allRackData = CSVParser.parseRackData(from: url)
            print("✅ Loaded \(allRackData.count) rack data entries")
        } else {
            print("❌ Failed to find Rack_Data_1s.csv")
        }

        // Load Module data
        if let url = moduleURL {
            allModuleData = CSVParser.parseModuleData(from: url)
            print("✅ Loaded \(allModuleData.count) module data entries")
        } else {
            print("❌ Failed to find Module_Data_M01_1s.csv")
        }

        // Load Cell data
        if let url = cellURL {
            allCellData = CSVParser.parseCellData(from: url)
            print("✅ Loaded \(allCellData.count) cell data entries")
        } else {
            print("❌ Failed to find Cell_Data_M01_1s.csv")
        }

        initializeCellSoCMatrix()
    }

    private func initializeCellSoCMatrix() {
        cellSoCMatrix = Array(repeating: Array(repeating: 85.0, count: Self.cellsPerModule), count: Self.moduleCount)
    }

    private func findCSVFile(named fileName: String) -> URL? {
        if let url = Bundle.main.url(forResource: fileName, withExtension: "csv") {
            return url
        }
        if let url = Bundle.main.url(forResource: fileName, withExtension: "csv", subdirectory: "DummyData") {
            return url
        }
        if let urls = Bundle.main.urls(forResourcesWithExtension: "csv", subdirectory: nil),
           let url = urls.first(where: { $0.lastPathComponent == "\(fileName).csv" }) {
            return url
        }
        if let urls = Bundle.main.urls(forResourcesWithExtension: "csv", subdirectory: "DummyData"),
           let url = urls.first(where: { $0.lastPathComponent == "\(fileName).csv" }) {
            return url
        }
        return nil
    }

    // MARK: - 시뮬레이션

    func startSimulation() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateData()
        }
    }

    func stopSimulation() {
        timer?.invalidate()
        timer = nil
    }

    private func updateData() {
        guard !allRackData.isEmpty else { return }

        currentIndex = (currentIndex + 1) % allRackData.count

        // Update current rack data
        currentRackData = allRackData[currentIndex]

        // Update history (keep last 50 points)
        rackDataHistory.append(allRackData[currentIndex])
        if rackDataHistory.count > 50 {
            rackDataHistory.removeFirst()
        }

        // Update module data (11 modules)
        let moduleStartIndex = currentIndex * Self.moduleCount
        if moduleStartIndex + Self.moduleCount <= allModuleData.count {
            moduleData = Array(allModuleData[moduleStartIndex..<(moduleStartIndex + Self.moduleCount)])

            // Module 7 (인덱스 6)의 SOC를 Warning 범위(50~65%)로 조정하여 주황색 표시
            if moduleData.count > 6 {
                moduleData[6].moduleId = moduleData[6].moduleId  // 변경 가능하게 하기 위한 트릭
                var module7 = moduleData[6]
                module7 = ModuleData(
                    timestamp: module7.timestamp,
                    rackId: module7.rackId,
                    moduleId: module7.moduleId,
                    maxCellTemp: 33.0,      // 정상 범위 (< 35)
                    minCellTemp: module7.minCellTemp,
                    avgTemp: 32.0,          // 정상 범위 (< 35)
                    maxCellVoltage: module7.maxCellVoltage,
                    minCellVoltage: 3.65,   // 정상 범위 (> 3.6)
                    avgVoltage: module7.avgVoltage,
                    stringMaxCurrent: module7.stringMaxCurrent,
                    stringMinCurrent: module7.stringMinCurrent,
                    avgCurrent: 40.0,       // 정상 범위 (> 35)
                    soc: 58.0,              // Warning 범위 (50~65) → 주황색
                    soh: 85.0,              // 정상 범위 (> 80)
                    cellBalancingStatus: module7.cellBalancingStatus
                )
                moduleData[6] = module7
            }

            // Update module history (keep last 50 points per module)
            for (index, data) in moduleData.enumerated() {
                moduleDataHistory[index].append(data)
                if moduleDataHistory[index].count > 50 {
                    moduleDataHistory[index].removeFirst()
                }
            }
        }

        // Update cell SoC matrix and cell data
        updateCellSoCMatrix()
        updateCurrentCellData()
    }

    private func updateCurrentCellData() {
        let cellsPerTimestamp = Self.moduleCount * Self.cellsPerModule
        let cellStartIndex = currentIndex * cellsPerTimestamp

        guard cellStartIndex + cellsPerTimestamp <= allCellData.count else {
            return
        }

        currentCellData = Array(allCellData[cellStartIndex..<(cellStartIndex + cellsPerTimestamp)])

        // Update cell history (keep last 50 points per cell)
        for cell in currentCellData {
            let moduleIdx = cell.moduleNumber - 1
            let cellIdx = cell.cellNumber - 1
            let flatIndex = moduleIdx * Self.cellsPerModule + cellIdx

            if flatIndex >= 0 && flatIndex < cellDataHistory.count {
                cellDataHistory[flatIndex].append(cell)
                if cellDataHistory[flatIndex].count > 50 {
                    cellDataHistory[flatIndex].removeFirst()
                }
            }
        }
    }

    /// 특정 모듈, 셀의 데이터 반환
    func cellData(moduleIndex: Int, cellIndex: Int) -> CellData? {
        return currentCellData.first { cell in
            cell.moduleNumber - 1 == moduleIndex && cell.cellNumber - 1 == cellIndex
        }
    }

    /// 특정 모듈, 셀의 히스토리 반환
    func cellHistory(moduleIndex: Int, cellIndex: Int) -> [CellData] {
        let flatIndex = moduleIndex * Self.cellsPerModule + cellIndex
        guard flatIndex >= 0 && flatIndex < cellDataHistory.count else { return [] }
        return cellDataHistory[flatIndex]
    }

    private func updateCellSoCMatrix() {
        let cellsPerTimestamp = Self.moduleCount * Self.cellsPerModule
        let cellStartIndex = currentIndex * cellsPerTimestamp

        guard cellStartIndex + cellsPerTimestamp <= allCellData.count else {
            return
        }

        let currentCells = Array(allCellData[cellStartIndex..<(cellStartIndex + cellsPerTimestamp)])

        var newMatrix = Array(repeating: Array(repeating: 85.0, count: Self.cellsPerModule), count: Self.moduleCount)

        for cell in currentCells {
            let moduleIdx = cell.moduleNumber - 1
            let cellIdx = cell.cellNumber - 1

            if moduleIdx >= 0 && moduleIdx < Self.moduleCount &&
               cellIdx >= 0 && cellIdx < Self.cellsPerModule {
                newMatrix[moduleIdx][cellIdx] = cell.soc
            }
        }

        cellSoCMatrix = newMatrix
    }

    deinit {
        stopSimulation()
    }
}
