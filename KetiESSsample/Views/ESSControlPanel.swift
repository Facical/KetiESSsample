// KetiESSsample/Views/ESSControlPanel.swift

import SwiftUI
import Charts

struct ESSControlPanel: View {
    @ObservedObject var systemModel: ESSSystemModel
    @State private var selectedTab = 0
    
    var body: some View {
        VStack(spacing: 20) {
            // Header with System Status
            HStack {
                VStack(alignment: .leading) {
                    Text("ESS System Dashboard")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    Text("Real-time Monitoring")
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                // System Status Indicator
                HStack(spacing: 20) {
                    StatusIndicator(
                        title: "System",
                        value: "Online",
                        color: .green
                    )
                    StatusIndicator(
                        title: "Efficiency",
                        value: String(format: "%.1f%%", systemModel.systemEfficiency),
                        color: .blue
                    )
                }
            }
            .padding()
            
            // Tab Selection
            Picker("View", selection: $selectedTab) {
                Text("Overview").tag(0)
                Text("Power").tag(1)
                Text("Modules").tag(2)
                Text("Analytics").tag(3)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            
            // Content based on selected tab
            ScrollView {
                switch selectedTab {
                case 0:
                    OverviewTab(systemModel: systemModel)
                case 1:
                    PowerTab(systemModel: systemModel)
                case 2:
                    ModulesTab(systemModel: systemModel)
                case 3:
                    AnalyticsTab(systemModel: systemModel)
                default:
                    OverviewTab(systemModel: systemModel)
                }
            }
        }
        .frame(minWidth: 900, idealWidth: 1000, maxWidth: .infinity,
               minHeight: 700, idealHeight: 800, maxHeight: .infinity)
        .background(.regularMaterial)
    }
}

// Overview Tab
struct OverviewTab: View {
    @ObservedObject var systemModel: ESSSystemModel
    
    var body: some View {
        VStack(spacing: 20) {
            // Key Metrics
            HStack(spacing: 15) {
                MetricCard(
                    icon: "bolt.fill",
                    title: "Total Power",
                    value: String(format: "%.2f kW", systemModel.totalPower),
                    color: .blue
                )
                MetricCard(
                    icon: "battery.75",
                    title: "Energy Stored",
                    value: String(format: "%.1f kWh", systemModel.totalEnergy),
                    color: .green
                )
                MetricCard(
                    icon: "thermometer.medium",
                    title: "Temperature",
                    value: String(format: "%.1f°C", systemModel.systemTemperature),
                    color: systemModel.systemTemperature > 35 ? .orange : .blue
                )
            }
            .padding(.horizontal)
            
            // Real-time Power Chart
            VStack(alignment: .leading) {
                Text("Power Output (Real-time)")
                    .font(.headline)
                    .padding(.horizontal)
                
                Chart {
                    ForEach(Array(systemModel.powerHistory.enumerated()), id: \.offset) { index, power in
                        LineMark(
                            x: .value("Time", index),
                            y: .value("Power", power)
                        )
                        .foregroundStyle(.blue)
                        .interpolationMethod(.catmullRom)
                        
                        AreaMark(
                            x: .value("Time", index),
                            y: .value("Power", power)
                        )
                        .foregroundStyle(.linearGradient(
                            colors: [.blue.opacity(0.3), .blue.opacity(0.1)],
                            startPoint: .top,
                            endPoint: .bottom
                        ))
                        .interpolationMethod(.catmullRom)
                    }
                }
                .frame(height: 200)
                .padding()
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal)
            }
            
            // Module Status Grid
            VStack(alignment: .leading) {
                Text("Battery Modules Status")
                    .font(.headline)
                    .padding(.horizontal)
                
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 10) {
                    ForEach(systemModel.modules) { module in
                        ModuleStatusView(module: module)
                    }
                }
                .padding()
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal)
            }
        }
        .padding(.vertical)
    }
}

// Power Tab
struct PowerTab: View {
    @ObservedObject var systemModel: ESSSystemModel
    
    var body: some View {
        VStack(spacing: 20) {
            // Power Flow Diagram
            HStack(spacing: 30) {
                PowerFlowCard(
                    title: "Input",
                    value: systemModel.inputPower,
                    icon: "arrow.right.circle.fill",
                    color: .blue
                )
                
                Image(systemName: "arrow.right")
                    .font(.title)
                    .foregroundStyle(.secondary)
                
                PowerFlowCard(
                    title: "ESS",
                    value: systemModel.totalPower,
                    icon: "battery.100.bolt",
                    color: .green
                )
                
                Image(systemName: "arrow.right")
                    .font(.title)
                    .foregroundStyle(.secondary)
                
                PowerFlowCard(
                    title: "Output",
                    value: systemModel.outputPower,
                    icon: "arrow.right.circle",
                    color: .orange
                )
            }
            .padding()
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal)
            
            // Voltage Chart
            VStack(alignment: .leading) {
                Text("Voltage Trend")
                    .font(.headline)
                
                Chart {
                    ForEach(Array(systemModel.voltageHistory.enumerated()), id: \.offset) { index, voltage in
                        LineMark(
                            x: .value("Time", index),
                            y: .value("Voltage", voltage)
                        )
                        .foregroundStyle(.green)
                        .interpolationMethod(.catmullRom)
                    }
                }
                .frame(height: 200)
                .padding()
            }
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal)
        }
        .padding(.vertical)
    }
}

