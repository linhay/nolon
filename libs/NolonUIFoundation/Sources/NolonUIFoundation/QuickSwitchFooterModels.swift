import Foundation

public struct QuickSwitchFooterActionData: Identifiable, Equatable, Sendable {
    public let id: String
    public let systemImage: String
    public let tooltip: String

    public init(
        id: String,
        systemImage: String,
        tooltip: String
    ) {
        self.id = id
        self.systemImage = systemImage
        self.tooltip = tooltip
    }

    public static func `default`() -> [QuickSwitchFooterActionData] {
        [
            .init(
                id: "add",
                systemImage: "plus",
                tooltip: NSLocalizedString("quickswitch.footer.add", value: "添加账号", comment: "Quick switch footer add")
            ),
            .init(
                id: "refresh",
                systemImage: "arrow.clockwise",
                tooltip: NSLocalizedString("quickswitch.footer.refresh", value: "刷新配额", comment: "Quick switch footer refresh")
            ),
            .init(
                id: "auth",
                systemImage: "lock.doc.fill",
                tooltip: NSLocalizedString("quickswitch.footer.auth", value: "auth.json", comment: "Quick switch footer auth")
            ),
            .init(
                id: "config",
                systemImage: "gearshape.fill",
                tooltip: NSLocalizedString("quickswitch.footer.config", value: "config.toml", comment: "Quick switch footer config")
            )
        ]
    }
}

public struct QuickSwitchFooterData: Equatable, Sendable {
    public let actions: [QuickSwitchFooterActionData]
    public let quitTitle: String

    public init(
        actions: [QuickSwitchFooterActionData] = QuickSwitchFooterActionData.default(),
        quitTitle: String = NSLocalizedString(
            "quickswitch.footer.quit",
            value: "退出",
            comment: "Quick switch footer quit"
        )
    ) {
        self.actions = actions
        self.quitTitle = quitTitle
    }
}
