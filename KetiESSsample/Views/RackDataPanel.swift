// KetiESSsample/Views/RackDataPanel.swift

import SwiftUI
import Charts

// MARK: - 선택 가능한 파라미터 타입 (Rack)
enum RackParameter: String, CaseIterable, Identifiable {
    case none = "None"
    case voltage = "System Bus Voltage"
    case current = "System Bus Current"
    case soc = "System Online SOC"
    case soh = "System Online SOH"

    var id: String { rawValue }

    var unit: String {
        switch self {
        case .none: return ""
        case .voltage: return "V"
        case .current: return "A"
        case .soc, .soh: return "%"
        }
    }

    var color: Color {
        switch self {
        case .none: return .clear
        case .voltage: return .cyan
        case .current: return .purple
        case .soc: return .green
        case .soh: return .orange
        }
    }

    var graphTitle: String {
        switch self {
        case .none: return ""
        case .voltage: return "System Bus Voltage Stream Graph"
        case .current: return "System Bus Current Stream Graph"
        case .soc: return "System Online SOC Stream Graph"
        case .soh: return "System Online SOH Stream Graph"
        }
    }
}

// MARK: - 선택 가능한 파라미터 타입 (Module)
enum ModuleParameter: String, CaseIterable, Identifiable {
    case none = "None"
    case maxCellTemp = "Max Cell Temp"
    case minCellTemp = "Min Cell Temp"
    case avgTemp = "Avg Temp"
    case maxCellVoltage = "Max Cell Voltage"
    case minCellVoltage = "Min Cell Voltage"
    case avgVoltage = "Avg Voltage"
    case stringMaxCurrent = "String Max Current"
    case stringMinCurrent = "String Min Current"
    case avgCurrent = "Avg Current"
    case soc = "SOC"
    case soh = "SOH"

    var id: String { rawValue }

    var unit: String {
        switch self {
        case .none: return ""
        case .maxCellTemp, .minCellTemp, .avgTemp: return "°C"
        case .maxCellVoltage, .minCellVoltage: return "V"
        case .avgVoltage: return "V"
        case .stringMaxCurrent, .stringMinCurrent, .avgCurrent: return "A"
        case .soc, .soh: return "%"
        }
    }

    var color: Color {
        switch self {
        case .none: return .clear
        case .maxCellTemp: return .red
        case .minCellTemp: return .blue
        case .avgTemp: return .orange
        case .maxCellVoltage: return .yellow
        case .minCellVoltage: return .cyan
        case .avgVoltage: return .teal
        case .stringMaxCurrent: return .purple
        case .stringMinCurrent: return .indigo
        case .avgCurrent: return .pink
        case .soc: return .green
        case .soh: return .mint
        }
    }

    var graphTitle: String {
        switch self {
        case .none: return ""
        case .maxCellTemp: return "Max Cell Temperature Stream Graph"
        case .minCellTemp: return "Min Cell Temperature Stream Graph"
        case .avgTemp: return "Average Temperature Stream Graph"
        case .maxCellVoltage: return "Max Cell Voltage Stream Graph"
        case .minCellVoltage: return "Min Cell Voltage Stream Graph"
        case .avgVoltage: return "Average Voltage Stream Graph"
        case .stringMaxCurrent: return "String Max Current Stream Graph"
        case .stringMinCurrent: return "String Min Current Stream Graph"
        case .avgCurrent: return "Average Current Stream Graph"
        case .soc: return "SOC Stream Graph"
        case .soh: return "SOH Stream Graph"
        }
    }

    /// ModuleData에서 해당 파라미터 값 추출
    func value(from data: ModuleData) -> Double {
        switch self {
        case .none: return 0
        case .maxCellTemp: return data.maxCellTemp
        case .minCellTemp: return data.minCellTemp
        case .avgTemp: return data.avgTemp
        case .maxCellVoltage: return data.maxCellVoltage
        case .minCellVoltage: return data.minCellVoltage
        case .avgVoltage: return data.avgVoltage
        case .stringMaxCurrent: return data.stringMaxCurrent
        case .stringMinCurrent: return data.stringMinCurrent
        case .avgCurrent: return data.avgCurrent
        case .soc: return data.soc
        case .soh: return data.soh
        }
    }
}

// MARK: - 선택 가능한 파라미터 타입 (Cell)
enum CellParameter: String, CaseIterable, Identifiable {
    case none = "None"
    case voltage = "Voltage"
    case current = "Current"
    case temp = "Temp"
    case soc = "SOC"
    case soh = "SOH"

    var id: String { rawValue }

    var unit: String {
        switch self {
        case .none: return ""
        case .voltage: return "V"
        case .current: return "A"
        case .temp: return "°C"
        case .soc, .soh: return "%"
        }
    }

    var color: Color {
        switch self {
        case .none: return .clear
        case .voltage: return .cyan
        case .current: return .purple
        case .temp: return .orange
        case .soc: return .green
        case .soh: return .mint
        }
    }

    var graphTitle: String {
        switch self {
        case .none: return ""
        case .voltage: return "Cell Voltage Stream Graph"
        case .current: return "Cell Current Stream Graph"
        case .temp: return "Cell Temperature Stream Graph"
        case .soc: return "Cell SOC Stream Graph"
        case .soh: return "Cell SOH Stream Graph"
        }
    }

    /// CellData에서 해당 파라미터 값 추출
    func value(from data: CellData) -> Double {
        switch self {
        case .none: return 0
        case .voltage: return data.voltage
        case .current: return data.current
        case .temp: return data.temp
        case .soc: return data.soc
        case .soh: return data.soh
        }
    }
}

struct RackDataPanel: View {
    @ObservedObject var rackModel: RackSystemModel
    @Binding var selectedTab: Int  // 0: Rack, 1: Module, 2: Cell (외부에서 관찰 가능)
    @Binding var selectedModuleIndex: Int  // Module 선택 (0-10) (외부에서 관찰 가능)
    @State private var selectedParameter: RackParameter = .none
    @State private var selectedModuleParameter: ModuleParameter = .none  // Module 탭용
    @State private var selectedCellParameter: CellParameter = .none  // Cell 탭용
    @State private var selectedCellModuleIndex: Int = 0  // Cell 탭에서 모듈 선택 (0-10)
    @State private var selectedCellIndex: Int = 0  // Cell 탭에서 셀 선택 (0-47)

