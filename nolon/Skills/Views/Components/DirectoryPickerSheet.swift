import SwiftUI

/// Directory picker sheet for selecting skills directories (supports multiple selection)
struct DirectoryPickerSheet: View {
    @Binding var isPresented: Bool
    let candidates: [GitRepository.SkillsDirectoryCandidate]
    @Binding var selectedIndices: Set<Int>
    let onConfirm: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            SheetHeaderView(
                title: NSLocalizedString("Choose Skills Directories", comment: "Choose skills directories"),
                subtitle: NSLocalizedString("Select one or more directories containing skills:", comment: "Select directories")
            ) {
                isPresented = false
            }

            Form {
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
                                            .foregroundStyle(selectedIndices.contains(index) ? DesignSystem.Colors.primary : DesignSystem.Colors.Text.secondary)
                                        Text(candidate.path == "."
                                             ? NSLocalizedString("Repository Root", comment: "Repository root")
                                             : candidate.path)
                                            .font(.body)
                                        Spacer(minLength: 0)
                                        Text("\(candidate.skillCount) skill\(candidate.skillCount == 1 ? "" : "s")")
                                            .font(.caption)
                                            .foregroundStyle(DesignSystem.Colors.Text.secondary)
                                    }
                                    if !candidate.skillNames.isEmpty {
                                        Text(candidate.skillNames.joined(separator: ", "))
                                            .font(.caption2)
                                            .foregroundStyle(DesignSystem.Colors.Text.tertiary)
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

            Divider()
                .background(DesignSystem.Colors.Component.separator.opacity(0.25))

            HStack(spacing: 12) {
                Button(NSLocalizedString("Cancel", comment: "Cancel")) {
                    isPresented = false
                }
                .buttonStyle(.plain)

                Spacer(minLength: 0)

                Button(NSLocalizedString("select", comment: "Select")) {
                    onConfirm()
                    isPresented = false
                }
                .buttonStyle(.borderedProminent)
                .disabled(selectedIndices.isEmpty)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
        }
        .frame(width: 500, height: 400)
    }
}
