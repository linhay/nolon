import SwiftUI
import NolonResourceKit

struct SkillFileNavigator: View {
    @Bindable var viewModel: SkillDetailViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Resources".uppercased())
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(DesignSystem.Colors.Text.tertiary)
                .tracking(0.8)
                .padding(.horizontal, 24)
            
            VStack(spacing: 2) {
                ForEach(viewModel.files) { file in
                    FileNavItem(file: file, isSelected: viewModel.selectedFile == file) {
                        viewModel.selectedFile = file
                    }
                }
            }
            .padding(.horizontal, 12)
        }
    }
}

private struct FileNavItem: View {
    let file: SkillFile
    let isSelected: Bool
    let action: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                icon(for: file.type)
                    .font(.system(size: 14))
                    .frame(width: 16)
                
                Text(file.name)
                    .font(.system(size: 12, weight: isSelected ? .semibold : .medium))
                    .lineLimit(1)
                
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .foregroundStyle(isSelected ? .white : (isHovered ? DesignSystem.Colors.Text.primary : DesignSystem.Colors.Text.secondary))
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? DesignSystem.Colors.primary : (isHovered ? Color.white.opacity(0.05) : Color.clear))
            )
            .shadow(color: isSelected ? DesignSystem.Colors.primary.opacity(0.4) : .clear, radius: 8, x: 0, y: 4)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }
    
    private func icon(for type: SkillFile.SkillFileType) -> Image {
        switch type {
        case .markdown: return Image(systemName: "doc.text")
        case .code: return Image(systemName: "chevron.left.forwardslash.chevron.right")
        case .image: return Image(systemName: "photo")
        case .other: return Image(systemName: "doc")
        }
    }
}
