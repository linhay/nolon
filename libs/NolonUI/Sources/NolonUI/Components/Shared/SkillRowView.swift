import SwiftUI
import NolonUIFoundation

public struct SkillRowView: View {
    @State private var viewModel = SkillRowViewViewModel()
    private let row: SkillRowInfo

    public init(row: SkillRowInfo) {
        self.row = row
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(row.name)
                    .font(.headline)

                if row.isInstalled {
                    SkillInstalledBadge()
                }
            }

            Text(row.description)
                .font(.caption)
                .dsSecondaryText(font: .caption)
                .lineLimit(2)

            HStack {
                if row.referenceCount > 0 || row.scriptCount > 0 {
                    HStack(spacing: 12) {
                        if row.referenceCount > 0 {
                            Label("\(row.referenceCount)", systemImage: "doc.text")
                                .dsIconLabelText()
                        }
                        if row.scriptCount > 0 {
                            Label("\(row.scriptCount)", systemImage: "terminal")
                                .dsIconLabelText()
                        }
                    }
                }

                Spacer()

                SkillVersionBadge(version: row.version)
            }

            if viewModel.isExpanded {
                Divider()
                VStack(alignment: .leading, spacing: 4) {
                    Text(NSLocalizedString("skill.path_label", comment: "Path:"))
                        .font(.caption)
                        .dsSecondaryText(font: .caption)

                    Text(row.globalPath)
                        .dsSecondaryText(font: .system(.caption2, design: .monospaced))
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                .padding(.top, 4)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation {
                viewModel.isExpanded.toggle()
            }
        }
    }
}

#Preview {
    SkillRowView(
        row: SkillRowInfo(
            name: "swiftui-patterns",
            description: "Best practices for modern SwiftUI state and composition.",
            isInstalled: true,
            version: "1.2.0",
            globalPath: "/Users/demo/.nolon/skills/swiftui-patterns",
            referenceCount: 3,
            scriptCount: 1
        )
    )
    .padding()
    .frame(width: 420)
}
