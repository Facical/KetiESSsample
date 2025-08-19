import SwiftUI

struct CalloutBubble: View {
    let title: String
    let detail: String
    @State private var isHovering = false  // 👈 호버 상태 추가
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.title2)  // 👈 더 큰 폰트로 변경
                    .fontWeight(.semibold)
                
                // 호버 안 했을 때만 info 아이콘 표시
                if !isHovering {
                    Image(systemName: "info.circle.fill")
                        .foregroundColor(.blue.opacity(0.7))
                        .font(.body)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            
            // 호버시 detail 표시
            if isHovering {
                Text(detail)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .transition(.asymmetric(
                        insertion: .push(from: .top).combined(with: .opacity),
                        removal: .push(from: .bottom).combined(with: .opacity)
                    ))
            }
        }
        .padding(15)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 12))
        .overlay(alignment: .bottom) {
            Triangle()
                .frame(width: 14, height: 8)
                .rotationEffect(.degrees(180))
                .foregroundStyle(.ultraThinMaterial)
                .offset(y: 6)
        }
        .glassBackgroundEffect()
        .onHover { hovering in  // 👈 호버 감지
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                isHovering = hovering
            }
        }
        // 호버시 살짝 커지는 효과 (선택사항)
        .scaleEffect(isHovering ? 1.05 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isHovering)
    }
}

private struct Triangle: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: .init(x: r.midX, y: r.minY))
        p.addLine(to: .init(x: r.maxX, y: r.maxY))
        p.addLine(to: .init(x: r.minX, y: r.maxY))
        p.closeSubpath()
        return p
    }
}
