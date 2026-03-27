import Foundation

public enum TokenCountFormatters {
    public static func compact(_ value: Int) -> String {
        if value >= 100_000_000 {
            return String(format: "%.1f亿", Double(value) / 100_000_000)
        }
        if value >= 1_000_000 {
            return String(format: "%.1fM", Double(value) / 1_000_000)
        }
        if value >= 1_000 {
            return String(format: "%.1fK", Double(value) / 1_000)
        }
        return "\(value)"
    }
}