// Modules Tab
struct ModulesTab: View {
    @ObservedObject var systemModel: ESSSystemModel
    
    var body: some View {
        VStack(spacing: 20) {
            ForEach(systemModel.modules) { module in
                ModuleDetailCard(module: module)
            }
        }
        .padding()
    }
}

// Analytics Tab
struct AnalyticsTab: View {
    @ObservedObject var systemModel: ESSSystemModel
    
    var body: some View {
        VStack(spacing: 20) {
            // Temperature Trend
            VStack(alignment: .leading) {
                Text("Temperature Analysis")
                    .font(.headline)
                
                Chart {
                    ForEach(Array(systemModel.temperatureHistory.enumerated()), id: \.offset) { index, temp in
                        LineMark(
                            x: .value("Time", index),
                            y: .value("Temperature", temp)
                        )
                        .foregroundStyle(.orange)
                        .interpolationMethod(.catmullRom)
                        
                        RuleMark(y: .value("Threshold", 35))
                            .foregroundStyle(.red.opacity(0.3))
                            .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 5]))
                    }
                }
                .frame(height: 200)
                .padding()
            }
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal)
            
            // Efficiency Analysis
            HStack(spacing: 20) {
                GaugeView(
                    value: systemModel.systemEfficiency,
                    title: "System Efficiency",
                    maxValue: 100,
                    unit: "%"
                )
                
                VStack(alignment: .leading, spacing: 10) {
                    Text("Efficiency Factors")
                        .font(.headline)
                    
                    EfficiencyFactor(name: "Conversion Loss", value: 2.5, isNegative: true)
                    EfficiencyFactor(name: "Heat Dissipation", value: 1.8, isNegative: true)
                    EfficiencyFactor(name: "Power Factor", value: 0.98, isNegative: false)
                    EfficiencyFactor(name: "Module Health", value: 96.5, isNegative: false)
                }
                .padding()
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal)
        }
        .padding(.vertical)
    }
}

// Helper Views
struct StatusIndicator: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .trailing) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack {
                Circle()
                    .fill(color)
                    .frame(width: 8, height: 8)
                Text(value)
                    .font(.headline)
            }
        }
    }
}

struct MetricCard: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(color)
                Spacer()
            }
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct ModuleStatusView: View {
    let module: BatteryModule
    
    var body: some View {
        VStack {
            Circle()
                .fill(module.status.color)
                .frame(width: 50, height: 50)
                .overlay(
                    Text("M\(module.position + 1)")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                )
            Text("\(Int(module.soc))%")
                .font(.caption2)
        }
    }
}

struct ModuleDetailCard: View {
    let module: BatteryModule
    
    var body: some View {
        HStack {
            Circle()
                .fill(module.status.color)
                .frame(width: 40, height: 40)
                .overlay(
                    Text("M\(module.position + 1)")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                )
            
            VStack(alignment: .leading) {
                Text("Module \(module.position + 1)")
                    .font(.headline)
                HStack {
                    Label(String(format: "%.1fV", module.voltage), systemImage: "bolt")
                    Label(String(format: "%.1fA", module.current), systemImage: "arrow.right.arrow.left")
                    Label(String(format: "%.1f°C", module.temperature), systemImage: "thermometer")
                    Label(String(format: "%.0f%%", module.soc), systemImage: "battery.75")
                }
                .font(.caption)
            }
            
            Spacer()
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

struct PowerFlowCard: View {
    let title: String
    let value: Double
    let icon: String
    let color: Color
    
    var body: some View {
        VStack {
            Image(systemName: icon)
                .font(.largeTitle)
                .foregroundStyle(color)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(String(format: "%.2f kW", value))
                .font(.title3)
                .fontWeight(.bold)
        }
        .padding()
    }
}

struct GaugeView: View {
    let value: Double
    let title: String
    let maxValue: Double
    let unit: String
    
    var body: some View {
        VStack {
            Text(title)
                .font(.headline)
            
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 20)
                
                Circle()
                    .trim(from: 0, to: value / maxValue)
                    .stroke(
                        LinearGradient(
                            colors: [.green, .blue],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        style: StrokeStyle(lineWidth: 20, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                
                VStack {
                    Text(String(format: "%.1f", value))
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    Text(unit)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 150, height: 150)
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct EfficiencyFactor: View {
    let name: String
    let value: Double
    let isNegative: Bool
    
    var body: some View {
        HStack {
            Text(name)
                .font(.caption)
            Spacer()
            Text(String(format: "%.1f%s", value, isNegative ? "%" : "%"))
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(isNegative ? .red : .green)
        }
    }
}
