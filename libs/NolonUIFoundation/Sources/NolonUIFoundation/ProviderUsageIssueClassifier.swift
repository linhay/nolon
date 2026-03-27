import Foundation

public typealias ProviderUsageIssueCode = ProviderUsageIssueClassifier.IssueCode

public enum ProviderUsageIssueClassifier {
    public enum IssueCode: String, Equatable {
        case binary
        case auth
        case parse
        case timeout
        case unsupported
        case unknown
    }

    public static func classify(
        providerID: String,
        errorText: String,
        usageErrorCode: String?
    ) -> IssueCode {
        if let usageErrorCode {
            switch usageErrorCode {
            case "unsupported":
                return .unsupported
            case "missingToken", "missingAccount", "authExpired":
                return .auth
            default:
                break
            }
        }

        let text = normalized(errorText)
        if text.contains("timeout") || text.contains("timed out") {
            return .timeout
        }
        if text.contains("unauthorized")
            || text.contains("forbidden")
            || text.contains("401")
            || text.contains("403")
            || text.contains("auth")
            || text.contains("token")
            || text.contains("login")
        {
            return .auth
        }
        if text.contains("parse")
            || text.contains("decode")
            || text.contains("json")
            || text.contains("format")
            || text.contains("invalid")
        {
            return .parse
        }
        if text.contains("binary")
            || text.contains("executable")
            || text.contains("command not found")
            || text.contains("no such file")
            || text.contains("not found")
        {
            return .binary
        }
        if isGeminiFamily(providerID: providerID) {
            return .unsupported
        }
        return .unknown
    }

    public static func hints(providerID: String, code: IssueCode) -> [String] {
        var values: [String] = []
        switch code {
        case .binary:
            values.append("检查相关 CLI 二进制是否可执行并在 PATH 中。")
        case .auth:
            values.append("检查登录态是否有效，必要时重新执行登录。")
        case .parse:
            values.append("检查 usage 返回格式是否可解析。")
        case .timeout:
            values.append("出现超时，请稍后重试并检查网络连接。")
        case .unsupported:
            values.append("当前 provider 暂未支持该 usage 读取路径。")
        case .unknown:
            values.append("查看错误原文并重试。")
        }

        if providerID == "gemini" {
            values.append("可尝试点击顶部“登录”重新走 Gemini OAuth。")
        } else if providerID == "antigravity" {
            values.append("可尝试点击顶部“登录”重新走 Antigravity OAuth。")
        }
        return values
    }

    public static func isGeminiFamily(providerID: String) -> Bool {
        providerID == "gemini" || providerID == "antigravity"
    }

    private static func normalized(_ raw: String) -> String {
        raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }
}
