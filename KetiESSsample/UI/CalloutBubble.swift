import SwiftUI

struct CalloutBubble: View {
    let title: String
    let detail: String
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // 👇 버튼으로 변경
            Button(action: {
                withAnimation(.spring(response: 0.3)) {
                    isExpanded.toggle()
                }
            }) {
                HStack {
                    Text(title)
                        .font(.title2)
                        .foregroundColor(.primary)  // 색상 유지
                    
                    Image(systemName: isExpanded ? "chevron.up.circle.fill" : "chevron.down.circle.fill")
                        .foregroundColor(.blue)
                        .font(.title2)
                }
            }
            .buttonStyle(.plain)  // 기본 버튼 스타일 제거
            .hoverEffect()  // 호버 효과 추가
            
            if isExpanded {
                Text(detail)
                    .font(.body)
                    .fixedSize(horizontal: false, vertical: true)
                    .transition(.asymmetric(
                        insertion: .move(edge: .top).combined(with: .opacity),
                        removal: .move(edge: .top).combined(with: .opacity)
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
