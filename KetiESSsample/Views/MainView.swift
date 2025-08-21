// KetiESSsample/Views/MainView.swift

import SwiftUI

struct MainView: View {
    @Environment(\.openImmersiveSpace) var openImmersiveSpace
    @Environment(\.dismissImmersiveSpace) var dismissImmersiveSpace
    @State private var showingSampleModels = false
    @State private var essSystemModel = ESSSystemModel()
    @State private var immersiveSpaceIsShown = false
    
    var body: some View {
        NavigationStack {
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
                
                // Main ESS Control Button
                VStack(spacing: 20) {
                    Button(action: {
                        Task {
                            if immersiveSpaceIsShown {
                                await dismissImmersiveSpace()
                                immersiveSpaceIsShown = false
                            } else {
                                await openImmersiveSpace(id: "ESSView")
                                immersiveSpaceIsShown = true
                            }
                        }
                    }) {
                        VStack(spacing: 15) {
                            Image(systemName: immersiveSpaceIsShown ? "cube.fill" : "cube")
                                .font(.system(size: 50))
                                .symbolEffect(.pulse, value: immersiveSpaceIsShown)
                            
                            Text(immersiveSpaceIsShown ? "Close ESS View" : "Open ESS Control View")
                                .font(.title2)
                                .fontWeight(.semibold)
                            
                            Text("View 3D ESS Cabinet with Real-time Monitoring")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 30)
                        .background(.regularMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .strokeBorder(
                                    LinearGradient(
                                        colors: [.blue.opacity(0.5), .green.opacity(0.5)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 2
                                )
                        )
                    }
                    .buttonStyle(.plain)
                    .scaleEffect(immersiveSpaceIsShown ? 0.95 : 1.0)
                    .animation(.easeInOut, value: immersiveSpaceIsShown)
                    
                    // ESS Control Panel Navigation
                    NavigationLink(destination: ESSControlPanel(systemModel: essSystemModel)
                        .frame(minWidth: 900, minHeight: 700)) {
                        HStack {
                            Image(systemName: "chart.line.uptrend.xyaxis")
                                .font(.title2)
                            
                            VStack(alignment: .leading) {
                                Text("System Dashboard")
                                    .font(.headline)
                                Text("Real-time monitoring & analytics")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .foregroundStyle(.secondary)
                        }
                        .padding()
                        .background(.regularMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 15))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal)
                
                // Sample Models Section
                VStack(alignment: .leading, spacing: 15) {
                    Button(action: {
                        withAnimation(.spring()) {
                            showingSampleModels.toggle()
                        }
                    }) {
                        HStack {
                            Image(systemName: showingSampleModels ? "chevron.down.circle.fill" : "chevron.right.circle")
                                .font(.title3)
                            
                            Text("Sample Models")
                                .font(.headline)
                            
                            Spacer()
                            
                            Text("Demo")
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(.blue.opacity(0.2))
                                .clipShape(Capsule())
                        }
                        .padding()
                        .background(.regularMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                    
                    if showingSampleModels {
                        HStack(spacing: 15) {
                            // Uracan Button
                            Button(action: {
                                Task {
                                    await dismissImmersiveSpace()
                                    immersiveSpaceIsShown = false
                                    await openImmersiveSpace(id: "CarView")
                                }
                            }) {
                                VStack {
                                    Image(systemName: "car.fill")
                                        .font(.title)
                                    Text("Uracan")
                                        .font(.caption)
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(.blue.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                            .buttonStyle(.plain)
                            
                            // Turbine Button
                            Button(action: {
                                Task {
                                    await dismissImmersiveSpace()
                                    immersiveSpaceIsShown = false
                                    await openImmersiveSpace(id: "TurbineView")
                                }
                            }) {
                                VStack {
                                    Image(systemName: "fan.fill")
                                        .font(.title)
                                    Text("Turbine")
                                        .font(.caption)
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(.green.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal)
                        .transition(.asymmetric(
                            insertion: .move(edge: .top).combined(with: .opacity),
                            removal: .move(edge: .top).combined(with: .opacity)
                        ))
                    }
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
            .navigationTitle("")
            .navigationBarHidden(true)
        }
        .frame(width: 1200, height: 900)
    }
}

#Preview {
    MainView()
}
