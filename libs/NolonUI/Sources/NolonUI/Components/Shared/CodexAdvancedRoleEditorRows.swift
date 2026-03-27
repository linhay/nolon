import SwiftUI
import NolonUIFoundation

public struct CodexAdvancedRoleEditorRow<Control: View>: View {
    let label: String
    let labelWidth: CGFloat
    let spacing: CGFloat
    let control: () -> Control

    public init(
        label: String,
        labelWidth: CGFloat = 180,
        spacing: CGFloat = 10,
        @ViewBuilder control: @escaping () -> Control
    ) {
        self.label = label
        self.labelWidth = labelWidth
        self.spacing = spacing
        self.control = control
    }

    public var body: some View {
        HStack(spacing: spacing) {
            Text(label)
                .font(.caption.monospaced())
                .foregroundStyle(DesignSystem.Colors.Text.secondary)
                .frame(width: labelWidth, alignment: .leading)

            Spacer(minLength: 12)

            control()
        }
    }
}

public struct CodexAdvancedRoleTextFieldRowView: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    let textFieldWidth: CGFloat

    public init(
        label: String,
        placeholder: String,
        text: Binding<String>,
        textFieldWidth: CGFloat = 360
    ) {
        self.label = label
        self.placeholder = placeholder
        self._text = text
        self.textFieldWidth = textFieldWidth
    }

    public var body: some View {
        CodexAdvancedRoleEditorRow(label: label) {
            TextField(placeholder, text: $text)
                .textFieldStyle(.roundedBorder)
                .frame(width: textFieldWidth, alignment: .trailing)
        }
    }
}

public struct CodexAdvancedRolePickerRowView: View {
    let label: String
    let options: [CodexAdvancedPickerOption]
    @Binding var selection: String
    let pickerWidth: CGFloat
    let onSelectionChanged: (() -> Void)?

    public init(
        label: String,
        options: [CodexAdvancedPickerOption],
        selection: Binding<String>,
        pickerWidth: CGFloat = 260,
        onSelectionChanged: (() -> Void)? = nil
    ) {
        self.label = label
        self.options = options
        self._selection = selection
        self.pickerWidth = pickerWidth
        self.onSelectionChanged = onSelectionChanged
    }

    public var body: some View {
        CodexAdvancedRoleEditorRow(label: label) {
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
            .frame(width: pickerWidth, alignment: .trailing)
        }
    }
}