    var body: some View {
        VStack(spacing: 0) {
            // 메인 패널 - 탭에 따라 다른 뷰 표시
            Group {
                switch selectedTab {
                case 0:
                    RackTabView(
                        rackModel: rackModel,
                        selectedParameter: $selectedParameter
                    )
                case 1:
                    ModuleTabView(
                        rackModel: rackModel,
                        selectedModuleIndex: $selectedModuleIndex,
                        selectedParameter: $selectedModuleParameter
                    )
                case 2:
                    CellTabView(
                        rackModel: rackModel,
                        selectedModuleIndex: $selectedCellModuleIndex,
                        selectedCellIndex: $selectedCellIndex,
                        selectedParameter: $selectedCellParameter
                    )
                default:
                    RackTabView(
                        rackModel: rackModel,
                        selectedParameter: $selectedParameter
                    )
                }
            }
            .padding(40)
            .frame(width: 1500, height: 1100)
            .glassBackgroundEffect()

            // 4. 하단 탭 바 (패널 아래에 별도 배치)
            BottomTabBar(selectedTab: $selectedTab)
                .padding(.top, 20)
        }
    }
}

// MARK: - Rack Tab View
private struct RackTabView: View {
    @ObservedObject var rackModel: RackSystemModel
    @Binding var selectedParameter: RackParameter

    var body: some View {
        VStack(alignment: .leading, spacing: 25) {
            // 1. 최상단 타이틀
            Text("Rack#001")
                .font(.system(size: 64, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 10)

            // 2. 상단 정보 패널
            if let data = rackModel.currentRackData {
                RackInfoDarkPanel(
                    data: data,
                    selectedParameter: $selectedParameter
                )
            }

            // 3. 하단 패널
            if selectedParameter == .none {
                CellSoCHeatmapDarkPanel(cellSoCMatrix: rackModel.cellSoCMatrix)
            } else {
                ParameterStreamGraphPanel(
                    parameter: selectedParameter,
                    history: rackModel.rackDataHistory
                )
            }

            Spacer(minLength: 0)
        }
    }
}

// MARK: - Module Tab View
private struct ModuleTabView: View {
    @ObservedObject var rackModel: RackSystemModel
    @Binding var selectedModuleIndex: Int
    @Binding var selectedParameter: ModuleParameter

    var currentModuleData: ModuleData? {
        guard selectedModuleIndex < rackModel.moduleData.count else { return nil }
        return rackModel.moduleData[selectedModuleIndex]
    }

    var currentCellSoCs: [Double] {
        guard selectedModuleIndex < rackModel.cellSoCMatrix.count else { return [] }
        return rackModel.cellSoCMatrix[selectedModuleIndex]
    }

    var currentModuleHistory: [ModuleData] {
        guard selectedModuleIndex < rackModel.moduleDataHistory.count else { return [] }
        return rackModel.moduleDataHistory[selectedModuleIndex]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 25) {
            // 1. 최상단 타이틀 + 모듈 선택 버튼들
            HStack {
                Text("Module#\(String(format: "%03d", selectedModuleIndex + 1))")
                    .font(.system(size: 64, weight: .bold))
                    .foregroundColor(.white)

                Spacer()

                // 모듈 선택 버튼들 (1-11)
                HStack(spacing: 12) {
                    ForEach(0..<11, id: \.self) { index in
                        Button(action: {
                            selectedModuleIndex = index
                        }) {
                            Text("\(index + 1)")
                                .font(.system(size: 22, weight: selectedModuleIndex == index ? .bold : .medium))
                                .foregroundColor(selectedModuleIndex == index ? .white : .white.opacity(0.6))
                                .frame(width: 55, height: 55)
                                .background(selectedModuleIndex == index ? Color.blue : Color.white.opacity(0.1))
                                .clipShape(Circle())
                                .overlay(
                                    Circle()
                                        .strokeBorder(selectedModuleIndex == index ? Color.blue.opacity(0.8) : Color.clear, lineWidth: 2)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 10)

            // 2. 모듈 정보 패널
            if let data = currentModuleData {
                ModuleInfoDarkPanel(
                    data: data,
                    moduleIndex: selectedModuleIndex,
                    selectedParameter: $selectedParameter
                )
            }

            // 3. 하단 패널 - 파라미터 선택에 따라 다른 뷰
            if selectedParameter == .none {
                ModuleSoCPlotPanel(cellSoCs: currentCellSoCs)
            } else {
                ModuleParameterStreamGraphPanel(
                    parameter: selectedParameter,
                    history: currentModuleHistory
                )
            }

            Spacer(minLength: 0)
        }
    }
}

// MARK: - Cell Tab View
private struct CellTabView: View {
    @ObservedObject var rackModel: RackSystemModel
    @Binding var selectedModuleIndex: Int
    @Binding var selectedCellIndex: Int
    @Binding var selectedParameter: CellParameter

    var currentCellData: CellData? {
        rackModel.cellData(moduleIndex: selectedModuleIndex, cellIndex: selectedCellIndex)
    }

    var currentCellHistory: [CellData] {
        rackModel.cellHistory(moduleIndex: selectedModuleIndex, cellIndex: selectedCellIndex)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // 1. 최상단 타이틀 + 모듈/셀 선택
            HStack {
                Text("Cell #\(String(format: "%03d", selectedModuleIndex * 48 + selectedCellIndex + 1))")
                    .font(.system(size: 64, weight: .bold))
                    .foregroundColor(.white)

                Spacer()
            }
            .padding(.horizontal, 10)

            // 모듈 선택 버튼들 (1-11)
            HStack(spacing: 8) {
                Text("Module:")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))

                ForEach(0..<11, id: \.self) { index in
                    Button(action: {
                        selectedModuleIndex = index
                    }) {
                        Text("\(index + 1)")
                            .font(.system(size: 14, weight: selectedModuleIndex == index ? .bold : .medium))
                            .foregroundColor(selectedModuleIndex == index ? .white : .white.opacity(0.6))
                            .frame(width: 36, height: 36)
                            .background(selectedModuleIndex == index ? Color.blue : Color.white.opacity(0.1))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
            }

            // 셀 선택 슬라이더
            HStack(spacing: 15) {
                Text("Cell: \(selectedCellIndex + 1)")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
                    .frame(width: 80, alignment: .leading)

                Slider(value: Binding(
                    get: { Double(selectedCellIndex) },
                    set: { selectedCellIndex = Int($0) }
                ), in: 0...47, step: 1)
                .tint(.blue)

                Text("/ 48")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.5))
            }
            .padding(.horizontal, 10)

            // 2. 셀 정보 패널
            if let data = currentCellData {
                CellInfoDarkPanel(
                    data: data,
                    moduleIndex: selectedModuleIndex,
                    cellIndex: selectedCellIndex,
                    selectedParameter: $selectedParameter
                )
            }

            // 3. 하단 패널 - 파라미터 선택에 따라 다른 뷰
            if selectedParameter == .none {
                CellMultiLinePlotPanel(
                    rackModel: rackModel,
                    moduleIndex: selectedModuleIndex,
                    cellIndex: selectedCellIndex
                )
            } else {
                CellParameterStreamGraphPanel(
                    parameter: selectedParameter,
                    history: currentCellHistory
                )
            }

            Spacer(minLength: 0)
        }
    }
}

// MARK: - 1. Top Info Panel (Dark & Pill Layout)
private struct RackInfoDarkPanel: View {
    let data: RackData
    @Binding var selectedParameter: RackParameter

