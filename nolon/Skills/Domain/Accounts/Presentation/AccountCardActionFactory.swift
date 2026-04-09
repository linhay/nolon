import Foundation
import SwiftUI
import NolonUIFoundation

enum AccountCardActionFactory {
    static func primaryActivateAction(
        title: String,
        isEnabled: Bool = true
    ) -> AccountCardActionViewData {
        .init(
            id: "activate",
            actionID: .activate,
            title: title,
            systemImage: nil,
            role: nil,
            prominence: .primary,
            isEnabled: isEnabled
        )
    }

    static func menuEditAction(
        title: String,
        systemImage: String = "pencil",
        isEnabled: Bool = true
    ) -> AccountCardMenuActionViewData {
        .init(
            id: "edit",
            actionID: .edit,
            title: title,
            systemImage: systemImage,
            role: nil,
            isEnabled: isEnabled
        )
    }

    static func menuRefreshAction(isEnabled: Bool) -> AccountCardMenuActionViewData {
        .init(
            id: "refresh",
            actionID: .refresh,
            title: NSLocalizedString("usage.monitor.refresh", value: "Refresh", comment: "Refresh"),
            systemImage: "arrow.clockwise",
            role: nil,
            isEnabled: isEnabled
        )
    }

    static func menuDeleteAction(
        title: String = NSLocalizedString(
            "codex.accounts.delete.title",
            value: "Delete Account",
            comment: "Delete account title"
        ),
        isEnabled: Bool = true
    ) -> AccountCardMenuActionViewData {
        .init(
            id: "delete",
            actionID: .delete,
            title: title,
            systemImage: "trash",
            role: .destructive,
            isEnabled: isEnabled
        )
    }
}
