// KetiESSsample/Views/RackDataPanel.swift

import SwiftUI
import Charts

struct RackDataPanel: View {
    @ObservedObject var rackModel: RackSystemModel
    @State private var selectedTab = 0

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Rack#001")
                    .font(.title2)
                    .fontWeight(.bold)
                Spacer()
            }
            .padding()
            .background(.ultraThinMaterial)

            // Operation Info Display (Yellow Section)
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("운용 정보 디스플레이")
                        .font(.headline)
                        .fontWeight(.bold)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundStyle(.secondary)
                }

                if let rackData = rackModel.currentRackData {
                    // Date/Time
                    Text(rackData.timestamp, style: .date)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.bottom, 4)

                    // Metrics Grid
                    HStack(spacing: 12) {
                        MetricBox(
                            label: "System Bus\nVoltage",
                            value: String(format: "%.1fV", rackData.systemBusVoltage)
                        )
                        MetricBox(
                            label: "System Bus\nCurrent",
                            value: String(format: "%.1fA", rackData.systemBusCurrent)
                        )
                        MetricBox(
                            label: "System online\nSOC",
                            value: String(format: "%.0f%%", rackData.systemOnlineSOC)
                        )
                        MetricBox(
                            label: "System online\nSOH",
                            value: String(format: "%.0f%%", rackData.systemOnlineSOH)
                        )
                    }
                }
            }
            .padding()
            .background(Color.yellow.opacity(0.3))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding()

            // Tab Content
            if selectedTab == 0 {
                // SoC Hitmap
                SoCHitmapView(rackModel: rackModel)
                    .padding(.horizontal)
            } else if selectedTab == 1 {
                // Module view
                Text("Module View")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding()
            } else {
                // Cell view
                Text("Cell View")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding()
            }

            Spacer()

            // Bottom Tabs
            HStack(spacing: 0) {
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
            .padding(.horizontal)
            .padding(.bottom, 16)
        }
        .frame(width: 600, height: 700)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
}

// MARK: - Metric Box
struct MetricBox: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            Text(value)
                .font(.title3)
                .fontWeight(.bold)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(.white.opacity(0.8))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - SoC Hitmap View
struct SoCHitmapView: View {
    @ObservedObject var rackModel: RackSystemModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("SoC Hitmap")
                    .font(.headline)
                Spacer()
                Image(systemName: "info.circle")
                    .foregroundStyle(.secondary)
            }

            // Time range selector
            HStack {
                Spacer()
                Text("최근 3일")
                    .font(.caption)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                Spacer()
                Text("1주일")
                    .font(.caption)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.clear)
                Spacer()
                Text("지정 기간")
                    .font(.caption)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.clear)
                Spacer()
            }
            .padding(.vertical, 4)

            // Chart
            if !rackModel.moduleData.isEmpty {
                Chart {
                    ForEach(Array(rackModel.rackDataHistory.enumerated()), id: \.offset) { index, data in
                        // Draw lines for each module (7 modules)
                        ForEach(0..<min(7, rackModel.moduleData.count), id: \.self) { moduleIndex in
                            if moduleIndex < rackModel.moduleData.count {
                                LineMark(
                                    x: .value("Time", index),
                                    y: .value("SOC", rackModel.moduleData[moduleIndex].soc)
                                )
                                .foregroundStyle(by: .value("Module", "#\(String(format: "%02d", moduleIndex + 1))"))
                                .lineStyle(StrokeStyle(lineWidth: 2))
                            }
                        }
                    }
                }
                .chartYScale(domain: 80...100)
                .chartYAxis {
                    AxisMarks(position: .leading)
                }
                .chartXAxis {
                    AxisMarks { value in
                        if let index = value.as(Int.self) {
                            AxisValueLabel {
                                if index % 10 == 0 {
                                    Text("")
                                }
                            }
                            AxisGridLine()
                        }
                    }
                }
                .frame(height: 220)
                .padding()
                .background(.black.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                Rectangle()
                    .fill(.black.opacity(0.05))
                    .frame(height: 220)
                    .overlay(
                        Text("Loading data...")
                            .foregroundStyle(.secondary)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            // Module labels
            HStack(spacing: 8) {
                ForEach(1...7, id: \.self) { num in
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.accentColor)
                            .frame(width: 8, height: 8)
                        Text("#\(String(format: "%02d", num))")
                            .font(.caption2)
                    }
                }
            }
        }
    }
}

// MARK: - Tab Button
struct TabButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .foregroundColor(isSelected ? .white : .secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(isSelected ? Color.accentColor : Color.clear)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    RackDataPanel(rackModel: RackSystemModel())
        .glassBackgroundEffect()
}
