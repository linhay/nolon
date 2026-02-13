import ArgumentParser

struct NolonRootCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "nolon",
        subcommands: [NolonCodexRootCommand.self]
    )
}

struct NolonCodexRootCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "codex",
        subcommands: [NolonCodexAuthGroupCommand.self, NolonCodexBinaryGroupCommand.self, NolonCodexStatusGroupCommand.self]
    )
}

struct NolonCodexAuthGroupCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "auth",
        subcommands: [
            NolonCodexAuthListCommand.self,
            NolonCodexAuthStatusCommand.self,
            NolonCodexAuthActivateCommand.self,
            NolonCodexAuthLoginCommand.self,
            NolonCodexAuthDeleteCommand.self,
        ]
    )
}

struct NolonCodexBinaryGroupCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "binary",
        subcommands: [
            NolonCodexBinaryListCommand.self,
            NolonCodexBinaryCurrentCommand.self,
            NolonCodexBinaryInstallCommand.self,
            NolonCodexBinaryUseCommand.self,
            NolonCodexBinaryDoctorCommand.self,
        ]
    )
}

struct NolonCodexStatusGroupCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "status",
        subcommands: [NolonCodexStatusProbeCommand.self]
    )
}

struct NolonCodexAuthListCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "list")

    @Option(name: .long, help: "Provider id, default is codex.")
    var provider: String = "codex"
}

struct NolonCodexAuthStatusCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "status")

    @Option(name: .long, help: "Provider id, default is codex.")
    var provider: String = "codex"
}

struct NolonCodexAuthActivateCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "activate")

    @Option(name: .long, help: "Provider id, default is codex.")
    var provider: String = "codex"

    @Option(name: .long, help: "Account id UUID.")
    var accountID: String
}

struct NolonCodexAuthLoginCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "login")

    @Option(name: .long, help: "Provider id, default is codex.")
    var provider: String = "codex"

    @Option(name: .long, help: "Preferred account id UUID for snapshot update.")
    var preferredAccountID: String?
}

struct NolonCodexAuthDeleteCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "delete")

    @Option(name: .long, help: "Provider id, default is codex.")
    var provider: String = "codex"

    @Option(name: .long, help: "Account id UUID.")
    var accountID: String
}

struct NolonCodexBinaryInstallCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "install")

    @Option(name: .long, help: "Version tag to install, e.g. 0.26.0 or rust-v0.26.0.")
    var version: String

    @Flag(name: .long, help: "Activate this version after install.")
    var setDefault: Bool = false
}

struct NolonCodexBinaryListCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "list")
}

struct NolonCodexBinaryCurrentCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "current")
}

struct NolonCodexBinaryUseCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "use")

    @Option(name: .long, help: "Version id or semantic version.")
    var version: String
}

struct NolonCodexBinaryDoctorCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "doctor")
}

struct NolonCodexStatusProbeCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "probe")

    @Option(name: .long, help: "Provider id for reporting context.")
    var provider: String?
}
