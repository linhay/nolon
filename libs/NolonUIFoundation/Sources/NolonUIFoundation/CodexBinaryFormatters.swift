import Foundation

public enum CodexBinaryFormatters {
    public static func byteProgressText(completed: Int64, total: Int64) -> String {
        if total <= 0 {
            return String(
                format: NSLocalizedString(
                    "codex.binary.download.progress.single",
                    value: "Downloaded %@",
                    comment: "Download progress bytes without total"
                ),
                byteText(completed)
            )
        }
        return String(
            format: NSLocalizedString(
                "codex.binary.download.progress",
                value: "%@ / %@",
                comment: "Download progress bytes"
            ),
            byteText(completed),
            byteText(total)
        )
    }

    public static func byteText(_ value: Int64) -> String {
        let kb: Double = 1024
        let mb = kb * 1024
        let gb = mb * 1024
        let bytes = Double(value)
        if bytes >= gb { return String(format: "%.1f GB", bytes / gb) }
        if bytes >= mb { return String(format: "%.1f MB", bytes / mb) }
        if bytes >= kb { return String(format: "%.1f KB", bytes / kb) }
        return String(format: "%.0f B", bytes)
    }
}