    var body: some View {
        VStack(alignment: .leading, spacing: 25) {
            // 내부 헤더 (Rack ID + 날짜 + 화살표)
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Rack#001")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.white.opacity(0.9))

                    Text(data.timestamp, format: .dateTime.year().month().day().hour().minute().second())
                        .font(.system(size: 20))
                        .foregroundColor(.white.opacity(0.5))
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundColor(.white.opacity(0.5))
                    .font(.title)
            }

            // 4개의 캡슐형 메트릭 박스 (HStack) - 탭 가능
            HStack(spacing: 15) {
                SelectableMetricPill(
                    label: "System Bus\nVoltage",
                    value: String(format: "%.1fV", data.systemBusVoltage),
                    parameter: .voltage,
                    selectedParameter: $selectedParameter
                )
                SelectableMetricPill(
                    label: "System Bus\nCurrent",
                    value: String(format: "%.1fA", data.systemBusCurrent),
                    parameter: .current,
                    selectedParameter: $selectedParameter
                )
                SelectableMetricPill(
                    label: "System Online\nSOC",
                    value: String(format: "%.0f%%", data.systemOnlineSOC),
                    parameter: .soc,
                    selectedParameter: $selectedParameter
                )
                SelectableMetricPill(
                    label: "System Online\nSOH",
                    value: String(format: "%.0f%%", data.systemOnlineSOH),
                    parameter: .soh,
                    selectedParameter: $selectedParameter
                )
            }
        }
        .padding(30)
        // 패널 배경: 검은색 반투명 (이미지처럼 어둡게)
        .background(Color.black.opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: 30))
    }
}

// 탭 가능한 메트릭 캡슐
private struct SelectableMetricPill: View {
    let label: String
    let value: String
    let parameter: RackParameter
    @Binding var selectedParameter: RackParameter

    private var isSelected: Bool {
        selectedParameter == parameter
    }

    var body: some View {
        Button {
            // 비동기로 state 변경하여 view update 중 변경 방지
            DispatchQueue.main.async {
                withAnimation(.easeInOut(duration: 0.2)) {
                    if selectedParameter == parameter {
                        selectedParameter = .none
                    } else {
                        selectedParameter = parameter
                    }
                }
            }
        } label: {
            HStack {
                Text(label)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(isSelected ? .white : .white.opacity(0.6))
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)

                Spacer()

                Text(value)
                    .font(.system(size: 36, weight: .bold))
                    .foregroundColor(isSelected ? parameter.color : .white)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 20)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(isSelected ? parameter.color.opacity(0.3) : Color.white.opacity(0.1))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .strokeBorder(isSelected ? parameter.color : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Parameter Stream Graph Panel
private struct ParameterStreamGraphPanel: View {
    let parameter: RackParameter
    let history: [RackData]

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // 헤더
            HStack {
                Text(parameter.graphTitle)
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundColor(.white.opacity(0.8))

                Spacer()

                // 정보 아이콘
                Image(systemName: "info.circle")
                    .font(.title)
                    .foregroundColor(.white.opacity(0.5))
            }

            // 그래프
            if history.isEmpty {
                // 데이터가 없을 때
                VStack {
                    Spacer()
                    Text("No data available")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(.white.opacity(0.5))
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                StreamGraph(parameter: parameter, history: history)
            }
        }
        .padding(30)
        .frame(maxHeight: 800)
        .background(Color.black.opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: 30))
    }
}

// Chart용 Rack 데이터 포인트
private struct RackChartDataPoint: Identifiable {
    let id: Int
    let index: Int
    let timestamp: Date
    let value: Double
}

// MARK: - Stream Graph (Charts)
private struct StreamGraph: View {
    let parameter: RackParameter
    let history: [RackData]

    // 미리 계산된 데이터 포인트
    private var chartData: [RackChartDataPoint] {
        history.enumerated().map { index, data in
            RackChartDataPoint(
                id: index,
                index: index,
                timestamp: data.timestamp,
                value: getValue(from: data)
            )
        }
    }

    private var yDomain: ClosedRange<Double> {
        let values = chartData.map { $0.value }
        let minVal = values.min() ?? 0
        let maxVal = values.max() ?? 100
        let padding = (maxVal - minVal) * 0.1
        return (minVal - padding)...(maxVal + padding)
    }

