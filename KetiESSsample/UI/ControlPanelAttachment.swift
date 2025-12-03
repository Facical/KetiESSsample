// KetiESSsample/UI/ControlPanelAttachment.swift

import SwiftUI

/// 3D 공간에 배치되는 컨트롤 패널 (MainView 역할 대체)
struct ControlPanelAttachment: View {
    // Binding to RackView states
    @Binding var isPlaced: Bool
    @Binding var showCallouts: Bool
    @Binding var showProblemAnalysis: Bool  // 문제 분석 모드
    @Binding var isObjectTracking: Bool     // Object Tracking 모드

    // Callbacks
    var onPlaceHere: () -> Void
    var onResetModules: () -> Void
    var onReposition: () -> Void
    var onCloseXR: () -> Void
    var onToggleObjectTracking: () -> Void  // Object Tracking 토글

    // Module info
    var moduleCount: Int
    var pulledOutCount: Int
    var problemModuleCount: Int  // 문제가 있는 모듈 수

    var body: some View {
        VStack(spacing: 24) {
            // Header
            headerSection

            Divider()
                .background(Color.white.opacity(0.3))

            if !isPlaced {
                // Placement mode
                placementSection
            } else {
                // Control mode
                controlSection
            }

            Divider()
                .background(Color.white.opacity(0.3))

            // Footer - Close button
            footerSection
        }
        .padding(24)
        .frame(width: 400)
        .background(.ultraThickMaterial, in: RoundedRectangle(cornerRadius: 24))
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .strokeBorder(
                    LinearGradient(
                        colors: [.blue.opacity(0.5), .cyan.opacity(0.3)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 2
                )
        )
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: 8) {
            Image(systemName: "battery.100.bolt")
                .font(.system(size: 40))
                .foregroundStyle(.linearGradient(
                    colors: [.blue, .green],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))

            Text("ESS Control System")
                .font(.title2)
                .fontWeight(.bold)

            Text("Energy Storage System Management")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Placement Section

    private var placementSection: some View {
        VStack(spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: isObjectTracking ? "cube.transparent" : "hand.point.up.left.fill")
                    .font(.title)
                    .foregroundColor(isObjectTracking ? .green : .blue)
                    .symbolEffect(.pulse)

                VStack(alignment: .leading, spacing: 4) {
                    Text(isObjectTracking ? "Scanning for ESS..." : "Position the Rack")
                        .font(.headline)
                    Text(isObjectTracking ? "Looking for real ESS rack" : "Drag the model or use Object Tracking")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            // Object Tracking 버튼 (항상 표시)
            Button(action: onToggleObjectTracking) {
                    HStack {
                        Image(systemName: isObjectTracking ? "cube.fill" : "cube.transparent")
                            .font(.title3)
                            .foregroundColor(isObjectTracking ? .white : .green)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Object Tracking")
                                .font(.subheadline)
                                .fontWeight(.bold)
                            Text(isObjectTracking ? "Detecting real ESS rack..." : "Snap to real ESS rack")
                                .font(.caption2)
                                .opacity(0.8)
                        }

                        Spacer()

                        // Toggle indicator
                        if isObjectTracking {
                            ProgressView()
                                .progressViewStyle(.circular)
                                .scaleEffect(0.8)
                                .tint(.white)
                        } else {
                            Image(systemName: "circle")
                                .font(.title2)
                                .foregroundColor(.gray)
                        }
                    }
                    .foregroundColor(isObjectTracking ? .white : .primary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(
                        Group {
                            if isObjectTracking {
                                LinearGradient(
                                    colors: [.green, .teal],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            } else {
                                Color.clear
                            }
                        }
                    )
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(
                                isObjectTracking ? Color.clear : Color.green.opacity(0.5),
                                lineWidth: 2
                            )
                    )
                }
            .buttonStyle(.plain)

            Button(action: onPlaceHere) {
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                    Text("Place Here")
                        .font(.headline)
                        .fontWeight(.bold)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    LinearGradient(
                        colors: [.blue, .cyan],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(Capsule())
                .shadow(color: .blue.opacity(0.5), radius: 10)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Control Section

    private var controlSection: some View {
        VStack(spacing: 16) {
            // Status info
            HStack(spacing: 12) {
                StatusBadge(
                    icon: "server.rack",
                    label: "Modules",
                    value: "\(moduleCount)"
                )

                StatusBadge(
                    icon: "tray.and.arrow.up",
                    label: "Pulled Out",
                    value: "\(pulledOutCount)"
                )

                StatusBadge(
                    icon: "exclamationmark.triangle.fill",
                    label: "Problems",
                    value: "\(problemModuleCount)",
                    iconColor: problemModuleCount > 0 ? .red : .green
                )
            }

            // Problem Analysis Toggle (스위치 UI)
            HStack {
                Image(systemName: "waveform.path.ecg.rectangle")
                    .font(.title3)
                    .foregroundColor(.orange)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Problem Analysis")
                        .font(.subheadline)
                        .fontWeight(.bold)
                    Text(showProblemAnalysis ? "Highlighting problem modules" : "Show module health status")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Toggle("", isOn: $showProblemAnalysis)
                    .toggleStyle(SwitchToggleStyle(tint: .orange))
                    .labelsHidden()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Color.orange.opacity(0.3), lineWidth: 1)
            )

            // Color Legend (문제 분석 모드일 때만 표시)
            if showProblemAnalysis {
                colorLegend
            }

            // Other Control buttons
            VStack(spacing: 10) {
                // Show/Hide Labels
                Button(action: { showCallouts.toggle() }) {
                    HStack {
                        Image(systemName: showCallouts ? "eye.slash.fill" : "eye.fill")
                            .font(.body)
                        Text(showCallouts ? "Hide Labels" : "Show Labels")
                            .font(.caption)
                            .fontWeight(.medium)
                        Spacer()
                    }
                    .foregroundColor(.primary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)

                HStack(spacing: 10) {
                    // Reset Modules
                    Button(action: onResetModules) {
                        HStack {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.body)
                            Text("Reset")
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(.regularMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)

                    // Reposition
                    Button(action: onReposition) {
                        HStack {
                            Image(systemName: "arrow.up.and.down.and.arrow.left.and.right")
                                .font(.body)
                            Text("Reposition")
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(.regularMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }
            }

            // Module interaction hint
            HStack(spacing: 8) {
                Image(systemName: "hand.pinch.fill")
                    .font(.caption)
                    .foregroundColor(.blue)
                Text("Tap or pinch modules to inspect")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 4)
        }
    }

    // MARK: - Color Legend

    private var colorLegend: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Module Status")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)

            HStack(spacing: 16) {
                LegendItem(color: .red, label: "Critical")
                LegendItem(color: .orange, label: "Warning")
                LegendItem(color: .clear, label: "Normal", isOutline: true)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.black.opacity(0.2))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Footer Section

    private var footerSection: some View {
        Button(action: onCloseXR) {
            HStack(spacing: 8) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                Text("Close XR View")
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .foregroundColor(.red)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(.red.opacity(0.15))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Status Badge Component

private struct StatusBadge: View {
    let icon: String
    let label: String
    let value: String
    var iconColor: Color = .blue

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(iconColor)

            Text(value)
                .font(.headline)
                .fontWeight(.bold)

            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Legend Item Component

private struct LegendItem: View {
    let color: Color
    let label: String
    var isOutline: Bool = false

    var body: some View {
        HStack(spacing: 6) {
            if isOutline {
                Circle()
                    .strokeBorder(Color.gray, lineWidth: 2)
                    .frame(width: 12, height: 12)
            } else {
                Circle()
                    .fill(color)
                    .frame(width: 12, height: 12)
            }

            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
}

#Preview {
    VStack(spacing: 40) {
        // Placement mode - Object Tracking OFF
        ControlPanelAttachment(
            isPlaced: .constant(false),
            showCallouts: .constant(false),
            showProblemAnalysis: .constant(false),
            isObjectTracking: .constant(false),
            onPlaceHere: {},
            onResetModules: {},
            onReposition: {},
            onCloseXR: {},
            onToggleObjectTracking: {},
            moduleCount: 11,
            pulledOutCount: 0,
            problemModuleCount: 1
        )

        // Placement mode - Object Tracking ON
        ControlPanelAttachment(
            isPlaced: .constant(false),
            showCallouts: .constant(false),
            showProblemAnalysis: .constant(false),
            isObjectTracking: .constant(true),
            onPlaceHere: {},
            onResetModules: {},
            onReposition: {},
            onCloseXR: {},
            onToggleObjectTracking: {},
            moduleCount: 11,
            pulledOutCount: 0,
            problemModuleCount: 1
        )

        // Control mode - Analysis ON
        ControlPanelAttachment(
            isPlaced: .constant(true),
            showCallouts: .constant(true),
            showProblemAnalysis: .constant(true),
            isObjectTracking: .constant(false),
            onPlaceHere: {},
            onResetModules: {},
            onReposition: {},
            onCloseXR: {},
            onToggleObjectTracking: {},
            moduleCount: 11,
            pulledOutCount: 2,
            problemModuleCount: 1
        )
    }
    .padding()
    .background(Color.black)
}
