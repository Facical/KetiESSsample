// KetiESSsample/UI/ModuleDataBubble.swift

import SwiftUI

/// 모듈을 꺼냈을 때 표시되는 데이터 버블
struct ModuleDataBubble: View {
    let moduleId: String
    let moduleData: ModuleData?
    var onReturnTap: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 헤더
            HStack {
                Image(systemName: "battery.100.bolt")
                    .font(.title2)
                    .foregroundColor(headerColor)

                Text(formattedModuleId)
                    .font(.title2)
                    .fontWeight(.bold)

                Spacer()

                // 복귀 버튼
                Button(action: {
                    onReturnTap?()
                }) {
                    Image(systemName: "arrow.uturn.backward.circle.fill")
                        .font(.title2)
                        .foregroundColor(.blue)
                }
                .buttonStyle(.plain)
                .help("Return module to rack")
            }

            Divider()
                .background(Color.white.opacity(0.3))

            if let data = moduleData {
                // 온도 정보
                HStack(spacing: 20) {
                    DataItemWithStatus(icon: "thermometer.high", label: "Max Temp", value: String(format: "%.1f°C", data.maxCellTemp), status: maxTempStatus(data.maxCellTemp))
                    DataItemWithStatus(icon: "thermometer.low", label: "Min Temp", value: String(format: "%.1f°C", data.minCellTemp), status: minTempStatus(data.minCellTemp))
                    DataItemWithStatus(icon: "thermometer.medium", label: "Avg Temp", value: String(format: "%.1f°C", data.avgTemp), status: avgTempStatus(data.avgTemp))
                }

                Divider()
                    .background(Color.white.opacity(0.2))

                // 전압 정보
                HStack(spacing: 20) {
                    DataItemWithStatus(icon: "bolt.fill", label: "Max Volt", value: String(format: "%.2fV", data.maxCellVoltage), status: maxVoltageStatus(data.maxCellVoltage))
                    DataItemWithStatus(icon: "bolt", label: "Min Volt", value: String(format: "%.2fV", data.minCellVoltage), status: minVoltageStatus(data.minCellVoltage))
                    DataItemWithStatus(icon: "bolt.circle", label: "Avg Volt", value: String(format: "%.2fV", data.avgVoltage), status: avgVoltageStatus(data.avgVoltage))
                }

                Divider()
                    .background(Color.white.opacity(0.2))

                // 전류 & SOC/SOH 정보
                HStack(spacing: 20) {
                    DataItemWithStatus(icon: "arrow.right.circle", label: "Current", value: String(format: "%.1fA", data.avgCurrent), status: currentStatus(data.avgCurrent))
                    DataItemWithStatus(icon: "battery.75percent", label: "SOC", value: String(format: "%.1f%%", data.soc), status: socStatus(data.soc))
                    DataItemWithStatus(icon: "heart.fill", label: "SOH", value: String(format: "%.1f%%", data.soh), status: sohStatus(data.soh))
                }

                // 밸런싱 상태
                HStack {
                    Image(systemName: data.cellBalancingStatus == 1 ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(data.cellBalancingStatus == 1 ? .green : .gray)
                    Text("Cell Balancing: \(data.cellBalancingStatus == 1 ? "Active" : "Inactive")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 4)

            } else {
                Text("No data available")
                    .foregroundColor(.secondary)
                    .italic()
            }
        }
        .padding(20)
        .frame(width: 380)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(
                    LinearGradient(
                        colors: [borderColor.opacity(0.5), borderColor.opacity(0.3)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 2
                )
        )
        .glassBackgroundEffect()
    }

    // MARK: - 헤더/테두리 색상 (문제가 있으면 빨간색)

    private var headerColor: Color {
        guard let data = moduleData else { return .green }
        if hasAnyCritical(data) { return .red }
        if hasAnyWarning(data) { return .orange }
        return .green
    }

    private var borderColor: Color {
        guard let data = moduleData else { return .blue }
        if hasAnyCritical(data) { return .red }
        if hasAnyWarning(data) { return .orange }
        return .blue
    }

    // MARK: - 전체 상태 체크

    private func hasAnyCritical(_ data: ModuleData) -> Bool {
        return maxTempStatus(data.maxCellTemp) == .critical ||
               minTempStatus(data.minCellTemp) == .critical ||
               avgTempStatus(data.avgTemp) == .critical ||
               maxVoltageStatus(data.maxCellVoltage) == .critical ||
               minVoltageStatus(data.minCellVoltage) == .critical ||
               avgVoltageStatus(data.avgVoltage) == .critical ||
               currentStatus(data.avgCurrent) == .critical ||
               socStatus(data.soc) == .critical ||
               sohStatus(data.soh) == .critical
    }

    private func hasAnyWarning(_ data: ModuleData) -> Bool {
        return maxTempStatus(data.maxCellTemp) == .warning ||
               minTempStatus(data.minCellTemp) == .warning ||
               avgTempStatus(data.avgTemp) == .warning ||
               maxVoltageStatus(data.maxCellVoltage) == .warning ||
               minVoltageStatus(data.minCellVoltage) == .warning ||
               avgVoltageStatus(data.avgVoltage) == .warning ||
               currentStatus(data.avgCurrent) == .warning ||
               socStatus(data.soc) == .warning ||
               sohStatus(data.soh) == .warning
    }

    // 모듈 ID 포맷팅 (예: "Module1_001" -> "Module 01")
    private var formattedModuleId: String {
        if let range = moduleId.range(of: #"Module(\d+)"#, options: .regularExpression) {
            let numStr = moduleId[range].dropFirst(6)
            if let num = Int(numStr) {
                return String(format: "Module %02d", num)
            }
        }
        return moduleId
    }

    // MARK: - 임계값 기반 상태 판정

    // 온도 (높을수록 나쁨): normal ≤ 35, warning ≤ 40, critical > 40
    private func maxTempStatus(_ temp: Double) -> DataStatus {
        if temp > 40 { return .critical }
        if temp > 35 { return .warning }
        return .normal
    }

    private func minTempStatus(_ temp: Double) -> DataStatus {
        // Min Temp는 너무 낮으면 문제 (예: < 10도)
        if temp < 10 { return .critical }
        if temp < 15 { return .warning }
        return .normal
    }

    private func avgTempStatus(_ temp: Double) -> DataStatus {
        if temp > 40 { return .critical }
        if temp > 35 { return .warning }
        return .normal
    }

    // 전압 (낮을수록 나쁨): normal ≥ 3.6, warning ≥ 3.4, critical < 3.4
    private func maxVoltageStatus(_ voltage: Double) -> DataStatus {
        // Max Voltage가 너무 높으면 과충전
        if voltage > 4.2 { return .critical }
        if voltage > 4.0 { return .warning }
        return .normal
    }

    private func minVoltageStatus(_ voltage: Double) -> DataStatus {
        if voltage < 3.4 { return .critical }
        if voltage < 3.6 { return .warning }
        return .normal
    }

    private func avgVoltageStatus(_ voltage: Double) -> DataStatus {
        // avgVoltage는 24셀 합계이므로 다른 기준 적용 (약 86.4V ~ 87.6V 정상)
        if voltage < 82 { return .critical }
        if voltage < 85 { return .warning }
        return .normal
    }

    // 전류 (낮을수록 나쁨 - 방전 기준): normal ≥ 35, warning ≥ 25, critical < 25
    private func currentStatus(_ current: Double) -> DataStatus {
        if current < 25 { return .critical }
        if current < 35 { return .warning }
        return .normal
    }

    // SOC (낮을수록 나쁨): normal ≥ 65, warning ≥ 50, critical < 50
    private func socStatus(_ soc: Double) -> DataStatus {
        if soc < 50 { return .critical }
        if soc < 65 { return .warning }
        return .normal
    }

    // SOH (낮을수록 나쁨): normal ≥ 80, warning ≥ 60, critical < 60
    private func sohStatus(_ soh: Double) -> DataStatus {
        if soh < 60 { return .critical }
        if soh < 80 { return .warning }
        return .normal
    }
}

// MARK: - 데이터 상태 열거형

enum DataStatus {
    case normal
    case warning
    case critical

    var color: Color {
        switch self {
        case .normal: return .primary
        case .warning: return .orange
        case .critical: return .red
        }
    }

    var iconColor: Color {
        switch self {
        case .normal: return .green
        case .warning: return .orange
        case .critical: return .red
        }
    }
}

/// 상태 기반 데이터 아이템 뷰 (임계값에 따라 색상 변경)
private struct DataItemWithStatus: View {
    let icon: String
    let label: String
    let value: String
    let status: DataStatus

    var body: some View {
        VStack(alignment: .center, spacing: 4) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(status.iconColor)

            Text(value)
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(status.color)

            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(minWidth: 80)
    }
}

#Preview {
    VStack(spacing: 20) {
        // 정상 모듈
        ModuleDataBubble(
            moduleId: "Module1_001",
            moduleData: ModuleData(
                timestamp: Date(),
                rackId: "R01",
                moduleId: "M01",
                maxCellTemp: 32.5,
                minCellTemp: 28.1,
                avgTemp: 30.3,
                maxCellVoltage: 3.72,
                minCellVoltage: 3.65,
                avgVoltage: 87.6,
                stringMaxCurrent: 52.5,
                stringMinCurrent: 48.2,
                avgCurrent: 50.8,
                soc: 85.5,
                soh: 96.2,
                cellBalancingStatus: 1
            )
        )

        // 문제 있는 모듈 (M08)
        ModuleDataBubble(
            moduleId: "Module8_001",
            moduleData: ModuleData(
                timestamp: Date(),
                rackId: "R01",
                moduleId: "M08",
                maxCellTemp: 43.5,
                minCellTemp: 31.1,
                avgTemp: 37.3,
                maxCellVoltage: 3.72,
                minCellVoltage: 3.28,
                avgVoltage: 87.6,
                stringMaxCurrent: 48.5,
                stringMinCurrent: 22.2,
                avgCurrent: 35.8,
                soc: 54.5,
                soh: 55.2,
                cellBalancingStatus: 0
            )
        )
    }
    .padding()
    .background(Color.black)
}
