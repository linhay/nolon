import Foundation

// swiftformat:disable sortDeclarations
public enum UsageProvider: String, CaseIterable, Sendable, Codable {
    case codex
    case claude
    case cursor
    case opencode
    case factory
    case gemini
    case antigravity
    case copilot
    case zai
    case minimax
    case kimi
    case kiro
    case vertexai
    case augment
    case jetbrains
    case kimik2
    case amp
    case synthetic
}
// swiftformat:enable sortDeclarations

public enum IconStyle: Sendable, CaseIterable {
    case codex
    case claude
    case zai
    case minimax
    case gemini
    case antigravity
    case cursor
    case opencode
    case factory
    case copilot
    case kimi
    case kimik2
    case kiro
    case vertexai
    case augment
    case jetbrains
    case amp
    case synthetic
    case combined
}

public struct ProviderColor: Sendable, Equatable {
    public let red: Double
    public let green: Double
    public let blue: Double

    public init(red: Double, green: Double, blue: Double) {
        self.red = red
        self.green = green
        self.blue = blue
    }
}

public struct ProviderBranding: Sendable {
    public let iconStyle: IconStyle
    public let iconResourceName: String
    public let color: ProviderColor

    public init(iconStyle: IconStyle, iconResourceName: String, color: ProviderColor) {
        self.iconStyle = iconStyle
        self.iconResourceName = iconResourceName
        self.color = color
    }
}

