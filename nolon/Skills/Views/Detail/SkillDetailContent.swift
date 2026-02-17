import SwiftUI
import MarkdownUI
import NolonResourceKit

struct SkillDetailContent: View {
    @Bindable var viewModel: SkillDetailViewModel
    
    var body: some View {
        Group {
            if let file = viewModel.selectedFile {
                if let content = try? String(contentsOf: file.url) {
                    if file.name == "SKILL.md" && file.type == .markdown {
                        // Structured display for SKILL.md
                        ScrollView {
                            VStack(alignment: .leading, spacing: 20) {
                                // Metadata
                                let metadata = FrontmatterParser.parseMetadata(from: content)
                                if !metadata.isEmpty {
                                    VStack(alignment: .leading, spacing: 12) {
                                        Text("Metadata")
                                            .dsSecondaryText(font: .headline)
                                        
                                        Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
                                            ForEach(metadata.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
                                                GridRow(alignment: .top) {
                                                    Text(key)
                                                        .dsSecondaryText(font: .caption)
                                                        .frame(width: 80, alignment: .trailing)
                                                    
                                                    Text(value)
                                                        .font(.caption)
                                                        .monospaced()
                                                        .textSelection(.enabled)
                                                }
                                            }
                                        }
                                        .padding()
                                        .dsCard(
                                            background: DesignSystem.Colors.Component.controlFillSubtle,
                                            cornerRadius: DesignSystem.Metrics.cornerRadiusM
                                        )
                                    }
                                }
                                
                                Divider()
                                
                                // Content
                                let body = FrontmatterParser.stripFrontmatter(from: content)
                                Markdown(body)
                                    .textSelection(.enabled)
                            }
                            .padding()
                        }
                    } else {
                        // Standard preview
                        ScrollView {
                            if file.type == .markdown {
                                Markdown(content)
                                    .padding()
                                    .textSelection(.enabled)
                            } else {
                                Text(content)
                                    .font(.monospaced(.body)())
                                    .padding()
                                    .textSelection(.enabled)
                            }
                        }
                    }
                } else {
                    ContentUnavailableView {
                        Label {
                            Text("Unable to read file")
                                .dsEmptyStateTitle()
                        } icon: {
                            Image(systemName: "doc.question.mark")
                                .dsEmptyStateIcon()
                        }
                    }
                }
            } else {
                ContentUnavailableView {
                    Label {
                        Text("No file selected")
                            .dsEmptyStateTitle()
                    } icon: {
                        Image(systemName: "doc")
                            .dsEmptyStateIcon()
                    }
                }
            }
        }
    }
}
