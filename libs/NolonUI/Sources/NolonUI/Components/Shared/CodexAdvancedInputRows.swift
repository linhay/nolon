import SwiftUI

public struct CodexAdvancedTextFieldRowView: View {
    let label: String
    let description: String?
    let placeholder: String
    @Binding var text: String
    let onTextChanged: (() -> Void)?

    public init(
        label: String,
        description: String? = nil,
        placeholder: String,
        text: Binding<String>,
        onTextChanged: (() -> Void)? = nil
    ) {
        self.label = label
        self.description = description
        self.placeholder = placeholder
        self._text = text
        self.onTextChanged = onTextChanged
    }

    public var body: some View {
        CodexAdvancedAlignedConfigRow(label: label, description: description) {
            TextField(placeholder, text: $text)
                .onChange(of: text) { _, _ in
                    onTextChanged?()
                }
                .textFieldStyle(.roundedBorder)
                .multilineTextAlignment(.trailing)
        }
    }
}

public struct CodexAdvancedNumericFieldRowView: View {
    let label: String
    let description: String?
    @Binding var text: String
    let onTextChanged: (() -> Void)?

    public init(
        label: String,
        description: String? = nil,
        text: Binding<String>,
        onTextChanged: (() -> Void)? = nil
    ) {
        self.label = label
        self.description = description
        self._text = text
        self.onTextChanged = onTextChanged
    }

    public var body: some View {
        CodexAdvancedAlignedConfigRow(label: label, description: description) {
            TextField("", text: $text)
                .onChange(of: text) { _, newValue in
                    let filtered = newValue.filter(\.isNumber)
                    if filtered != newValue {
                        text = filtered
                        return
                    }
                    onTextChanged?()
                }
                .textFieldStyle(.roundedBorder)
                .multilineTextAlignment(.trailing)
        }
    }
}

