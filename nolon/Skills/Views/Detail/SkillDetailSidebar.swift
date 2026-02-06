import SwiftUI

struct SkillDetailSidebar: View {
    @Bindable var viewModel: SkillDetailViewModel
    
    var body: some View {
        VStack(spacing: 0) {
            // New Information Header with "Liquid Glass" feel
            VStack(alignment: .leading, spacing: 16) {
                // Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    DesignSystem.Colors.primary,
                                    DesignSystem.Colors.primary.opacity(0.7)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: DesignSystem.Colors.primary.opacity(0.3), radius: 8, x: 0, y: 4)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(DesignSystem.Colors.Component.border.opacity(0.25), lineWidth: 1)
                        )
                    
                    Text(viewModel.skill.name.prefix(1).uppercased())
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(DesignSystem.Colors.Text.onAccent)
                        .shadow(color: DesignSystem.Colors.Shadow.floating.opacity(0.5), radius: 2, x: 0, y: 1)
                }
                .frame(width: 56, height: 56)
                
                // Title info
                VStack(alignment: .leading, spacing: 6) {
                    Text(viewModel.skill.name)
                        .font(.system(.title3, design: .rounded))
                        .fontWeight(.bold)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    HStack {
                        Text("v" + viewModel.skill.version)
                            .font(.system(.caption2, design: .monospaced))
                            .fontWeight(.semibold)
                            .dsBadgeBorder(
                                foreground: DesignSystem.Colors.Text.secondary,
                                background: DesignSystem.Colors.Component.controlFillSubtle,
                                borderColor: DesignSystem.Colors.Component.border.opacity(0.20),
                                borderWidth: 0.5,
                                horizontalPadding: 8,
                                verticalPadding: 3
                            )
                        
                        Spacer()
                    }
                }
            }
            .padding(16)
            .padding(.top, 8)
            
            Divider()
            
            // File List
            List(selection: $viewModel.selectedFile) {
                ForEach(viewModel.files) { file in
                    Label {
                        Text(file.name)
                    } icon: {
                        icon(for: file.type)
                    }
                    .tag(file)
                }
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)
        }
    }
    
    private func icon(for type: SkillFile.SkillFileType) -> Image {
        switch type {
        case .markdown: return Image(systemName: "doc.text")
        case .code: return Image(systemName: "curlybraces")
        case .image: return Image(systemName: "photo")
        case .other: return Image(systemName: "doc")
        }
    }
}
