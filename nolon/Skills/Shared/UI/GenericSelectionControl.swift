import SwiftUI

struct GenericSelectionControl<Value: Hashable, Content: View>: View {
    @State private var viewModel = GenericSelectionControlViewModel()

    private let isSelected: Bool
    private let onToggle: () -> Void
    private let content: (Bool) -> Content
    private let disabled: Bool

    init(
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

    init(
        value: Value,
        selection: Binding<Value?>,
        allowsEmptySelection: Bool = false,
        onToggle: (() -> Void)? = nil,
        disabled: Bool = false,
        @ViewBuilder content: @escaping (_ isSelected: Bool) -> Content
    ) {
        self.isSelected = selection.wrappedValue == value
        self.onToggle = {
            selection.wrappedValue = GenericSelectionStateResolver.resolveSingleSelection(
                current: selection.wrappedValue,
                tapped: value,
                allowsEmptySelection: allowsEmptySelection
            )
            onToggle?()
        }
        self.content = content
        self.disabled = disabled
    }

    init(
        value: Value,
        selections: Binding<Set<Value>>,
        onToggle: (() -> Void)? = nil,
        disabled: Bool = false,
        @ViewBuilder content: @escaping (_ isSelected: Bool) -> Content
    ) {
        self.isSelected = selections.wrappedValue.contains(value)
        self.onToggle = {
            selections.wrappedValue = GenericSelectionStateResolver.resolveMultiSelection(
                current: selections.wrappedValue,
                tapped: value
            )
            onToggle?()
        }
        self.content = content
        self.disabled = disabled
    }

    var body: some View {
        Button(action: onToggle) {
            content(isSelected)
        }
        .buttonStyle(.plain)
        .disabled(disabled)
    }
}
