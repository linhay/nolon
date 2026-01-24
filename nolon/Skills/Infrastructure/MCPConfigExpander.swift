import Foundation
import STJSON

/// Utility to expand environment variables in MCP configurations
public struct MCPConfigExpander {
    
    /// Expands environment variables in a JSON object
    /// Supports `${VAR}` and `${VAR:-default}` syntax
    public static func expand(_ json: JSON) -> JSON {
        switch json.type {
        case .string:
            return JSON(expandString(json.stringValue))
        case .array:
            return JSON(json.arrayValue.map { expand($0) })
        case .dictionary:
            var dict = [String: JSON]()
            for (key, value) in json.dictionaryValue {
                dict[key] = expand(value)
            }
            return JSON(dict)
        default:
            return json
        }
    }
    
    /// Expands variables in a single string
    private static func expandString(_ value: String) -> String {
        let pattern = #"\$\{([^}:]+)(?::-([^}]*))?\}"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return value
        }
        
        let nsString = value as NSString
        var result = value
        let matches = regex.matches(in: value, options: [], range: NSRange(location: 0, length: nsString.length))
        
        // Reverse order to avoid range issues when replacing
        for match in matches.reversed() {
            let varName = nsString.substring(with: match.range(at: 1))
            let defaultValue: String? = match.range(at: 2).location != NSNotFound ? nsString.substring(with: match.range(at: 2)) : nil
            
            let envValue = ProcessInfo.processInfo.environment[varName]
            let resolvedValue = envValue ?? defaultValue ?? ""
            
            result = (result as NSString).replacingCharacters(in: match.range, with: resolvedValue)
        }
        
        return result
    }
}
