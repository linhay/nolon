import SwiftUI

public struct CodexAdvancedRoleSectionFooterView<MenuContent: View>: View {
    let addTitle: String
    let addSystemImage: String
    let saveTitle: String
    let isSaveDisabled: Bool
    let menuContent: () -> MenuContent
    let onSave: () -> Void

    public init(
        addTitle: String,
        addSystemImage: String = "plus",
        saveTitle: String,
        isSaveDisabled: Bool,
        @ViewBuilder menuContent: @escaping () -> MenuContent,
        onSave: @escaping () -> Void
    ) {
        self.addTitle = addTitle
        self.addSystemImage = addSystemImage
        self.saveTitle = saveTitle
        self.isSaveDisabled = isSaveDisabled
        self.menuContent = menuContent
        self.onSave = onSave
    }

    public var body: some View {
        HStack {
            Menu {
                menuContent()
            } label: {
                Label(addTitle, systemImage: addSystemImage)
            }
            .dsSecondaryButton()

            Spacer(minLength: 0)

            Button(saveTitle) {
                onSave()
            }
            .dsPrimaryButton()
            .disabled(isSaveDisabled)
        }
    }
}