    var body: some View {
        Chart(chartData) { point in
            LineMark(
                x: .value("Time", point.timestamp),
                y: .value(parameter.rawValue, point.value)
            )
            .foregroundStyle(parameter.color)
            .lineStyle(StrokeStyle(lineWidth: 2))

            AreaMark(
                x: .value("Time", point.timestamp),
                y: .value(parameter.rawValue, point.value)
            )
            .foregroundStyle(
                LinearGradient(
                    colors: [parameter.color.opacity(0.3), parameter.color.opacity(0.05)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )

            // 데이터 포인트 표시 (간격 조절)
            if point.index % 5 == 0 {
                PointMark(
                    x: .value("Time", point.timestamp),
                    y: .value(parameter.rawValue, point.value)
                )
                .foregroundStyle(parameter.color)
                .symbolSize(30)
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 5)) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [5, 5]))
                    .foregroundStyle(Color.white.opacity(0.2))
                AxisValueLabel()
                    .foregroundStyle(Color.white.opacity(0.6))
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 6)) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [5, 5]))
                    .foregroundStyle(Color.white.opacity(0.2))
                AxisValueLabel {
                    if let doubleValue = value.as(Double.self) {
                        Text("\(Int(doubleValue))\(parameter.unit)")
                            .foregroundStyle(Color.white.opacity(0.6))
                    }
                }
            }
        }
        .chartYScale(domain: yDomain)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func getValue(from data: RackData) -> Double {
        switch parameter {
        case .voltage: return data.systemBusVoltage
        case .current: return data.systemBusCurrent
        case .soc: return data.systemOnlineSOC
        case .soh: return data.systemOnlineSOH
        case .none: return 0
        }
    }
}

// MARK: - 2. Heatmap Panel
private struct CellSoCHeatmapDarkPanel: View {
    let cellSoCMatrix: [[Double]]  // [module][cell] SoC 값

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("Cell SoC Heatmap")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundColor(.white.opacity(0.8))

                Spacer()

                // 범례
                HStack(spacing: 14) {
                    LegendItem(color: SoCColorHelper.color(for: 97), label: "95-100%")
                    LegendItem(color: SoCColorHelper.color(for: 90), label: "85-95%")
                    LegendItem(color: SoCColorHelper.color(for: 80), label: "75-85%")
                    LegendItem(color: SoCColorHelper.color(for: 70), label: "65-75%")
                    LegendItem(color: SoCColorHelper.color(for: 50), label: "<65%")
                }
            }

            // 히트맵 그리드
            HeatmapGrid(cellSoCMatrix: cellSoCMatrix)

            Spacer(minLength: 0)
        }
        .padding(30)
        .frame(maxHeight: 800)
        .background(Color.black.opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: 30))
    }
}

// MARK: - Legend Item
private struct LegendItem: View {
    let color: Color
    let label: String

    var body: some View {
        HStack(spacing: 5) {
            RoundedRectangle(cornerRadius: 3)
                .fill(color)
                .frame(width: 16, height: 16)
            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
        }
    }
}

// MARK: - SoC Color Helper
private struct SoCColorHelper {
    /// SoC 값에 따른 색상 반환
    /// - 청록색: 95-100%
    /// - 녹색: 85-95%
    /// - 노란색: 75-85%
    /// - 주황색: 65-75%
    /// - 빨간색: <65%
    static func color(for soc: Double) -> Color {
        if soc >= 95 {
            return Color(red: 0.0, green: 0.7, blue: 0.7)   // 청록색
        } else if soc >= 85 {
            return Color(red: 0.2, green: 0.7, blue: 0.3)   // 녹색
        } else if soc >= 75 {
            return Color(red: 0.9, green: 0.8, blue: 0.2)   // 노란색
        } else if soc >= 65 {
            return Color(red: 0.9, green: 0.5, blue: 0.1)   // 주황색
        } else {
            return Color(red: 0.8, green: 0.2, blue: 0.2)   // 빨간색
        }
    }
}

// MARK: - Heatmap Grid
private struct HeatmapGrid: View {
    let cellSoCMatrix: [[Double]]
    let rows = 11    // 모듈 개수
    let cols = 48    // 모듈당 셀 개수

