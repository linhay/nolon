import SwiftUI

/// Dynamic liquid background with subtle motion and texture.
public struct LiquidBackgroundView: View {
    @State private var viewModel = LiquidBackgroundViewModel()

    public init() {}

    public var body: some View {
        ZStack {
            DesignSystem.Colors.Background.canvas

            ZStack {
                Circle()
                    .fill(DesignSystem.Colors.primary.opacity(0.10))
                    .frame(width: 600, height: 600)
                    .offset(
                        x: viewModel.appear ? -150 : 150,
                        y: viewModel.appear ? -100 : 100
                    )
                    .blur(radius: 100)

                Circle()
                    .fill(DesignSystem.Colors.secondary.opacity(0.08))
                    .frame(width: 800, height: 800)
                    .offset(
                        x: viewModel.appear ? 200 : -200,
                        y: viewModel.appear ? 150 : -150
                    )
                    .blur(radius: 120)
            }
            .opacity(0.35)

            Canvas { context, size in
                for _ in 0...1000 {
                    let x = CGFloat.random(in: 0...size.width)
                    let y = CGFloat.random(in: 0...size.height)
                    context.fill(
                        Path(CGRect(x: x, y: y, width: 1, height: 1)),
                        with: .color(DesignSystem.Colors.Text.quaternary)
                    )
                }
            }
            .blendMode(.overlay)
        }
        .ignoresSafeArea()
        .onAppear {
            viewModel.startAnimation()
        }
    }
}

#Preview {
    LiquidBackgroundView()
        .frame(width: 800, height: 600)
}
