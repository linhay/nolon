import SwiftUI
import NolonUIFoundation

public struct CodexAdvancedPickerRowView: View {
    let label: String
    let description: String?
    let options: [CodexAdvancedPickerOption]
    @Binding var selection: String
    let isDisabled: Bool
    let showsProgress: Bool
    let onSelectionChanged: (() -> Void)?

    public init(
        label: String,
        description: String? = nil,
        options: [CodexAdvancedPickerOption],
        selection: Binding<String>,
        isDisabled: Bool = false,
        showsProgress: Bool = false,
        onSelectionChanged: (() -> Void)? = nil
    ) {
        self.label = label
        self.description = description
        self.options = options
        self._selection = selection
        self.isDisabled = isDisabled
        self.showsProgress = showsProgress
        self.onSelectionChanged = onSelectionChanged
    }

    public var body: some View {
        CodexAdvancedAlignedConfigRow(label: label, description: description) {
            HStack(spacing: 8) {
                Picker("", selection: $selection) {
                    ForEach(options) { option in
                        Text(option.title).tag(option.id)
                    }
                }
                .onChange(of: selection) { _, _ in
                    onSelectionChanged?()
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .disabled(isDisabled)
                .frame(maxWidth: .infinity, alignment: .trailing)

                if showsProgress {
                    ProgressView().controlSize(.small)
                }
            }
        }
    }
}