    var body: some View {
        VStack(spacing: 4) {
            ForEach(0..<rows, id: \.self) { row in
                HStack(spacing: 4) {
                    ForEach(0..<cols, id: \.self) { col in
                        let soc = getSoC(module: row, cell: col)
                        RoundedRectangle(cornerRadius: 3)
                            .fill(SoCColorHelper.color(for: soc))
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// 안전하게 SoC 값 가져오기
    private func getSoC(module: Int, cell: Int) -> Double {
        guard module < cellSoCMatrix.count,
              cell < (cellSoCMatrix.first?.count ?? 0) else {
            return 85.0  // 기본값
        }
        return cellSoCMatrix[module][cell]
    }
}

// MARK: - Module Info Panel
private struct ModuleInfoDarkPanel: View {
    let data: ModuleData
    let moduleIndex: Int
    @Binding var selectedParameter: ModuleParameter

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // 헤더 (Module ID + 날짜)
            VStack(alignment: .leading, spacing: 5) {
                Text("Module #\(String(format: "%03d", moduleIndex + 1))")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white.opacity(0.9))

                Text(data.timestamp, format: .dateTime.year().month().day().hour().minute().second())
                    .font(.system(size: 18))
                    .foregroundColor(.white.opacity(0.5))
            }

            // 메트릭 그리드 (3열 x 4행) - 선택 가능
            VStack(spacing: 12) {
                // Row 1: Temperature
                HStack(spacing: 12) {
                    SelectableModuleMetricPill(
                        label: "Max Cell Temp",
                        value: String(format: "%.1f°C", data.maxCellTemp),
                        parameter: .maxCellTemp,
                        selectedParameter: $selectedParameter
                    )
                    SelectableModuleMetricPill(
                        label: "Min Cell Temp",
                        value: String(format: "%.1f°C", data.minCellTemp),
                        parameter: .minCellTemp,
                        selectedParameter: $selectedParameter
                    )
                    SelectableModuleMetricPill(
                        label: "Avg Temp",
                        value: String(format: "%.1f°C", data.avgTemp),
                        parameter: .avgTemp,
                        selectedParameter: $selectedParameter
                    )
                }

                // Row 2: Voltage
                HStack(spacing: 12) {
                    SelectableModuleMetricPill(
                        label: "Max Cell Voltage",
                        value: String(format: "%.2fV", data.maxCellVoltage),
                        parameter: .maxCellVoltage,
                        selectedParameter: $selectedParameter
                    )
                    SelectableModuleMetricPill(
                        label: "Min Cell Voltage",
                        value: String(format: "%.2fV", data.minCellVoltage),
                        parameter: .minCellVoltage,
                        selectedParameter: $selectedParameter
                    )
                    SelectableModuleMetricPill(
                        label: "Avg Voltage",
                        value: String(format: "%.1fV", data.avgVoltage),
                        parameter: .avgVoltage,
                        selectedParameter: $selectedParameter
                    )
                }

                // Row 3: Current
                HStack(spacing: 12) {
                    SelectableModuleMetricPill(
                        label: "String Max Current",
                        value: String(format: "%.1fA", data.stringMaxCurrent),
                        parameter: .stringMaxCurrent,
                        selectedParameter: $selectedParameter
                    )
                    SelectableModuleMetricPill(
                        label: "String Min Current",
                        value: String(format: "%.1fA", data.stringMinCurrent),
                        parameter: .stringMinCurrent,
                        selectedParameter: $selectedParameter
                    )
                    SelectableModuleMetricPill(
                        label: "Avg Current",
                        value: String(format: "%.2fA", data.avgCurrent),
                        parameter: .avgCurrent,
                        selectedParameter: $selectedParameter
                    )
                }

                // Row 4: SOC, SOH, Balancing
                HStack(spacing: 12) {
                    SelectableModuleMetricPill(
                        label: "SOC",
                        value: String(format: "%.1f%%", data.soc),
                        parameter: .soc,
                        selectedParameter: $selectedParameter
                    )
                    SelectableModuleMetricPill(
                        label: "SOH",
                        value: String(format: "%.1f%%", data.soh),
                        parameter: .soh,
                        selectedParameter: $selectedParameter
                    )
                    // Cell balancing은 선택 불가 (숫자가 아님)
                    ModuleMetricPill(label: "Cell Balancing", value: data.cellBalancingStatus == 1 ? "ON" : "OFF")
                }
            }
        }
        .padding(30)
        .background(Color.black.opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: 30))
    }
}

// 모듈용 메트릭 필 (선택 불가)
private struct ModuleMetricPill: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.6))
                .lineLimit(2)

            Spacer()

            Text(value)
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 18)
        .frame(maxWidth: .infinity)
        .background(Color.white.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// 선택 가능한 모듈 메트릭 필
private struct SelectableModuleMetricPill: View {
    let label: String
    let value: String
    let parameter: ModuleParameter
    @Binding var selectedParameter: ModuleParameter

    private var isSelected: Bool {
        selectedParameter == parameter
    }

    var body: some View {
        Button {
            // 비동기로 state 변경하여 view update 중 변경 방지
            DispatchQueue.main.async {
                if selectedParameter == parameter {
                    selectedParameter = .none
                } else {
                    selectedParameter = parameter
                }
            }
        } label: {
            HStack {
                Text(label)
                    .font(.system(size: 14))
                    .foregroundColor(isSelected ? .white : .white.opacity(0.6))
                    .lineLimit(2)

                Spacer()

                Text(value)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 18)
            .frame(maxWidth: .infinity)
            .background(
                isSelected
                    ? parameter.color.opacity(0.4)
                    : Color.white.opacity(0.1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(
                        isSelected ? parameter.color : Color.clear,
                        lineWidth: 2
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Module SoC Plot Panel (Violin Plot)
private struct ModuleSoCPlotPanel: View {
    let cellSoCs: [Double]

    // 온도, 전압, 전류에 대한 샘플 데이터 (실제로는 Cell 데이터에서 추출)
    var tempData: [Double] {
        // 셀 SoC를 기반으로 온도 범위 시뮬레이션 (25-45도)
        cellSoCs.map { 25 + ($0 / 100.0) * 20 }
    }

    var voltageData: [Double] {
        // 셀 SoC를 기반으로 전압 범위 시뮬레이션 (3.2-4.2V)
        cellSoCs.map { 3.2 + ($0 / 100.0) * 1.0 }
    }

    var currentData: [Double] {
        // 셀 SoC를 기반으로 전류 범위 시뮬레이션 (0-5A)
        cellSoCs.map { ($0 / 100.0) * 5.0 }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // 헤더
            HStack {
                Text("Module SoC Plot")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundColor(.white.opacity(0.8))

                Spacer()

                Image(systemName: "info.circle")
                    .font(.title)
                    .foregroundColor(.white.opacity(0.5))
            }

            // 3개의 바이올린 플롯
            HStack(spacing: 20) {
                ViolinPlotCard(title: "Temp", data: tempData, color: .green)
                ViolinPlotCard(title: "Voltage", data: voltageData, color: .cyan)
                ViolinPlotCard(title: "Current", data: currentData, color: .purple)
            }
        }
        .padding(25)
        .frame(maxHeight: 420)
        .background(Color.black.opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: 30))
    }
}

// 바이올린 플롯 카드
private struct ViolinPlotCard: View {
    let title: String
    let data: [Double]
    let color: Color

    var body: some View {
        VStack(spacing: 10) {
            // 바이올린 플롯 그래프
            ViolinPlotShape(data: data, color: color)
                .frame(maxWidth: .infinity, minHeight: 180, maxHeight: 250)

            // 레이블 + 화살표
            HStack {
                Text(title)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white.opacity(0.8))

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundColor(.white.opacity(0.4))
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
}

// 바이올린 플롯 Shape
private struct ViolinPlotShape: View {
    let data: [Double]
    let color: Color

    private var stats: (min: Double, max: Double, q1: Double, median: Double, q3: Double) {
        guard !data.isEmpty else {
            return (0, 100, 25, 50, 75)
        }
        let sorted = data.sorted()
        let count = sorted.count

        let minVal = sorted.first ?? 0
        let maxVal = sorted.last ?? 100
        let medianVal = sorted[count / 2]
        let q1Val = sorted[count / 4]
        let q3Val = sorted[(count * 3) / 4]

        return (minVal, maxVal, q1Val, medianVal, q3Val)
    }

    var body: some View {
        Canvas { context, size in
            let width = size.width
            let height = size.height
            let centerX = width / 2
            let range = Swift.max(stats.max - stats.min, 0.001)

            // Y 위치 계산 (상단 25%, 하단 10% 여백)
            func yPos(_ value: Double) -> CGFloat {
                let normalized = (value - stats.min) / range
                return height * (1 - CGFloat(normalized)) * 0.65 + height * 0.25
            }

            // 바이올린 폭 계산 (KDE + 끝 테이퍼링)
            func widthAt(_ t: Double, value: Double) -> CGFloat {
                // KDE: 중앙값 근처가 넓음
                let distFromMedian = abs(value - stats.median) / range
                let kdeWidth = exp(-distFromMedian * distFromMedian * 6) * width * 0.38

                // 끝 테이퍼링: 양 끝(t=0, t=1)에서 폭이 0으로 줄어듦
                let taper = 1.0 - pow(2.0 * t - 1.0, 4)  // 양 끝에서 0, 중앙에서 1

                return kdeWidth * CGFloat(taper)
            }

            // 바이올린 경로 생성
            var violinPath = Path()
            let steps = 30

            // 오른쪽 곡선
            for i in 0...steps {
                let t = Double(i) / Double(steps)
                let value = stats.min + t * range
                let y = yPos(value)
                let w = widthAt(t, value: value)
                let point = CGPoint(x: centerX + w, y: y)
                if i == 0 {
                    violinPath.move(to: point)
                } else {
                    violinPath.addLine(to: point)
                }
            }

            // 왼쪽 곡선
            for i in stride(from: steps, through: 0, by: -1) {
                let t = Double(i) / Double(steps)
                let value = stats.min + t * range
                let y = yPos(value)
                let w = widthAt(t, value: value)
                violinPath.addLine(to: CGPoint(x: centerX - w, y: y))
            }
            violinPath.closeSubpath()

            // 바이올린 채우기
            context.fill(
                violinPath,
                with: .linearGradient(
                    Gradient(colors: [color.opacity(0.6), color.opacity(0.3)]),
                    startPoint: CGPoint(x: 0, y: height / 2),
                    endPoint: CGPoint(x: width, y: height / 2)
                )
            )

            // IQR 중앙선
            var iqrPath = Path()
            iqrPath.move(to: CGPoint(x: centerX, y: yPos(stats.q1)))
            iqrPath.addLine(to: CGPoint(x: centerX, y: yPos(stats.q3)))
            context.stroke(iqrPath, with: .color(color), lineWidth: 4)

            // 중앙값 점
            let medianY = yPos(stats.median)
            context.fill(
                Path(ellipseIn: CGRect(x: centerX - 6, y: medianY - 6, width: 12, height: 12)),
                with: .color(color)
            )

            // 최소/최대 선
            var whiskerPath = Path()
            // 최소값 수평선
            whiskerPath.move(to: CGPoint(x: centerX - 15, y: yPos(stats.min)))
            whiskerPath.addLine(to: CGPoint(x: centerX + 15, y: yPos(stats.min)))
            // 최대값 수평선
            whiskerPath.move(to: CGPoint(x: centerX - 15, y: yPos(stats.max)))
            whiskerPath.addLine(to: CGPoint(x: centerX + 15, y: yPos(stats.max)))
            // 수직 연결선
            whiskerPath.move(to: CGPoint(x: centerX, y: yPos(stats.min)))
            whiskerPath.addLine(to: CGPoint(x: centerX, y: yPos(stats.q1)))
            whiskerPath.move(to: CGPoint(x: centerX, y: yPos(stats.q3)))
            whiskerPath.addLine(to: CGPoint(x: centerX, y: yPos(stats.max)))

            context.stroke(whiskerPath, with: .color(color.opacity(0.8)), lineWidth: 2)
        }
    }
}

// MARK: - Module Parameter Stream Graph Panel
private struct ModuleParameterStreamGraphPanel: View {
    let parameter: ModuleParameter
    let history: [ModuleData]

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // 헤더
            HStack {
                Text(parameter.graphTitle)
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))

                Spacer()

                // 현재 값 표시
                if let latest = history.last {
                    let value = parameter.value(from: latest)
                    Text(String(format: "%.2f%@", value, parameter.unit))
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(parameter.color)
                }
            }

            // 스트림 그래프
            ModuleStreamGraph(parameter: parameter, history: history)
        }
        .padding(30)
        .frame(minHeight: 350, maxHeight: 800)
        .background(Color.black.opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: 30))
    }
}

// Chart용 데이터 포인트
private struct ModuleChartDataPoint: Identifiable {
    let id: Int
    let index: Int
    let value: Double
}

// Module용 스트림 그래프
private struct ModuleStreamGraph: View {
    let parameter: ModuleParameter
    let history: [ModuleData]

    // 미리 계산된 데이터 포인트
    private var chartData: [ModuleChartDataPoint] {
        history.enumerated().map { index, data in
            ModuleChartDataPoint(
                id: index,
                index: index,
                value: parameter.value(from: data)
            )
        }
    }

    private var lastIndex: Int {
        history.count - 1
    }

    var body: some View {
        Chart(chartData) { point in
            // Area gradient
            AreaMark(
                x: .value("Time", point.index),
                y: .value("Value", point.value)
            )
            .foregroundStyle(
                LinearGradient(
                    colors: [parameter.color.opacity(0.4), parameter.color.opacity(0.1)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .interpolationMethod(.catmullRom)

            // Line
            LineMark(
                x: .value("Time", point.index),
                y: .value("Value", point.value)
            )
            .foregroundStyle(parameter.color)
            .lineStyle(StrokeStyle(lineWidth: 3))
            .interpolationMethod(.catmullRom)

            // Current point (last)
            if point.index == lastIndex {
                PointMark(
                    x: .value("Time", point.index),
                    y: .value("Value", point.value)
                )
                .foregroundStyle(parameter.color)
                .symbolSize(100)
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 5)) { _ in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [5, 5]))
                    .foregroundStyle(Color.white.opacity(0.2))
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 5)) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [5, 5]))
                    .foregroundStyle(Color.white.opacity(0.2))
                AxisValueLabel {
                    if let doubleValue = value.as(Double.self) {
                        Text(String(format: "%.1f", doubleValue))
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
            }
        }
        .chartPlotStyle { plotArea in
            plotArea
                .background(Color.clear)
        }
        .frame(maxWidth: .infinity, minHeight: 220, maxHeight: .infinity)
    }
}

