import Foundation

enum NolonCodexCLIHelpResolver {
    static func resolvedHelpText(arguments: [String]) -> String? {
        let normalized = arguments.map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
        if normalized.isEmpty {
            return rootHelpText()
        }
        guard let key = NolonCLIHelpPath(arguments: normalized) else { return nil }
        switch key {
        case .root:
            return rootHelpText()
        case .codex:
            return codexHelpText()
        case .codexAuth:
            return codexAuthHelpText()
        case .codexBinary:
            return codexBinaryHelpText()
        case .codexStatus:
            return codexStatusHelpText()
        case .codexRuntime:
            return codexRuntimeHelpText()
        case .codexAuthList:
            return codexAuthListHelpText()
        case .codexAuthStatus:
            return codexAuthStatusHelpText()
        case .codexAuthActivate:
            return codexAuthActivateHelpText()
        case .codexAuthLogin:
            return codexAuthLoginHelpText()
        case .codexAuthDelete:
            return codexAuthDeleteHelpText()
        case .codexBinaryInstall:
            return codexBinaryInstallHelpText()
        case .codexBinaryList:
            return codexBinaryListHelpText()
        case .codexBinaryCurrent:
            return codexBinaryCurrentHelpText()
        case .codexBinaryDoctor:
            return codexBinaryDoctorHelpText()
        case .codexBinaryUse:
            return codexBinaryUseHelpText()
        case .codexStatusProbe:
            return codexStatusProbeHelpText()
        case .codexRuntimeList:
            return codexRuntimeListHelpText()
        case .codexRuntimeStop:
            return codexRuntimeStopHelpText()
        default:
            return nil
        }
    }

    private static func rootHelpText() -> String {
        codexHelpText()
    }

    private static func codexHelpText() -> String {
        """
        Usage: nolon codex <group> <action> [options]

        Groups:
          auth      list | status | activate | login | delete
          binary    list | current | install | use | doctor
          status    probe
          runtime   list | stop

        Examples:
          nolon codex auth list --provider codex
          nolon codex binary current
          nolon codex status probe --provider codex
        """
    }

    private static func codexAuthHelpText() -> String {
        """
        Usage: nolon codex auth <action> [options]

        Actions:
          list      [--provider codex|codex-xcode]
          status    [--provider codex|codex-xcode]
          activate  [--account-id <uuid>] [--tui] [--provider ...]
          login     [--preferred-account-id <uuid>] [--provider ...]
          delete    --account-id <uuid> [--provider ...]
        """
    }

    private static func codexBinaryHelpText() -> String {
        """
        Usage: nolon codex binary <action> [options]

        Actions:
          list
          current
          install  --version <version-or-tag> [--set-default]
          use      --version <version-or-id>
          doctor
        """
    }

    private static func codexStatusHelpText() -> String {
        """
        Usage: nolon codex status <action> [options]

        Actions:
          probe    [--provider codex|codex-xcode]
        """
    }

    private static func codexRuntimeHelpText() -> String {
        """
        Usage: nolon codex runtime <action> [options]

        Actions:
          list
          stop     --pid <pid> [--force] [--timeout-seconds <n>]
        """
    }

    private static func codexAuthListHelpText() -> String {
        """
        Usage: nolon codex auth list [options]

        Options:
          --provider <id>   Provider id, default is codex.
        """
    }

    private static func codexAuthStatusHelpText() -> String {
        """
        Usage: nolon codex auth status [options]

        Options:
          --provider <id>   Provider id, default is codex.
        """
    }

    private static func codexAuthActivateHelpText() -> String {
        """
        Usage: nolon codex auth activate [--account-id <uuid>] [--tui] [--provider <id>]

        Options:
          --provider <id>     Provider id, default is codex.
          --account-id <id>   Account id UUID.
          --tui               Use TUI picker when account id is omitted.
        """
    }

    private static func codexAuthLoginHelpText() -> String {
        """
        Usage: nolon codex auth login [--provider <id>] [--preferred-account-id <uuid>]

        Options:
          --provider <id>               Provider id, default is codex.
          --preferred-account-id <id>   Preferred account id UUID for snapshot update.
        """
    }

    private static func codexAuthDeleteHelpText() -> String {
        """
        Usage: nolon codex auth delete --account-id <uuid> [--provider <id>]

        Options:
          --provider <id>     Provider id, default is codex.
          --account-id <id>   Account id UUID.
        """
    }

    private static func codexBinaryInstallHelpText() -> String {
        """
        Usage: nolon codex binary install --version <version-or-tag> [--set-default]

        Options:
          --version <value>   Version tag to install, e.g. 0.26.0 or rust-v0.26.0.
          --set-default       Activate this version after install.
        """
    }

    private static func codexBinaryListHelpText() -> String {
        """
        Usage: nolon codex binary list
        """
    }

    private static func codexBinaryCurrentHelpText() -> String {
        """
        Usage: nolon codex binary current
        """
    }

    private static func codexBinaryDoctorHelpText() -> String {
        """
        Usage: nolon codex binary doctor
        """
    }

    private static func codexBinaryUseHelpText() -> String {
        """
        Usage: nolon codex binary use --version <version-or-id>

        Options:
          --version <value>   Version id or semantic version.
        """
    }

    private static func codexStatusProbeHelpText() -> String {
        """
        Usage: nolon codex status probe [--provider <id>]

        Options:
          --provider <id>   Provider id for reporting context.
        """
    }

    private static func codexRuntimeListHelpText() -> String {
        """
        Usage: nolon codex runtime list
        """
    }

