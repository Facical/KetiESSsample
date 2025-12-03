// KetiESSsample/Views/MainView.swift

import SwiftUI

struct MainView: View {
    @Environment(\.openImmersiveSpace) var openImmersiveSpace
    @Environment(\.dismissImmersiveSpace) var dismissImmersiveSpace
    @Environment(\.dismissWindow) var dismissWindow
    @State private var immersiveSpaceIsShown = false

    var body: some View {
        VStack(spacing: 30) {
            // Header
            VStack(spacing: 10) {
                Image(systemName: "battery.100.bolt")
                    .font(.system(size: 60))
                    .foregroundStyle(.linearGradient(
                        colors: [.blue, .green],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))

                Text("ESS Control System")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Energy Storage System Management")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 40)

            // Main ESS Rack XR Visualization
            VStack(spacing: 20) {
                Button(action: {
                    Task {
                        // Dismiss any other spaces first
                        await dismissImmersiveSpace()
                        try? await Task.sleep(nanoseconds: 100_000_000)

                        // Open RackView
                        let result = await openImmersiveSpace(id: "RackView")

                        switch result {
                        case .opened:
                            immersiveSpaceIsShown = true
                            // 윈도우 자동 닫기 (컨트롤은 3D Attachment에서 처리)
                            dismissWindow(id: "MainWindow")
                        case .userCancelled, .error:
                            immersiveSpaceIsShown = false
                        @unknown default:
                            immersiveSpaceIsShown = false
                        }
                    }
                }) {
                    VStack(spacing: 15) {
                        Image(systemName: "server.rack")
                            .font(.system(size: 60))
                            .foregroundStyle(.linearGradient(
                                colors: [.green, .cyan],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ))

                        Text("View ESS Rack in AR")
                            .font(.title)
                            .fontWeight(.bold)

                        Text("3D Model with Real-time Data Panel")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [.green.opacity(0.5), .cyan.opacity(0.5)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 2
                            )
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal)

            Spacer()

            // Footer Info
            HStack {
                Label("System Online", systemImage: "circle.fill")
                    .font(.caption)
                    .foregroundStyle(.green)

                Spacer()

                Text("KETI ESS v1.0")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
        .frame(width: 1200, height: 900)
    }
}

#Preview {
    MainView()
}
