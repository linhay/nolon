import SwiftUI

/// Directory picker sheet for selecting skills directories (supports multiple selection)
struct DirectoryPickerSheet: View {
    @Binding var isPresented: Bool
    let candidates: [GitRepositoryService.SkillsDirectoryCandidate]
    @Binding var selectedIndices: Set<Int>
    let onConfirm: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Select one or more directories containing skills:")
                        .foregroundStyle(.secondary)
                }

                Section {
                    ForEach(Array(candidates.enumerated()), id: \.offset) { index, candidate in
                        Button {
                            if selectedIndices.contains(index) {
                                selectedIndices.remove(index)
                            } else {
                                selectedIndices.insert(index)
                            }
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Image(systemName: selectedIndices.contains(index) ? "checkmark.circle.fill" : "circle")
                                            .foregroundStyle(selectedIndices.contains(index) ? .blue : .secondary)
                                        Text(candidate.path == "." ? "Repository Root" : candidate.path)
                                            .font(.body)
                                        Spacer()
                                        Text("\(candidate.skillCount) skill\(candidate.skillCount == 1 ? "" : "s")")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    if !candidate.skillNames.isEmpty {
                                        Text(candidate.skillNames.joined(separator: ", "))
                                            .font(.caption2)
                                            .foregroundStyle(.tertiary)
                                            .lineLimit(1)
                                            .padding(.leading, 20)
                                    }
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Choose Skills Directories")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Select \(selectedIndices.count) director\(selectedIndices.count == 1 ? "y" : "ies")") {
                        onConfirm()
                        isPresented = false
                    }
                    .disabled(selectedIndices.isEmpty)
                }
            }
        }
        .frame(width: 500, height: 400)
    }
}
