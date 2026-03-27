import SwiftUI

public struct McpConfigUnsupportedStateView: View {
    let title: String
    let systemImage: String
    let description: String

    public init(
        title: String = NSLocalizedString(
            "mcp.not_supported",
            value: "MCP Not Supported",
            comment: "MCP unsupported title"
        ),
        systemImage: String = "exclamationmark.triangle",
        description: String = NSLocalizedString(
            "mcp.not_supported_desc",
            value: "This provider does not support MCP configuration",
            comment: "MCP unsupported description"
        )
    ) {
        self.title = title
        self.systemImage = systemImage
        self.description = description
    }

    public var body: some View {
        UnavailableStateView(
            title: title,
            systemImage: systemImage,
            description: description
        )
    }
}

public struct McpConfigActionStateView: View {
    public enum Preset {
        case noConfiguration
        case noServers
    }

    let title: String
    let systemImage: String
    let description: String
    let actionTitle: String
    let onAction: () -> Void

    public init(
        title: String,
        systemImage: String,
        description: String,
        actionTitle: String,
        onAction: @escaping () -> Void
    ) {
        self.title = title
        self.systemImage = systemImage
        self.description = description
        self.actionTitle = actionTitle
        self.onAction = onAction
    }

    public init(
        preset: Preset,
        onAction: @escaping () -> Void
    ) {
        switch preset {
        case .noConfiguration:
            self.title = NSLocalizedString(
                "No Configuration",
                value: "No Configuration",
                comment: "MCP config missing title"
            )
            self.systemImage = "server.rack"
            self.description = NSLocalizedString(
                "MCP configuration file not found.",
                value: "MCP configuration file not found.",
                comment: "MCP config missing description"
            )
            self.actionTitle = NSLocalizedString(
                "Create Configuration",
                value: "Create Configuration",
                comment: "Create MCP config action"
            )
        case .noServers:
            self.title = NSLocalizedString(
                "No Servers",
                value: "No Servers",
                comment: "No MCP servers title"
            )
            self.systemImage = "server.rack"
            self.description = NSLocalizedString(
                "No MCP servers configured.",
                value: "No MCP servers configured.",
                comment: "No MCP servers description"
            )
            self.actionTitle = NSLocalizedString(
                "Edit Configuration",
                value: "Edit Configuration",
                comment: "Edit MCP config action"
            )
        }
        self.onAction = onAction
    }

    public var body: some View {
        ActionUnavailableStateView(
            title: title,
            systemImage: systemImage,
            description: description,
            actionTitle: actionTitle
        ) {
            onAction()
        }
    }
}

public struct McpConfigNoResultsStateView: View {
    let title: String
    let systemImage: String
    let description: String

    public init(
        title: String = NSLocalizedString(
            "mcp.empty.no_results.title",
            value: "No Results",
            comment: "MCP no results title"
        ),
        systemImage: String = "magnifyingglass",
        description: String = NSLocalizedString(
            "mcp.empty.no_results.desc",
            value: "No matching MCP servers found",
            comment: "MCP no results description"
        )
    ) {
        self.title = title
        self.systemImage = systemImage
        self.description = description
    }

    public var body: some View {
        UnavailableStateView(
            title: title,
            systemImage: systemImage,
            description: description
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
