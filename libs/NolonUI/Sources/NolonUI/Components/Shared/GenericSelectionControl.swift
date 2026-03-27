import SwiftUI

public struct GenericSelectionControl<Value: Hashable, Content: View>: View {
    @State private var viewModel = GenericSelectionControlViewModel()

    private let isSelected: Bool
    private let onToggle: () -> Void
    private let content: (Bool) -> Content
    private let disabled: Bool

    public init(
        value: Value,
        selection: Binding<Value>,
        onToggle: (() -> Void)? = nil,
        disabled: Bool = false,
        @ViewBuilder content: @escaping (_ isSelected: Bool) -> Content
    ) {
        self.isSelected = selection.wrappedValue == value
        self.onToggle = {
            selection.wrappedValue = value
            onToggle?()
        }
        self.content = content
        self.disabled = disabled
    }

    public init(
        value: Value,
        selection: Binding<Value?>,
        allowsEmptySelection: Bool = false,
        onToggle: (() -> Void)? = nil,
        disabled: Bool = false,
        @ViewBuilder content: @escaping (_ isSelected: Bool) -> Content
    ) {
        self.isSelected = selection.wrappedValue == value
        self.onToggle = {
            if allowsEmptySelection, selection.wrappedValue == value {
                selection.wrappedValue = nil
            } else {
                selection.wrappedValue = value
            }
            onToggle?()
        }
        self.content = content
        self.disabled = disabled
    }

    public init(
        value: Value,
        selections: Binding<Set<Value>>,
        onToggle: (() -> Void)? = nil,
        disabled: Bool = false,
        @ViewBuilder content: @escaping (_ isSelected: Bool) -> Content
    ) {
        self.isSelected = selections.wrappedValue.contains(value)
        self.onToggle = {
            if selections.wrappedValue.contains(value) {
                selections.wrappedValue.remove(value)
            } else {
                selections.wrappedValue.insert(value)
            }
            onToggle?()
        }
        self.content = content
        self.disabled = disabled
    }

    public var body: some View {
        Button(action: onToggle) {
            content(isSelected)
        }
        .buttonStyle(.plain)
        .disabled(disabled)
    }
}
