import Foundation
import SwiftUI
import NolonUIFoundation

enum CodexAccountActionFactory {
    static func primaryActivateAction(isEnabled: Bool = true) -> AccountCardActionViewData {
        AccountCardActionFactory.primaryActivateAction(
            title: NSLocalizedString("codex.accounts.action.activate", value: "Activate", comment: "Activate account"),
            isEnabled: isEnabled
        )
    }

    static func primaryCopyErrorAction(canRelogin: Bool) -> AccountCardActionViewData {
        .init(
            id: "copyError",
            actionID: .copyError,
            title: NSLocalizedString("codex.accounts.copy_error", value: "Copy error", comment: "Copy account error"),
            systemImage: nil,
            role: nil,
            prominence: canRelogin ? .secondary : .primary,
            isEnabled: true
        )
    }

    static func primaryReloginAction(isEnabled: Bool) -> AccountCardActionViewData {
        .init(
            id: "relogin",
            actionID: .relogin,
            title: NSLocalizedString("codex.accounts.relogin", value: "Re-login", comment: "Re-login account"),
            systemImage: nil,
            role: nil,
            prominence: .primary,
            isEnabled: isEnabled
        )
    }

    static func menuRefreshAction(isEnabled: Bool) -> AccountCardMenuActionViewData {
        AccountCardActionFactory.menuRefreshAction(isEnabled: isEnabled)
    }

    static func menuReloginAction(isEnabled: Bool) -> AccountCardMenuActionViewData {
        .init(
            id: "relogin-menu",
            actionID: .relogin,
            title: NSLocalizedString("codex.accounts.relogin", value: "Re-login", comment: "Re-login account"),
            systemImage: "person.badge.key",
            role: nil,
            isEnabled: isEnabled
        )
    }

    static func menuActivateAction() -> AccountCardMenuActionViewData {
        .init(
            id: "activate",
            actionID: .activate,
            title: NSLocalizedString("codex.accounts.action.activate", value: "Activate", comment: "Activate account"),
            systemImage: "checkmark.circle",
            role: nil,
            isEnabled: true
        )
    }

    static func menuCopyAccountIDAction() -> AccountCardMenuActionViewData {
        .init(
            id: "copy-account-id",
            actionID: .copyAccountID,
            title: NSLocalizedString("codex.accounts.menu.copy_account_id", value: "Copy Account ID", comment: "Copy account id"),
            systemImage: "number",
            role: nil,
            isEnabled: true
        )
    }

    static func menuCopyAuthPathAction() -> AccountCardMenuActionViewData {
        .init(
            id: "copy-auth-path",
            actionID: .copyAuthPath,
            title: NSLocalizedString("codex.accounts.menu.copy_auth_path", value: "Copy Auth Path", comment: "Copy auth path"),
            systemImage: "doc.on.doc",
            role: nil,
            isEnabled: true
        )
    }

    static func menuCopyAuthJSONAction() -> AccountCardMenuActionViewData {
        .init(
            id: "copy-auth-json",
            actionID: .copyAuthJSON,
            title: NSLocalizedString("codex.accounts.menu.copy_auth_json", value: "Copy auth.json", comment: "Copy auth json"),
            systemImage: "doc.on.doc.fill",
            role: nil,
            isEnabled: true
        )
    }

    static func menuEditAuthJSONAction() -> AccountCardMenuActionViewData {
        .init(
            id: "edit-auth-json",
            actionID: .editAuthJSON,
            title: NSLocalizedString("codex.accounts.menu.edit_auth_json", value: "Edit auth.json", comment: "Edit auth json"),
            systemImage: "pencil",
            role: nil,
            isEnabled: true
        )
    }

    static func menuRevealInFinderAction() -> AccountCardMenuActionViewData {
        .init(
            id: "reveal",
            actionID: .revealInFinder,
            title: NSLocalizedString("action.show_in_finder", comment: "Show in Finder"),
            systemImage: "folder",
            role: nil,
            isEnabled: true
        )
    }

    static func menuDeleteAction() -> AccountCardMenuActionViewData {
        AccountCardActionFactory.menuDeleteAction()
    }
}
