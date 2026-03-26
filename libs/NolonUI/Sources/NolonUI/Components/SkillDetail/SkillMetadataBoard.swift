import SwiftUI

struct SkillMetadataBoard: View {
    let metadata: [String: String]
    let covers: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 32) {
            // 1. Main Grid Tiles
            LazyVGrid(columns: [
                GridItem(.adaptive(minimum: 180, maximum: .infinity), spacing: 16)
            ], spacing: 16) {
                ForEach(Array(metadata.keys.sorted()), id: \.self) { key in
                    if key.lowercased() != "tags" {
                        MetadataTile(key: key, value: metadata[key] ?? "")
                    }
                }
            }
            
            // 2. Capabilities Section (Covers)
            if !covers.isEmpty {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(alignment: .top, spacing: 16) {
                        Text("CAPABILITIES")
                            .font(.system(size: 10, weight: .black))
                            .foregroundStyle(DesignSystem.Colors.Text.tertiary)
                            .tracking(2.0)
                            .padding(.top, 4)
                        
                        FlowLayout(spacing: 8) {
                            ForEach(covers, id: \.self) { tag in
                                Text("#\(tag)")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(DesignSystem.Colors.primary)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 6)
                                    .background(DesignSystem.Colors.primary.opacity(0.1))
                                    .cornerRadius(20)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 20)
                                            .stroke(DesignSystem.Colors.primary.opacity(0.25), lineWidth: 1)
                                    )
                            }
                        }
                    }
                }
                .padding(24)
                .background(Color.white.opacity(0.015))
                .cornerRadius(16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(DesignSystem.Colors.Component.border.opacity(0.3), style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                )
            }
        }
    }
}

private struct MetadataTile: View {
    let key: String
    let value: String
    
    @State private var isHovered = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                icon(for: key)
                    .font(.system(size: 10))
                Text(key.uppercased())
                    .font(.system(size: 9, weight: .black))
                    .tracking(1.5)
            }
            .foregroundStyle(DesignSystem.Colors.Text.tertiary)
            
            Text(value)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(DesignSystem.Colors.Text.primary)
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .padding(.vertical, 20)
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(isHovered ? Color.white.opacity(0.06) : Color.white.opacity(0.03))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(isHovered ? Color.white.opacity(0.15) : Color.white.opacity(0.08), lineWidth: 1.5)
        )
        .onHover { hovering in
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                isHovered = hovering
            }
        }
    }
    
    @ViewBuilder
    private func icon(for key: String) -> some View {
        switch key.lowercased() {
        case "author": Image(systemName: "person.fill")
        case "category": Image(systemName: "square.grid.3x3.fill")
        case "runtime", "platform": Image(systemName: "cpu.fill")
        case "license": Image(systemName: "doc.text.fill")
        case "id": Image(systemName: "key.fill")
        case "path": Image(systemName: "folder.fill")
        default: Image(systemName: "info.circle.fill")
        }
    }
}
