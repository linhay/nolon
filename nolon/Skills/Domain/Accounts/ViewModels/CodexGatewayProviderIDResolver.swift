import Foundation
import ProviderCatalog

enum CodexGatewayProviderIDResolver {
    static func resolve(provider: Provider) -> String? {
        let normalizedTemplateID = TextNormalizationSupport.trimmed(provider.templateId)?.lowercased()
        let normalizedProviderID = TextNormalizationSupport.trimmed(provider.id)?.lowercased()

        switch normalizedTemplateID {
        case ProviderTemplate.codex.rawValue.lowercased():
            return "codex"
        case ProviderTemplate.codexXcode.rawValue.lowercased():
            return "codex-xcode"
        default:
            break
        }

        switch normalizedProviderID {
        case "codex":
            return "codex"
        case "codex-xcode":
            return "codex-xcode"
        default:
            return nil
        }
    }

    static func resolveOrDefault(provider: Provider, defaultProviderID: String = "codex") -> String {
        resolve(provider: provider) ?? defaultProviderID
    }
}
