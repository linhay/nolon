import SwiftUI

/// 动态 Liquid 背景，使用 MeshGradient 打造流动的色彩感 (macOS 15+)
/// 对于较低版本 macOS，回退到动画模糊圆形状
struct LiquidBackgroundView: View {
    @State private var appear = false
    
    var body: some View {
        ZStack {
            // Subtle Material-like background
            Color(NSColor.windowBackgroundColor)
            
            // Subtle animated organic shapes with very low opacity and blur
            // This provides "Liquid" feel without being a "Gradient"
            ZStack {
                Circle()
                    .fill(Color.primary.opacity(0.03))
                    .frame(width: 600, height: 600)
                    .offset(x: appear ? -150 : 150, y: appear ? -100 : 100)
                    .blur(radius: 100)
                
                Circle()
                    .fill(Color.primary.opacity(0.02))
                    .frame(width: 800, height: 800)
                    .offset(x: appear ? 200 : -200, y: appear ? 150 : -150)
                    .blur(radius: 120)
            }
            .opacity(0.5)
            
            // Texture overlay
            Canvas { context, size in
                for _ in 0...1000 {
                    let x = CGFloat.random(in: 0...size.width)
                    let y = CGFloat.random(in: 0...size.height)
                    context.fill(Path(CGRect(x: x, y: y, width: 1, height: 1)), with: .color(Color.primary.opacity(0.03)))
                }
            }
            .blendMode(.overlay)
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.easeInOut(duration: 15).repeatForever(autoreverses: true)) {
                appear.toggle()
            }
        }
    }
}

#Preview {
    LiquidBackgroundView()
        .frame(width: 800, height: 600)
}
