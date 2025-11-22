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

// MARK: - Module Data
struct ModuleData: Identifiable, Codable {
    let id = UUID()
    let timestamp: Date
    let rackId: String
    var moduleId: String  // Changed to var so it can be modified
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

// MARK: - Rack System Model
class RackSystemModel: ObservableObject {
    @Published var currentRackData: RackData?
    @Published var rackDataHistory: [RackData] = []
    @Published var moduleData: [ModuleData] = []

    private var timer: Timer?
    private var allRackData: [RackData] = []
    private var allModuleData: [ModuleData] = []
    private var currentIndex = 0

    init() {
        loadCSVData()
        startSimulation()
    }

    func loadCSVData() {
        // Load Rack data
        if let rackURL = Bundle.main.url(forResource: "Rack_Data_1s", withExtension: "csv", subdirectory: "DummyData") {
            allRackData = CSVParser.parseRackData(from: rackURL)
            print("✅ Loaded \(allRackData.count) rack data entries")
        } else {
            print("❌ Failed to find Rack_Data_1s.csv")
        }

        // Load Module data
        if let moduleURL = Bundle.main.url(forResource: "Module_Data_M01_1s", withExtension: "csv", subdirectory: "DummyData") {
            allModuleData = CSVParser.parseModuleData(from: moduleURL)
            print("✅ Loaded \(allModuleData.count) module data entries")
        } else {
            print("❌ Failed to find Module_Data_M01_1s.csv")
        }
    }

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

        // Update module data (7 modules shown in the image)
        let moduleIndex = currentIndex % allModuleData.count
        if moduleIndex < allModuleData.count {
            // Simulate 7 modules with slight variations
            moduleData = (1...7).map { moduleNum in
                var data = allModuleData[moduleIndex]
                data.moduleId = "M\(String(format: "%02d", moduleNum))"
                return data
            }
        }
    }

    deinit {
        stopSimulation()
    }
}
