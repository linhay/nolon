import SwiftUI
import NolonUIFoundation

public struct CodexAdvancedRoleAddMenuContentView: View {
    let addEmptyTitle: String
    let builtinItems: [CodexAdvancedRoleAddBuiltinItem]
    let onAddEmpty: () -> Void
    let onSelectBuiltin: (String) -> Void

    public init(
        addEmptyTitle: String,
        builtinItems: [CodexAdvancedRoleAddBuiltinItem],
        onAddEmpty: @escaping () -> Void,
        onSelectBuiltin: @escaping (String) -> Void
    ) {
        self.addEmptyTitle = addEmptyTitle
        self.builtinItems = builtinItems
        self.onAddEmpty = onAddEmpty
        self.onSelectBuiltin = onSelectBuiltin
    }

    public var body: some View {
        Button(addEmptyTitle) {
            onAddEmpty()
        }

        if !builtinItems.isEmpty {
            Divider()
            ForEach(builtinItems) { item in
                Button(item.title) {
                    onSelectBuiltin(item.id)
                }
            }
        }
    }
}
