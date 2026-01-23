import SwiftUI
import MarkdownUI

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
                                let metadata = SkillParser.parseMetadata(from: content)
                                if !metadata.isEmpty {
                                    VStack(alignment: .leading, spacing: 12) {
                                        Text("Metadata")
                                            .font(.headline)
                                            .foregroundStyle(.secondary)
                                        
                                        Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
                                            ForEach(metadata.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
                                                GridRow(alignment: .top) {
                                                    Text(key)
                                                        .font(.caption)
                                                        .foregroundStyle(.secondary)
                                                        .frame(width: 80, alignment: .trailing)
                                                    
                                                    Text(value)
                                                        .font(.caption)
                                                        .monospaced()
                                                        .textSelection(.enabled)
                                                }
                                            }
                                        }
                                        .padding()
                                        .background(Color.secondary.opacity(0.05))
                                        .cornerRadius(8)
                                    }
                                }
                                
                                Divider()
                                
                                // Content
                                let body = SkillParser.stripFrontmatter(from: content)
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
                    ContentUnavailableView("Unable to read file", systemImage: "doc.question.mark")
                }
            } else {
                ContentUnavailableView("No file selected", systemImage: "doc")
            }
        }
    }
}