    private static func codexRuntimeStopHelpText() -> String {
        """
        Usage: nolon codex runtime stop --pid <pid> [--force] [--timeout-seconds <n>]

        Options:
          --pid <value>             Target runtime pid.
          --force                   Send SIGKILL immediately.
          --timeout-seconds <n>     Timeout seconds before escalating TERM to KILL.
        """
    }
}

private struct NolonCLIHelpPath: RawRepresentable, ExpressibleByStringLiteral, Equatable, Sendable {
    static let root: Self = "help.root"
    static let codex: Self = "help.codex"
    static let codexAuth: Self = "help.codex.auth"
    static let codexBinary: Self = "help.codex.binary"
    static let codexStatus: Self = "help.codex.status"
    static let codexRuntime: Self = "help.codex.runtime"
    static let codexAuthList: Self = "help.codex.auth.list"
    static let codexAuthStatus: Self = "help.codex.auth.status"
    static let codexAuthActivate: Self = "help.codex.auth.activate"
    static let codexAuthLogin: Self = "help.codex.auth.login"
    static let codexAuthDelete: Self = "help.codex.auth.delete"
    static let codexBinaryInstall: Self = "help.codex.binary.install"
    static let codexBinaryList: Self = "help.codex.binary.list"
    static let codexBinaryCurrent: Self = "help.codex.binary.current"
    static let codexBinaryDoctor: Self = "help.codex.binary.doctor"
    static let codexBinaryUse: Self = "help.codex.binary.use"
    static let codexStatusProbe: Self = "help.codex.status.probe"
    static let codexRuntimeList: Self = "help.codex.runtime.list"
    static let codexRuntimeStop: Self = "help.codex.runtime.stop"

    let rawValue: String

    init(rawValue: String) {
        self.rawValue = rawValue
    }

    init(_ value: String) {
        self.rawValue = value
    }

    init(stringLiteral value: String) {
        self.rawValue = value
    }

    init?(arguments: [String]) {
        switch arguments {
        case []:
            self = .root
            return
        case ["codex"]:
            self = .codex
            return
        case ["codex", "auth"]:
            self = .codexAuth
            return
        case ["codex", "binary"]:
            self = .codexBinary
            return
        case ["codex", "status"]:
            self = .codexStatus
            return
        case ["codex", "runtime"]:
            self = .codexRuntime
            return
        default:
            break
        }

        let flag = arguments.last
        guard flag == "help" || flag == "-h" || flag == "--help" else {
            return nil
        }
        switch arguments {
        case ["help"], ["-h"], ["--help"]:
            self = .root
        case ["codex", "help"], ["codex", "-h"], ["codex", "--help"]:
            self = .codex
        case ["codex", "auth", "help"], ["codex", "auth", "-h"], ["codex", "auth", "--help"]:
            self = .codexAuth
        case ["codex", "binary", "help"], ["codex", "binary", "-h"], ["codex", "binary", "--help"]:
            self = .codexBinary
        case ["codex", "status", "help"], ["codex", "status", "-h"], ["codex", "status", "--help"]:
            self = .codexStatus
        case ["codex", "runtime", "help"], ["codex", "runtime", "-h"], ["codex", "runtime", "--help"]:
            self = .codexRuntime
        case ["codex", "auth", "list", "help"], ["codex", "auth", "list", "-h"], ["codex", "auth", "list", "--help"]:
            self = .codexAuthList
        case ["codex", "auth", "status", "help"], ["codex", "auth", "status", "-h"], ["codex", "auth", "status", "--help"]:
            self = .codexAuthStatus
        case ["codex", "auth", "activate", "help"], ["codex", "auth", "activate", "-h"], ["codex", "auth", "activate", "--help"]:
            self = .codexAuthActivate
        case ["codex", "auth", "login", "help"], ["codex", "auth", "login", "-h"], ["codex", "auth", "login", "--help"]:
            self = .codexAuthLogin
        case ["codex", "auth", "delete", "help"], ["codex", "auth", "delete", "-h"], ["codex", "auth", "delete", "--help"]:
            self = .codexAuthDelete
        case ["codex", "binary", "install", "help"], ["codex", "binary", "install", "-h"], ["codex", "binary", "install", "--help"]:
            self = .codexBinaryInstall
        case ["codex", "binary", "list", "help"], ["codex", "binary", "list", "-h"], ["codex", "binary", "list", "--help"]:
            self = .codexBinaryList
        case ["codex", "binary", "current", "help"], ["codex", "binary", "current", "-h"], ["codex", "binary", "current", "--help"]:
            self = .codexBinaryCurrent
        case ["codex", "binary", "doctor", "help"], ["codex", "binary", "doctor", "-h"], ["codex", "binary", "doctor", "--help"]:
            self = .codexBinaryDoctor
        case ["codex", "binary", "use", "help"], ["codex", "binary", "use", "-h"], ["codex", "binary", "use", "--help"]:
            self = .codexBinaryUse
        case ["codex", "status", "probe", "help"], ["codex", "status", "probe", "-h"], ["codex", "status", "probe", "--help"]:
            self = .codexStatusProbe
        case ["codex", "runtime", "list", "help"], ["codex", "runtime", "list", "-h"], ["codex", "runtime", "list", "--help"]:
            self = .codexRuntimeList
        case ["codex", "runtime", "stop", "help"], ["codex", "runtime", "stop", "-h"], ["codex", "runtime", "stop", "--help"]:
            self = .codexRuntimeStop
        default:
            return nil
        }
    }
}
