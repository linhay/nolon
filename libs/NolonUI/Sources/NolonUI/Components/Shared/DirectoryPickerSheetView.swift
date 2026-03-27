import SwiftUI
import NolonUIFoundation

public struct DirectoryPickerSheetView: View {
    @State private var viewModel: DirectoryPickerSheetViewModel

    public init(viewModel: DirectoryPickerSheetViewModel) {
        self._viewModel = State(initialValue: viewModel)
    }

    public var body: some View {
        VStack(spacing: 0) {
            SheetHeaderView(
                title: NSLocalizedString("Choose Skills Directories", comment: "Choose skills directories"),
                subtitle: NSLocalizedString("Select one or more directories containing skills:", comment: "Select directories")
            ) {
                viewModel.cancel()
            }

            Divider()

            Form {
                Section {
                    ForEach(viewModel.data.candidates) { candidate in
                        Button {
                            viewModel.toggleSelection(candidate.id)
                        } label: {
                            row(candidate: candidate, isSelected: viewModel.selectedIDs.contains(candidate.id))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .formStyle(.grouped)

            Divider()

            HStack(spacing: 12) {
                Button(NSLocalizedString("Cancel", comment: "Cancel")) {
                    viewModel.cancel()
                }
                .dsLinkButton()

                Spacer(minLength: 0)

                Button(NSLocalizedString("select", comment: "Select")) {
                    viewModel.confirm()
                }
                .dsPrimaryButton()
                .disabled(viewModel.selectedIDs.isEmpty)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .frame(width: 500, height: 400)
    }

    @ViewBuilder
    private func row(candidate: DirectoryPickerCandidateInfo, isSelected: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? DesignSystem.Colors.primary : DesignSystem.Colors.Text.secondary)
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
        .contentShape(Rectangle())
    }
}
