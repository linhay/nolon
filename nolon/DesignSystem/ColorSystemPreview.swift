import SwiftUI

struct ColorSystemPreview: View {
    let colors: [(String, Color)] = [
        ("Brand Primary", DesignSystem.Colors.primary),
        ("Brand Secondary", DesignSystem.Colors.secondary),
        ("Background Canvas", DesignSystem.Colors.Background.canvas),
        ("Background Surface", DesignSystem.Colors.Background.surface),
        ("Background Elevated", DesignSystem.Colors.Background.elevated),
        ("Text Primary", DesignSystem.Colors.Text.primary),
        ("Text Secondary", DesignSystem.Colors.Text.secondary),
        ("Text Tertiary", DesignSystem.Colors.Text.tertiary),
        ("Text Quaternary", DesignSystem.Colors.Text.quaternary),
        ("Status Info", DesignSystem.Colors.Status.info),
        ("Status Success", DesignSystem.Colors.Status.success),
        ("Status Warning", DesignSystem.Colors.Status.warning),
        ("Status Error", DesignSystem.Colors.Status.error),
    ]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 120))], spacing: 20) {
                ForEach(colors, id: \.0) { name, color in
                    VStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(color)
                            .frame(height: 80)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(DesignSystem.Colors.Component.border, lineWidth: 1)
                            )

                        Text(name)
                            .font(.caption)
                            .foregroundColor(DesignSystem.Colors.Text.primary)
                            .multilineTextAlignment(.center)
                    }
                }
            }
            .padding()
        }
        .background(DesignSystem.Colors.Background.canvas)
        .navigationTitle("Design System Colors")
    }
}

#Preview {
    ColorSystemPreview()
        .frame(width: 500, height: 600)
}
