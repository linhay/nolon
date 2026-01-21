import MarkdownUI
import SwiftUI

/// Left column 3: Skill detail content view
/// Displays the SkillParser structure content for selected skill
@MainActor
public struct SkillDetailContentView: View {
    let skill: Skill?

    public init(skill: Skill?) {
        self.skill = skill
    }

    public var body: some View {
        Group {
            if let skill = skill {
                skillDetailContent(skill)
            } else {
                ContentUnavailableView(
                    NSLocalizedString("detail.no_selection", comment: "No Skill Selected"),
                    systemImage: "doc.text",
                    description: Text(
                        NSLocalizedString(
                            "detail.no_selection_desc",
                            comment: "Select a skill to view its details"))
                )
            }
        }
    }

    @ViewBuilder
    private func skillDetailContent(_ skill: Skill) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header section
                headerSection(skill)

                Divider()

                // Metadata section
                metadataSection(skill)

                Divider()

                // Content section
                contentSection(skill)
            }
            .padding()
        }
        .navigationTitle(skill.name)
    }

    @ViewBuilder
    private func headerSection(_ skill: Skill) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Name and version
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(skill.name)
                        .font(.title)
                        .bold()

                    Text(skill.description)
                        .font(.body)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Version badge
                Text("v\(skill.version)")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.1))
                    .foregroundStyle(.blue)
                    .cornerRadius(6)
            }
        }
    }

    @ViewBuilder
    private func metadataSection(_ skill: Skill) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(NSLocalizedString("detail.metadata", comment: "Metadata"))
                .font(.headline)

            LazyVGrid(
                columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                ], spacing: 12
            ) {
                // ID
                MetadataItem(
                    icon: "number",
                    title: NSLocalizedString("detail.id", comment: "ID"),
                    value: skill.id
                )

                // Version
                MetadataItem(
                    icon: "tag",
                    title: NSLocalizedString("detail.version_label", comment: "Version"),
                    value: skill.version
                )

                // References
                MetadataItem(
                    icon: "doc.text",
                    title: NSLocalizedString("detail.references", comment: "References"),
                    value:
                        "\(skill.referenceCount) \(NSLocalizedString("detail.files", comment: "files"))"
                )

                // Scripts
                MetadataItem(
                    icon: "terminal",
                    title: NSLocalizedString("detail.scripts", comment: "Scripts"),
                    value:
                        "\(skill.scriptCount) \(NSLocalizedString("detail.files", comment: "files"))"
                )
            }
        }
        .padding()
        .background(Color.secondary.opacity(0.05))
        .cornerRadius(12)
    }

    @ViewBuilder
    private func contentSection(_ skill: Skill) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(NSLocalizedString("detail.skill_content", comment: "SKILL.md Content"))
                .font(.headline)

            Markdown(skill.content)
                .padding()
                .background(Color.secondary.opacity(0.05))
                .cornerRadius(12)
        }
    }

    private func openInFinder(_ skill: Skill) {
        let url = URL(fileURLWithPath: skill.globalPath)
        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: url.path)
    }
}

/// Metadata item component
struct MetadataItem: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(.secondary)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(value)
                    .font(.callout)
            }

            Spacer()
        }
        .padding(8)
        .background(Color.secondary.opacity(0.05))
        .cornerRadius(8)
    }
}

/// Simple flow layout for tags
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(
        in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()
    ) {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        for (index, frame) in result.frames.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY),
                proposal: ProposedViewSize(frame.size)
            )
        }
    }

    private func arrangeSubviews(proposal: ProposedViewSize, subviews: Subviews) -> (
        size: CGSize, frames: [CGRect]
    ) {
        let maxWidth = proposal.width ?? .infinity
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        var frames: [CGRect] = []

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)

            if currentX + size.width > maxWidth && currentX > 0 {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }

            frames.append(CGRect(x: currentX, y: currentY, width: size.width, height: size.height))
            lineHeight = max(lineHeight, size.height)
            currentX += size.width + spacing
        }

        return (CGSize(width: maxWidth, height: currentY + lineHeight), frames)
    }
}
