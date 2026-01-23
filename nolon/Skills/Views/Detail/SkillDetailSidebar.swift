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
                                    Color.accentColor,
                                    Color.accentColor.opacity(0.7)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: Color.accentColor.opacity(0.3), radius: 8, x: 0, y: 4)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(.white.opacity(0.2), lineWidth: 1)
                        )
                    
                    Text(viewModel.skill.name.prefix(1).uppercased())
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
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
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(
                                Capsule()
                                    .fill(.ultraThinMaterial)
                                    .stroke(Color.secondary.opacity(0.1), lineWidth: 0.5)
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
