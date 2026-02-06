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

            SheetDivider()

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
                                            .dsSecondaryText(font: .caption)
                                    }
                                    if !candidate.skillNames.isEmpty {
                                        Text(candidate.skillNames.joined(separator: ", "))
                                            .font(.caption2)
                                            .dsTertiaryText(font: .caption2)
                                            .lineLimit(1)
                                            .padding(.leading, 20)
                                    }
                                }
                            }
                        }
                        .dsLinkButton()
                    }
                }
            }
            .formStyle(.grouped)
            .sheetScrollContentPadding()

            SheetDivider()

            HStack(spacing: 12) {
                Button(NSLocalizedString("Cancel", comment: "Cancel")) {
                    isPresented = false
                }
                .dsLinkButton()

                Spacer(minLength: 0)

                Button(NSLocalizedString("select", comment: "Select")) {
                    onConfirm()
                    isPresented = false
                }
                .dsPrimaryButton()
                .disabled(selectedIndices.isEmpty)
            }
            .padding(.horizontal, SheetLayout.footerHorizontalPadding)
            .padding(.vertical, SheetLayout.footerVerticalPadding)
        }
        .frame(width: 500, height: 400)
    }
}
