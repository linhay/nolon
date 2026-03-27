import SwiftUI

struct ContextMenuViewDetailsButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(NSLocalizedString("View Details", comment: "View resource details"), systemImage: "info.circle")
                .dsIconLabelButton()
        }
    }
}

struct ContextMenuShowInFinderButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(NSLocalizedString("action.show_in_finder", comment: "Show in Finder"), systemImage: "folder")
                .dsIconLabelButton()
        }
    }
}

struct ContextMenuInstallButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(NSLocalizedString("action.install", value: "Install", comment: "Install action"), systemImage: "arrow.down.circle")
                .dsIconLabelButton()
        }
    }
}

struct ContextMenuDeleteButton: View {
    let action: () -> Void
    let isEnabled: Bool

    init(
        isEnabled: Bool = true,
        action: @escaping () -> Void
    ) {
        self.action = action
        self.isEnabled = isEnabled
    }

    var body: some View {
        Button(role: .destructive, action: action) {
            Label(NSLocalizedString("action.delete", value: "Delete", comment: "Delete action"), systemImage: "trash")
                .dsIconLabelButton()
        }
        .disabled(!isEnabled)
    }
}