// MARK: - Cell Info Panel
private struct CellInfoDarkPanel: View {
    let data: CellData
    let moduleIndex: Int
    let cellIndex: Int
    @Binding var selectedParameter: CellParameter

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // 헤더 (Cell ID + 날짜)
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Cell #\(String(format: "%03d", moduleIndex * 48 + cellIndex + 1))")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white.opacity(0.9))

                    Text(data.timestamp, format: .dateTime.year().month().day().hour().minute().second())
                        .font(.system(size: 16))
                        .foregroundColor(.white.opacity(0.5))
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundColor(.white.opacity(0.5))
                    .font(.title2)
            }

            // 5개의 캡슐형 메트릭 박스 - 탭 가능
            HStack(spacing: 12) {
                SelectableCellMetricPill(
                    label: "Voltage",
                    value: String(format: "%.0fV", data.voltage),
                    parameter: .voltage,
                    selectedParameter: $selectedParameter
                )
                SelectableCellMetricPill(
                    label: "Current",
                    value: String(format: "%.1fA", data.current),
                    parameter: .current,
                    selectedParameter: $selectedParameter
                )
                SelectableCellMetricPill(
                    label: "Temp",
                    value: String(format: "%.0f°C", data.temp),
                    parameter: .temp,
                    selectedParameter: $selectedParameter
                )
                SelectableCellMetricPill(
                    label: "SOC",
                    value: String(format: "%.0f%%", data.soc),
                    parameter: .soc,
                    selectedParameter: $selectedParameter
                )
                SelectableCellMetricPill(
                    label: "SOH",
                    value: String(format: "%.0f%%", data.soh),
                    parameter: .soh,
                    selectedParameter: $selectedParameter
                )
            }
        }
        .padding(25)
        .background(Color.black.opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: 25))
    }
}

