// KetiESSsample/Models/ESSModel.swift

import Foundation
import SwiftUI
import Combine

// ESS 배터리 모듈 상태
struct BatteryModule: Identifiable {
    let id = UUID()
    let position: Int
    var voltage: Double
    var current: Double
    var temperature: Double
    var soc: Double // State of Charge (%)
    var status: ModuleStatus
    
    enum ModuleStatus {
        case normal
        case warning
        case critical
        case offline
        
        var color: Color {
            switch self {
            case .normal: return .green
            case .warning: return .yellow
            case .critical: return .red
            case .offline: return .gray
            }
        }
    }
}

// ESS 시스템 전체 상태
class ESSSystemModel: ObservableObject {
    @Published var modules: [BatteryModule] = []
    @Published var totalPower: Double = 0
    @Published var totalEnergy: Double = 0
    @Published var systemEfficiency: Double = 95.5
    @Published var inputPower: Double = 0
    @Published var outputPower: Double = 0
    @Published var systemTemperature: Double = 25.0
    
    // 실시간 데이터 히스토리 (그래프용)
    @Published var powerHistory: [Double] = []
    @Published var voltageHistory: [Double] = []
    @Published var temperatureHistory: [Double] = []
    
    private var timer: Timer?
    
    init() {
        // 10개의 배터리 모듈 초기화
        for i in 0..<10 {
            modules.append(BatteryModule(
                position: i,
                voltage: 48.0 + Double.random(in: -2...2),
                current: 50.0 + Double.random(in: -10...10),
                temperature: 25.0 + Double.random(in: -5...5),
                soc: 75.0 + Double.random(in: -20...20),
                status: .normal
            ))
        }
        
        // 초기 히스토리 데이터
        for _ in 0..<50 {
            powerHistory.append(Double.random(in: 80...120))
            voltageHistory.append(Double.random(in: 380...400))
            temperatureHistory.append(Double.random(in: 20...30))
        }
        
        startMonitoring()
    }
    
    func startMonitoring() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            self.updateSystemData()
        }
    }
    
    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }
    
    private func updateSystemData() {
        // 모듈 데이터 업데이트
        for i in modules.indices {
            modules[i].voltage += Double.random(in: -0.5...0.5)
            modules[i].current += Double.random(in: -2...2)
            modules[i].temperature += Double.random(in: -0.2...0.2)
            modules[i].soc = max(0, min(100, modules[i].soc + Double.random(in: -0.5...0.5)))
            
            // 상태 체크
            if modules[i].temperature > 40 {
                modules[i].status = .critical
            } else if modules[i].temperature > 35 {
                modules[i].status = .warning
            } else if modules[i].soc < 20 {
                modules[i].status = .warning
            } else {
                modules[i].status = .normal
            }
        }
        
        // 시스템 전체 데이터 계산
        totalPower = modules.reduce(0) { $0 + ($1.voltage * $1.current / 1000) }
        totalEnergy = totalPower * 0.5 // 임시 계산
        inputPower = totalPower * 1.05
        outputPower = totalPower * 0.95
        systemTemperature = modules.reduce(0) { $0 + $1.temperature } / Double(modules.count)
        
        // 히스토리 업데이트
        powerHistory.append(totalPower)
        if powerHistory.count > 50 { powerHistory.removeFirst() }
        
        voltageHistory.append(modules.first?.voltage ?? 0)
        if voltageHistory.count > 50 { voltageHistory.removeFirst() }
        
        temperatureHistory.append(systemTemperature)
        if temperatureHistory.count > 50 { temperatureHistory.removeFirst() }
    }
    
    deinit {
        stopMonitoring()
    }
}
