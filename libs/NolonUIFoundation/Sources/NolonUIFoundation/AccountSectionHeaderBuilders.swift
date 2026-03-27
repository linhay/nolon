import Foundation

public enum AccountSectionHeaderBuilders {
    public static func shortLabel(from title: String) -> String {
        String(title.prefix(1)).uppercased()
    }

    public static func accountCountText(_ count: Int) -> String {
        let unit = NSLocalizedString(
            "accounts.section.accounts",
            value: "accounts",
            comment: "accounts unit"
        )
        return "\(count) \(unit)"
    }
}