// 선택 가능한 셀 메트릭 필
private struct SelectableCellMetricPill: View {
    let label: String
    let value: String
    let parameter: CellParameter
    @Binding var selectedParameter: CellParameter

    private var isSelected: Bool {
        selectedParameter == parameter
    }

    var body: some View {
        Button {
            DispatchQueue.main.async {
                if selectedParameter == parameter {
                    selectedParameter = .none
                } else {
                    selectedParameter = parameter
                }
            }
        } label: {
            VStack(spacing: 8) {
                Text(label)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(isSelected ? .white : .white.opacity(0.6))

                Text(value)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(isSelected ? parameter.color : .white)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? parameter.color.opacity(0.3) : Color.white.opacity(0.1))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(isSelected ? parameter.color : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Cell Multi Line Plot Panel (선택한 셀의 여러 지표를 멀티라인으로 표시)
private struct CellMultiLinePlotPanel: View {
    @ObservedObject var rackModel: RackSystemModel
    let moduleIndex: Int
    let cellIndex: Int

    var cellHistory: [CellData] {
        rackModel.cellHistory(moduleIndex: moduleIndex, cellIndex: cellIndex)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            // 헤더
            HStack {
                Text("Cell Multi Line Plot")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(.white.opacity(0.8))

                Spacer()

                Text("Cell #\(String(format: "%03d", moduleIndex * 48 + cellIndex + 1))")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.5))

                Image(systemName: "info.circle")
                    .font(.title2)
                    .foregroundColor(.white.opacity(0.5))
            }

            // 멀티라인 차트 (Voltage, Temp, SOC)
            CellMultiMetricChart(history: cellHistory)
        }
        .padding(25)
        .frame(minHeight: 380, maxHeight: 480)
        .background(Color.black.opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: 25))
    }
}

// Cell Multi Metric Chart용 데이터 포인트
private struct CellMetricDataPoint: Identifiable {
    let id: String
    let metric: String
    let timeIndex: Int
    let value: Double
    let normalizedValue: Double  // 0~1 범위로 정규화된 값
}

// Cell Multi Metric Chart (한 셀의 Voltage, Temp, SOC를 멀티라인으로)
private struct CellMultiMetricChart: View {
    let history: [CellData]

    private let metricColors: [String: Color] = [
        "Voltage": .cyan,
        "Temp": .orange,
        "SOC": .green
    ]

    // 각 지표를 0~1 범위로 정규화하여 같은 차트에 표시
    private var chartData: [CellMetricDataPoint] {
        var points: [CellMetricDataPoint] = []

        // 각 지표별 min/max 계산
        let voltages = history.map { $0.voltage }
        let temps = history.map { $0.temp }
        let socs = history.map { $0.soc }

        let vMin = voltages.min() ?? 0
        let vMax = voltages.max() ?? 1
        let vRange = max(vMax - vMin, 0.001)

        let tMin = temps.min() ?? 0
        let tMax = temps.max() ?? 1
        let tRange = max(tMax - tMin, 0.001)

        let sMin = socs.min() ?? 0
        let sMax = socs.max() ?? 1
        let sRange = max(sMax - sMin, 0.001)

        for (timeIndex, data) in history.enumerated() {
            // Voltage
            points.append(CellMetricDataPoint(
                id: "Voltage-\(timeIndex)",
                metric: "Voltage",
                timeIndex: timeIndex,
                value: data.voltage,
                normalizedValue: (data.voltage - vMin) / vRange
            ))
            // Temp
            points.append(CellMetricDataPoint(
                id: "Temp-\(timeIndex)",
                metric: "Temp",
                timeIndex: timeIndex,
                value: data.temp,
                normalizedValue: (data.temp - tMin) / tRange
            ))
            // SOC
            points.append(CellMetricDataPoint(
                id: "SOC-\(timeIndex)",
                metric: "SOC",
                timeIndex: timeIndex,
                value: data.soc,
                normalizedValue: (data.soc - sMin) / sRange
            ))
        }
        return points
    }

