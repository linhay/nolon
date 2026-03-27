import Foundation

public enum CodexRuntimeBuilders {
    public static func pidText(_ pid: Int) -> String {
        String(
            format: NSLocalizedString(
                "codex.runtime.pid.label",
                value: "PID %d",
                comment: "Runtime PID label"
            ),
            pid
        )
    }

    public static func forceStopActionTitle(pid: Int) -> String {
        String(
            format: NSLocalizedString(
                "codex.runtime.force_stop.action",
                value: "Force Stop PID %d",
                comment: "Force stop action"
            ),
            pid
        )
    }

    public static func diagnosticLabel(for key: String) -> String {
        switch key {
        case "provider":
            return NSLocalizedString("codex.runtime.diag.provider", value: "Provider", comment: "Runtime diagnostics provider label")
        case "accounts":
            return NSLocalizedString("codex.runtime.diag.accounts", value: "Accounts", comment: "Runtime diagnostics accounts label")
        case "active":
            return NSLocalizedString("codex.runtime.diag.active", value: "Active", comment: "Runtime diagnostics active account label")
        case "running":
            return NSLocalizedString("codex.runtime.diag.running", value: "Running", comment: "Runtime diagnostics running count label")
        case "binary":
            return NSLocalizedString("codex.runtime.diag.binary", value: "Binary", comment: "Runtime diagnostics binary label")
        case "pathActive":
            return NSLocalizedString("codex.runtime.diag.path_active", value: "Path Active", comment: "Runtime diagnostics path active label")
        case "executable":
            return NSLocalizedString("codex.runtime.diag.executable", value: "Executable", comment: "Runtime diagnostics executable label")
        case "hint":
            return NSLocalizedString("codex.runtime.diag.hint", value: "Hint", comment: "Runtime diagnostics hint label")
        default:
            return key
        }
    }

    public static func booleanText(_ value: Bool) -> String {
        value
            ? NSLocalizedString(
                "codex.runtime.bool.true",
                value: "true",
                comment: "Runtime boolean true"
            )
            : NSLocalizedString(
                "codex.runtime.bool.false",
                value: "false",
                comment: "Runtime boolean false"
            )
    }

    public static func stopSummary(pid: Int32, signal: String, exited: Bool) -> String {
        String(
            format: NSLocalizedString(
                "codex.runtime.stop.summary",
                value: "PID %d (%@) -> exited=%@",
                comment: "Runtime stop summary"
            ),
            pid,
            signal.uppercased(),
            booleanText(exited)
        )
    }
}