    // 각 지표의 현재 값 (마지막 데이터)
    private var currentValues: (voltage: Double, temp: Double, soc: Double)? {
        guard let last = history.last else { return nil }
        return (last.voltage, last.temp, last.soc)
    }

    var body: some View {
        VStack(spacing: 12) {
            // 현재 값 표시 범례
            if let current = currentValues {
                HStack(spacing: 20) {
                    LegendValueItem(label: "Voltage", value: String(format: "%.1fV", current.voltage), color: .cyan)
                    LegendValueItem(label: "Temp", value: String(format: "%.1f°C", current.temp), color: .orange)
                    LegendValueItem(label: "SOC", value: String(format: "%.1f%%", current.soc), color: .green)
                }
            }

            // 차트
            Chart(chartData) { point in
                LineMark(
                    x: .value("Time", point.timeIndex),
                    y: .value("Value", point.normalizedValue),
                    series: .value("Metric", point.metric)
                )
                .foregroundStyle(by: .value("Metric", point.metric))
                .lineStyle(StrokeStyle(lineWidth: 2.5))
                .interpolationMethod(.catmullRom)
            }
            .chartYScale(domain: -0.1...1.1)
            .chartForegroundStyleScale([
                "Voltage": Color.cyan,
                "Temp": Color.orange,
                "SOC": Color.green
            ])
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 5)) { _ in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [5, 5]))
                        .foregroundStyle(Color.white.opacity(0.2))
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading, values: [0, 0.25, 0.5, 0.75, 1.0]) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [5, 5]))
                        .foregroundStyle(Color.white.opacity(0.2))
                    AxisValueLabel {
                        if let doubleValue = value.as(Double.self) {
                            Text(String(format: "%.0f%%", doubleValue * 100))
                                .font(.system(size: 10))
                                .foregroundColor(.white.opacity(0.5))
                        }
                    }
                }
            }
            .chartLegend(.hidden)
            .frame(maxWidth: .infinity, minHeight: 280, maxHeight: 350)
        }
    }
}

// 범례 아이템 (현재 값 표시)
private struct LegendValueItem: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.6))
            Text(value)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(color)
        }
    }
}

// MARK: - Cell Parameter Stream Graph Panel
private struct CellParameterStreamGraphPanel: View {
    let parameter: CellParameter
    let history: [CellData]

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // 헤더
            HStack {
                Text(parameter.graphTitle)
                    .font(.system(size: 22, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))

                Spacer()

                // 현재 값 표시
                if let latest = history.last {
                    let value = parameter.value(from: latest)
                    Text(String(format: "%.2f%@", value, parameter.unit))
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(parameter.color)
                }
            }

            // 스트림 그래프
            CellStreamGraph(parameter: parameter, history: history)
        }
        .padding(25)
        .frame(minHeight: 300, maxHeight: 400)
        .background(Color.black.opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: 25))
    }
}

// Chart용 Cell 데이터 포인트
private struct CellChartDataPoint: Identifiable {
    let id: Int
    let index: Int
    let value: Double
}

// Cell용 스트림 그래프
private struct CellStreamGraph: View {
    let parameter: CellParameter
    let history: [CellData]

    // 미리 계산된 데이터 포인트
    private var chartData: [CellChartDataPoint] {
        history.enumerated().map { index, data in
            CellChartDataPoint(
                id: index,
                index: index,
                value: parameter.value(from: data)
            )
        }
    }

    private var lastIndex: Int {
        history.count - 1
    }

    var body: some View {
        Chart(chartData) { point in
            // Area gradient
            AreaMark(
                x: .value("Time", point.index),
                y: .value("Value", point.value)
            )
            .foregroundStyle(
                LinearGradient(
                    colors: [parameter.color.opacity(0.4), parameter.color.opacity(0.1)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .interpolationMethod(.catmullRom)

            // Line
            LineMark(
                x: .value("Time", point.index),
                y: .value("Value", point.value)
            )
            .foregroundStyle(parameter.color)
            .lineStyle(StrokeStyle(lineWidth: 3))
            .interpolationMethod(.catmullRom)

            // Current point (last)
            if point.index == lastIndex {
                PointMark(
                    x: .value("Time", point.index),
                    y: .value("Value", point.value)
                )
                .foregroundStyle(parameter.color)
                .symbolSize(100)
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 5)) { _ in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [5, 5]))
                    .foregroundStyle(Color.white.opacity(0.2))
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 5)) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [5, 5]))
                    .foregroundStyle(Color.white.opacity(0.2))
                AxisValueLabel {
                    if let doubleValue = value.as(Double.self) {
                        Text(String(format: "%.1f", doubleValue))
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
            }
        }
        .chartPlotStyle { plotArea in
            plotArea
                .background(Color.clear)
        }
        .frame(maxWidth: .infinity, minHeight: 180, maxHeight: .infinity)
    }
}

// MARK: - 3. Bottom Tab Bar
private struct BottomTabBar: View {
    @Binding var selectedTab: Int

    var body: some View {
        HStack(spacing: 8) {
            TabButton(title: "Rack", isSelected: selectedTab == 0) {
                selectedTab = 0
            }
            TabButton(title: "Module", isSelected: selectedTab == 1) {
                selectedTab = 1
            }
            TabButton(title: "Cell", isSelected: selectedTab == 2) {
                selectedTab = 2
            }
        }
        .padding(12)
        .background(.regularMaterial)
        .clipShape(Capsule())
        .shadow(radius: 15)
    }
}

private struct TabButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(isSelected ? .white : .white.opacity(0.6))
                .frame(width: 180, height: 70)
                .background(isSelected ? Color.blue.opacity(0.5) : Color.white.opacity(0.1))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    RackDataPanel(
        rackModel: RackSystemModel(),
        selectedTab: .constant(0),
        selectedModuleIndex: .constant(0)
    )
}
