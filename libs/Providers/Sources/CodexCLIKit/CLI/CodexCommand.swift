import Foundation

public enum CodexSandboxMode: String, Sendable, Equatable {
    case readOnly = "read-only"
    case workspaceWrite = "workspace-write"
    case dangerFullAccess = "danger-full-access"
}

public enum CodexApprovalPolicy: String, Sendable, Equatable {
    case untrusted
    case onFailure = "on-failure"
    case onRequest = "on-request"
    case never
}

public enum CodexLocalProvider: String, Sendable, Equatable {
    case lmstudio
    case ollama
}

public enum CodexColorMode: String, Sendable, Equatable {
    case always
    case never
    case auto
}

public enum CodexCompletionShell: String, Sendable, Equatable {
    case bash
    case elvish
    case fish
    case powershell
    case zsh
}

public struct CodexGlobalOptions: Sendable, Equatable {
    public var configOverrides: [String] = []
    public var enabledFeatures: [String] = []
    public var disabledFeatures: [String] = []
    public var images: [String] = []
    public var model: String?
    public var useOSS: Bool = false
    public var localProvider: CodexLocalProvider?
    public var profile: String?
    public var sandbox: CodexSandboxMode?
    public var askForApproval: CodexApprovalPolicy?
    public var fullAuto: Bool = false
    public var bypassApprovalsAndSandbox: Bool = false
    public var workingDirectory: String?
    public var search: Bool = false
    public var additionalWritableDirectories: [String] = []
    public var noAltScreen: Bool = false
    public var rawOptions: [String] = []

    public init(
        configOverrides: [String] = [],
        enabledFeatures: [String] = [],
        disabledFeatures: [String] = [],
        images: [String] = [],
        model: String? = nil,
        useOSS: Bool = false,
        localProvider: CodexLocalProvider? = nil,
        profile: String? = nil,
        sandbox: CodexSandboxMode? = nil,
        askForApproval: CodexApprovalPolicy? = nil,
        fullAuto: Bool = false,
        bypassApprovalsAndSandbox: Bool = false,
        workingDirectory: String? = nil,
        search: Bool = false,
        additionalWritableDirectories: [String] = [],
        noAltScreen: Bool = false,
        rawOptions: [String] = []
    ) {
        self.configOverrides = configOverrides
        self.enabledFeatures = enabledFeatures
        self.disabledFeatures = disabledFeatures
        self.images = images
        self.model = model
        self.useOSS = useOSS
        self.localProvider = localProvider
        self.profile = profile
        self.sandbox = sandbox
        self.askForApproval = askForApproval
        self.fullAuto = fullAuto
        self.bypassApprovalsAndSandbox = bypassApprovalsAndSandbox
        self.workingDirectory = workingDirectory
        self.search = search
        self.additionalWritableDirectories = additionalWritableDirectories
        self.noAltScreen = noAltScreen
        self.rawOptions = rawOptions
    }

    public func render() -> [String] {
        var args: [String] = []
        for item in configOverrides {
            args.append("--config")
            args.append(item)
        }
        for feature in enabledFeatures {
            args.append("--enable")
            args.append(feature)
        }
        for feature in disabledFeatures {
            args.append("--disable")
            args.append(feature)
        }
        for image in images {
            args.append("--image")
            args.append(image)
        }
        if let model {
            args.append("--model")
            args.append(model)
        }
        if useOSS {
            args.append("--oss")
        }
        if let localProvider {
            args.append("--local-provider")
            args.append(localProvider.rawValue)
        }
        if let profile {
            args.append("--profile")
            args.append(profile)
        }
        if let sandbox {
            args.append("--sandbox")
            args.append(sandbox.rawValue)
        }
        if let askForApproval {
            args.append("--ask-for-approval")
            args.append(askForApproval.rawValue)
        }
        if fullAuto {
            args.append("--full-auto")
        }
        if bypassApprovalsAndSandbox {
            args.append("--dangerously-bypass-approvals-and-sandbox")
        }
        if let workingDirectory {
            args.append("--cd")
            args.append(workingDirectory)
        }
        if search {
            args.append("--search")
        }
        for directory in additionalWritableDirectories {
            args.append("--add-dir")
            args.append(directory)
        }
        if noAltScreen {
            args.append("--no-alt-screen")
        }
        args.append(contentsOf: rawOptions)
        return args
    }
}

public struct CodexRawCommand: Sendable, Equatable {
    public let args: [String]

    public init(args: [String]) {
        self.args = args
    }
}

public enum CodexTopLevelCommand: String, CaseIterable, Sendable {
    case exec
    case review
    case login
    case logout
    case mcp
    case mcpServer = "mcp-server"
    case appServer = "app-server"
    case app
    case completion
    case sandbox
    case debug
    case apply
    case resume
    case fork
    case cloud
    case features
}

public enum CodexExecSubcommand: Sendable, Equatable {
    case none
    case resume(last: Bool, all: Bool = false, sessionID: String?, prompt: String?)
    case review(prompt: String?)
    case raw([String])
}

public struct CodexExecOptions: Sendable, Equatable {
    public var prompt: String?
    public var skipGitRepoCheck: Bool = false
    public var outputSchemaFile: String?
    public var color: CodexColorMode?
    public var json: Bool = false
    public var outputLastMessageFile: String?
    public var subcommand: CodexExecSubcommand = .none
    public var rawOptions: [String] = []

    public init(
        prompt: String? = nil,
        skipGitRepoCheck: Bool = false,
        outputSchemaFile: String? = nil,
        color: CodexColorMode? = nil,
        json: Bool = false,
        outputLastMessageFile: String? = nil,
        subcommand: CodexExecSubcommand = .none,
        rawOptions: [String] = []
    ) {
        self.prompt = prompt
        self.skipGitRepoCheck = skipGitRepoCheck
        self.outputSchemaFile = outputSchemaFile
        self.color = color
        self.json = json
        self.outputLastMessageFile = outputLastMessageFile
        self.subcommand = subcommand
        self.rawOptions = rawOptions
    }

    public func render() -> [String] {
        var args: [String] = []
        if skipGitRepoCheck {
            args.append("--skip-git-repo-check")
        }
        if let outputSchemaFile {
            args.append("--output-schema")
            args.append(outputSchemaFile)
        }
        if let color {
            args.append("--color")
            args.append(color.rawValue)
        }
        if json {
            args.append("--json")
        }
        if let outputLastMessageFile {
            args.append("--output-last-message")
            args.append(outputLastMessageFile)
        }

        switch subcommand {
        case .none:
            if let prompt {
                args.append(prompt)
            }
        case let .resume(last, all, sessionID, prompt):
            args.append("resume")
            if last {
                args.append("--last")
            }
            if all {
                args.append("--all")
            }
            if let sessionID {
                args.append(sessionID)
            }
            if let prompt {
                args.append(prompt)
            }
        case let .review(prompt):
            args.append("review")
            if let prompt {
                args.append(prompt)
            }
        case let .raw(raw):
            args.append(contentsOf: raw)
        }

        args.append(contentsOf: rawOptions)
        return args
    }
}

public struct CodexReviewOptions: Sendable, Equatable {
    public var prompt: String?
    public var uncommitted: Bool = false
    public var baseBranch: String?
    public var commit: String?
    public var title: String?
    public var rawOptions: [String] = []

    public init(
        prompt: String? = nil,
        uncommitted: Bool = false,
        baseBranch: String? = nil,
        commit: String? = nil,
        title: String? = nil,
        rawOptions: [String] = []
    ) {
        self.prompt = prompt
        self.uncommitted = uncommitted
        self.baseBranch = baseBranch
        self.commit = commit
        self.title = title
        self.rawOptions = rawOptions
    }

    public func render() -> [String] {
        var args: [String] = []
        if uncommitted {
            args.append("--uncommitted")
        }
        if let baseBranch {
            args.append("--base")
            args.append(baseBranch)
        }
        if let commit {
            args.append("--commit")
            args.append(commit)
        }
        if let title {
            args.append("--title")
            args.append(title)
        }
        if let prompt {
            args.append(prompt)
        }
        args.append(contentsOf: rawOptions)
        return args
    }
}

public enum CodexLoginSubcommand: Sendable, Equatable {
    case none
    case status
}

public struct CodexLoginOptions: Sendable, Equatable {
    public var withAPIKey: Bool = false
    public var deviceAuth: Bool = false
    public var subcommand: CodexLoginSubcommand = .none
    public var rawOptions: [String] = []

    public init(
        withAPIKey: Bool = false,
        deviceAuth: Bool = false,
        subcommand: CodexLoginSubcommand = .none,
        rawOptions: [String] = []
    ) {
        self.withAPIKey = withAPIKey
        self.deviceAuth = deviceAuth
        self.subcommand = subcommand
        self.rawOptions = rawOptions
    }

    public func render() -> [String] {
        var args: [String] = []
        if withAPIKey {
            args.append("--with-api-key")
        }
        if deviceAuth {
            args.append("--device-auth")
        }
        switch subcommand {
        case .none:
            break
        case .status:
            args.append("status")
        }
        args.append(contentsOf: rawOptions)
        return args
    }
}

public struct CodexLogoutOptions: Sendable, Equatable {
    public var rawOptions: [String] = []

    public init(rawOptions: [String] = []) {
        self.rawOptions = rawOptions
    }

    public func render() -> [String] {
        rawOptions
    }
}

public enum CodexAppServerSubcommand: String, Sendable, Equatable {
    case generateTS = "generate-ts"
    case generateJSONSchema = "generate-json-schema"
}

public struct CodexAppServerOptions: Sendable, Equatable {
    public var analyticsDefaultEnabled: Bool = false
    public var subcommand: CodexAppServerSubcommand?
    public var rawOptions: [String] = []

    public init(
        analyticsDefaultEnabled: Bool = false,
        subcommand: CodexAppServerSubcommand? = nil,
        rawOptions: [String] = []
    ) {
        self.analyticsDefaultEnabled = analyticsDefaultEnabled
        self.subcommand = subcommand
        self.rawOptions = rawOptions
    }

    public func render() -> [String] {
        var args: [String] = []
        if analyticsDefaultEnabled {
            args.append("--analytics-default-enabled")
        }
        if let subcommand {
            args.append(subcommand.rawValue)
        }
        args.append(contentsOf: rawOptions)
        return args
    }
}

public struct CodexMCPServerOptions: Sendable, Equatable {
    public var rawOptions: [String] = []

    public init(rawOptions: [String] = []) {
        self.rawOptions = rawOptions
    }

    public func render() -> [String] {
        rawOptions
    }
}

public enum CodexMCPAction: Sendable, Equatable {
    case list(json: Bool = false)
    case get(name: String, json: Bool = false)
    case add(
        name: String,
        command: [String] = [],
        env: [String] = [],
        url: String? = nil,
        bearerTokenEnvVar: String? = nil
    )
    case remove(name: String)
    case login(name: String, scopes: [String] = [])
    case logout(name: String)
    case raw([String])
}

public struct CodexMCPOptions: Sendable, Equatable {
    public var action: CodexMCPAction
    public var rawOptions: [String] = []

    public init(action: CodexMCPAction, rawOptions: [String] = []) {
        self.action = action
        self.rawOptions = rawOptions
    }

    public func render() -> [String] {
        var args: [String] = []
        switch action {
        case let .list(json):
            args.append("list")
            if json {
                args.append("--json")
            }
        case let .get(name, json):
            args.append("get")
            args.append(name)
            if json {
                args.append("--json")
            }
        case let .add(name, command, env, url, bearerTokenEnvVar):
            args.append("add")
            args.append(name)
            for pair in env {
                args.append("--env")
                args.append(pair)
            }
            if let url {
                args.append("--url")
                args.append(url)
            }
            if let bearerTokenEnvVar {
                args.append("--bearer-token-env-var")
                args.append(bearerTokenEnvVar)
            }
            if !command.isEmpty {
                args.append("--")
                args.append(contentsOf: command)
            }
        case let .remove(name):
            args.append("remove")
            args.append(name)
        case let .login(name, scopes):
            args.append("login")
            args.append(name)
            if !scopes.isEmpty {
                args.append("--scopes")
                args.append(scopes.joined(separator: ","))
            }
        case let .logout(name):
            args.append("logout")
            args.append(name)
        case let .raw(raw):
            args.append(contentsOf: raw)
        }
        args.append(contentsOf: rawOptions)
        return args
    }
}

public struct CodexAppOptions: Sendable, Equatable {
    public var path: String?
    public var downloadURL: String?
    public var rawOptions: [String] = []

    public init(path: String? = nil, downloadURL: String? = nil, rawOptions: [String] = []) {
        self.path = path
        self.downloadURL = downloadURL
        self.rawOptions = rawOptions
    }

    public func render() -> [String] {
        var args: [String] = []
        if let downloadURL {
            args.append("--download-url")
            args.append(downloadURL)
        }
        if let path {
            args.append(path)
        }
        args.append(contentsOf: rawOptions)
        return args
    }
}

public struct CodexCompletionOptions: Sendable, Equatable {
    public var shell: CodexCompletionShell?
    public var rawOptions: [String] = []

    public init(shell: CodexCompletionShell? = nil, rawOptions: [String] = []) {
        self.shell = shell
        self.rawOptions = rawOptions
    }

    public func render() -> [String] {
        var args: [String] = []
        if let shell {
            args.append(shell.rawValue)
        }
        args.append(contentsOf: rawOptions)
        return args
    }
}

public enum CodexSandboxTarget: String, Sendable, Equatable {
    case macos
    case linux
    case windows
}

public struct CodexSandboxOptions: Sendable, Equatable {
    public var target: CodexSandboxTarget
    public var fullAuto: Bool = false
    public var logDenials: Bool = false
    public var command: [String] = []
    public var rawOptions: [String] = []

    public init(
        target: CodexSandboxTarget,
        fullAuto: Bool = false,
        logDenials: Bool = false,
        command: [String] = [],
        rawOptions: [String] = []
    ) {
        self.target = target
        self.fullAuto = fullAuto
        self.logDenials = logDenials
        self.command = command
        self.rawOptions = rawOptions
    }

    public func render() -> [String] {
        var args: [String] = [target.rawValue]
        if fullAuto {
            args.append("--full-auto")
        }
        if logDenials {
            args.append("--log-denials")
        }
        args.append(contentsOf: command)
        args.append(contentsOf: rawOptions)
        return args
    }
}

public enum CodexDebugAppServerSubcommand: Sendable, Equatable {
    case sendMessageV2(arguments: [String] = [])
    case raw([String])
}

public enum CodexDebugAction: Sendable, Equatable {
    case appServer(CodexDebugAppServerSubcommand)
    case raw([String])
}

public struct CodexDebugOptions: Sendable, Equatable {
    public var action: CodexDebugAction
    public var rawOptions: [String] = []

    public init(action: CodexDebugAction, rawOptions: [String] = []) {
        self.action = action
        self.rawOptions = rawOptions
    }

    public func render() -> [String] {
        var args: [String] = []
        switch action {
        case let .appServer(sub):
            args.append("app-server")
            switch sub {
            case let .sendMessageV2(arguments):
                args.append("send-message-v2")
                args.append(contentsOf: arguments)
            case let .raw(raw):
                args.append(contentsOf: raw)
            }
        case let .raw(raw):
            args.append(contentsOf: raw)
        }
        args.append(contentsOf: rawOptions)
        return args
    }
}

public struct CodexApplyOptions: Sendable, Equatable {
    public var taskID: String
    public var rawOptions: [String] = []

    public init(taskID: String, rawOptions: [String] = []) {
        self.taskID = taskID
        self.rawOptions = rawOptions
    }

    public func render() -> [String] {
        [taskID] + rawOptions
    }
}

public struct CodexResumeOptions: Sendable, Equatable {
    public var sessionID: String?
    public var prompt: String?
    public var last: Bool = false
    public var all: Bool = false
    public var rawOptions: [String] = []

    public init(
        sessionID: String? = nil,
        prompt: String? = nil,
        last: Bool = false,
        all: Bool = false,
        rawOptions: [String] = []
    ) {
        self.sessionID = sessionID
        self.prompt = prompt
        self.last = last
        self.all = all
        self.rawOptions = rawOptions
    }

    public func render() -> [String] {
        var args: [String] = []
        if last {
            args.append("--last")
        }
        if all {
            args.append("--all")
        }
        if let sessionID {
            args.append(sessionID)
        }
        if let prompt {
            args.append(prompt)
        }
        args.append(contentsOf: rawOptions)
        return args
    }
}

public typealias CodexForkOptions = CodexResumeOptions

public struct CodexCloudExecOptions: Sendable, Equatable {
    public var environmentID: String
    public var query: String?
    public var attempts: Int?
    public var branch: String?
    public var rawOptions: [String] = []

    public init(
        environmentID: String,
        query: String? = nil,
        attempts: Int? = nil,
        branch: String? = nil,
        rawOptions: [String] = []
    ) {
        self.environmentID = environmentID
        self.query = query
        self.attempts = attempts
        self.branch = branch
        self.rawOptions = rawOptions
    }

    public func render() -> [String] {
        var args: [String] = ["exec", "--env", environmentID]
        if let attempts {
            args.append("--attempts")
            args.append(String(attempts))
        }
        if let branch {
            args.append("--branch")
            args.append(branch)
        }
        if let query {
            args.append(query)
        }
        args.append(contentsOf: rawOptions)
        return args
    }
}

public struct CodexCloudTaskOptions: Sendable, Equatable {
    public var taskID: String
    public var attempt: Int?
    public var rawOptions: [String] = []

    public init(taskID: String, attempt: Int? = nil, rawOptions: [String] = []) {
        self.taskID = taskID
        self.attempt = attempt
        self.rawOptions = rawOptions
    }
}

public struct CodexCloudListOptions: Sendable, Equatable {
    public var environmentID: String?
    public var limit: Int?
    public var cursor: String?
    public var json: Bool = false
    public var rawOptions: [String] = []

    public init(
        environmentID: String? = nil,
        limit: Int? = nil,
        cursor: String? = nil,
        json: Bool = false,
        rawOptions: [String] = []
    ) {
        self.environmentID = environmentID
        self.limit = limit
        self.cursor = cursor
        self.json = json
        self.rawOptions = rawOptions
    }

    public func render() -> [String] {
        var args: [String] = ["list"]
        if let environmentID {
            args.append("--env")
            args.append(environmentID)
        }
        if let limit {
            args.append("--limit")
            args.append(String(limit))
        }
        if let cursor {
            args.append("--cursor")
            args.append(cursor)
        }
        if json {
            args.append("--json")
        }
        args.append(contentsOf: rawOptions)
        return args
    }
}

public enum CodexCloudAction: Sendable, Equatable {
    case exec(CodexCloudExecOptions)
    case status(CodexCloudTaskOptions)
    case list(CodexCloudListOptions)
    case apply(CodexCloudTaskOptions)
    case diff(CodexCloudTaskOptions)
    case raw([String])
}

public struct CodexCloudOptions: Sendable, Equatable {
    public var action: CodexCloudAction
    public var rawOptions: [String] = []

    public init(action: CodexCloudAction, rawOptions: [String] = []) {
        self.action = action
        self.rawOptions = rawOptions
    }

    public func render() -> [String] {
        var args: [String] = []
        switch action {
        case let .exec(options):
            args.append(contentsOf: options.render())
        case let .status(options):
            args.append("status")
            args.append(options.taskID)
            args.append(contentsOf: options.rawOptions)
        case let .list(options):
            args.append(contentsOf: options.render())
        case let .apply(options):
            args.append("apply")
            args.append(options.taskID)
            if let attempt = options.attempt {
                args.append("--attempt")
                args.append(String(attempt))
            }
            args.append(contentsOf: options.rawOptions)
        case let .diff(options):
            args.append("diff")
            args.append(options.taskID)
            if let attempt = options.attempt {
                args.append("--attempt")
                args.append(String(attempt))
            }
            args.append(contentsOf: options.rawOptions)
        case let .raw(raw):
            args.append(contentsOf: raw)
        }
        args.append(contentsOf: rawOptions)
        return args
    }
}

public enum CodexFeaturesAction: Sendable, Equatable {
    case list
    case enable(feature: String)
    case disable(feature: String)
    case raw([String])
}

public struct CodexFeaturesOptions: Sendable, Equatable {
    public var action: CodexFeaturesAction
    public var rawOptions: [String] = []

    public init(action: CodexFeaturesAction, rawOptions: [String] = []) {
        self.action = action
        self.rawOptions = rawOptions
    }

    public func render() -> [String] {
        var args: [String] = []
        switch action {
        case .list:
            args.append("list")
        case let .enable(feature):
            args.append("enable")
            args.append(feature)
        case let .disable(feature):
            args.append("disable")
            args.append(feature)
        case let .raw(raw):
            args.append(contentsOf: raw)
        }
        args.append(contentsOf: rawOptions)
        return args
    }
}

public struct CodexCommand: Sendable, Equatable {
    public var globalOptions: CodexGlobalOptions
    public var command: CodexTopLevelCommand?
    public var arguments: [String]

    public init(
        globalOptions: CodexGlobalOptions = CodexGlobalOptions(),
        command: CodexTopLevelCommand? = nil,
        arguments: [String] = []
    ) {
        self.globalOptions = globalOptions
        self.command = command
        self.arguments = arguments
    }

    public func render() -> [String] {
        var args = globalOptions.render()
        if let command {
            args.append(command.rawValue)
        }
        args.append(contentsOf: arguments)
        return args
    }

    public static func raw(_ raw: CodexRawCommand, globalOptions: CodexGlobalOptions = CodexGlobalOptions()) -> CodexCommand {
        CodexCommand(globalOptions: globalOptions, command: nil, arguments: raw.args)
    }

    public static func exec(
        _ options: CodexExecOptions = CodexExecOptions(),
        globalOptions: CodexGlobalOptions = CodexGlobalOptions()
    ) -> CodexCommand {
        CodexCommand(globalOptions: globalOptions, command: .exec, arguments: options.render())
    }

    public static func review(
        _ options: CodexReviewOptions = CodexReviewOptions(),
        globalOptions: CodexGlobalOptions = CodexGlobalOptions()
    ) -> CodexCommand {
        CodexCommand(globalOptions: globalOptions, command: .review, arguments: options.render())
    }

    public static func login(
        _ options: CodexLoginOptions = CodexLoginOptions(),
        globalOptions: CodexGlobalOptions = CodexGlobalOptions()
    ) -> CodexCommand {
        CodexCommand(globalOptions: globalOptions, command: .login, arguments: options.render())
    }

    public static func logout(
        _ options: CodexLogoutOptions = CodexLogoutOptions(),
        globalOptions: CodexGlobalOptions = CodexGlobalOptions()
    ) -> CodexCommand {
        CodexCommand(globalOptions: globalOptions, command: .logout, arguments: options.render())
    }

    public static func mcp(
        _ options: CodexMCPOptions,
        globalOptions: CodexGlobalOptions = CodexGlobalOptions()
    ) -> CodexCommand {
        CodexCommand(globalOptions: globalOptions, command: .mcp, arguments: options.render())
    }

    public static func mcpServer(
        _ options: CodexMCPServerOptions = CodexMCPServerOptions(),
        globalOptions: CodexGlobalOptions = CodexGlobalOptions()
    ) -> CodexCommand {
        CodexCommand(globalOptions: globalOptions, command: .mcpServer, arguments: options.render())
    }

    public static func appServer(
        _ options: CodexAppServerOptions = CodexAppServerOptions(),
        globalOptions: CodexGlobalOptions = CodexGlobalOptions()
    ) -> CodexCommand {
        CodexCommand(globalOptions: globalOptions, command: .appServer, arguments: options.render())
    }

    public static func app(
        _ options: CodexAppOptions = CodexAppOptions(),
        globalOptions: CodexGlobalOptions = CodexGlobalOptions()
    ) -> CodexCommand {
        CodexCommand(globalOptions: globalOptions, command: .app, arguments: options.render())
    }

    public static func completion(
        _ options: CodexCompletionOptions = CodexCompletionOptions(),
        globalOptions: CodexGlobalOptions = CodexGlobalOptions()
    ) -> CodexCommand {
        CodexCommand(globalOptions: globalOptions, command: .completion, arguments: options.render())
    }

    public static func sandbox(
        _ options: CodexSandboxOptions,
        globalOptions: CodexGlobalOptions = CodexGlobalOptions()
    ) -> CodexCommand {
        CodexCommand(globalOptions: globalOptions, command: .sandbox, arguments: options.render())
    }

    public static func debug(
        _ options: CodexDebugOptions,
        globalOptions: CodexGlobalOptions = CodexGlobalOptions()
    ) -> CodexCommand {
        CodexCommand(globalOptions: globalOptions, command: .debug, arguments: options.render())
    }

    public static func apply(
        _ options: CodexApplyOptions,
        globalOptions: CodexGlobalOptions = CodexGlobalOptions()
    ) -> CodexCommand {
        CodexCommand(globalOptions: globalOptions, command: .apply, arguments: options.render())
    }

    public static func resume(
        _ options: CodexResumeOptions = CodexResumeOptions(),
        globalOptions: CodexGlobalOptions = CodexGlobalOptions()
    ) -> CodexCommand {
        CodexCommand(globalOptions: globalOptions, command: .resume, arguments: options.render())
    }

    public static func fork(
        _ options: CodexForkOptions = CodexForkOptions(),
        globalOptions: CodexGlobalOptions = CodexGlobalOptions()
    ) -> CodexCommand {
        CodexCommand(globalOptions: globalOptions, command: .fork, arguments: options.render())
    }

    public static func cloud(
        _ options: CodexCloudOptions,
        globalOptions: CodexGlobalOptions = CodexGlobalOptions()
    ) -> CodexCommand {
        CodexCommand(globalOptions: globalOptions, command: .cloud, arguments: options.render())
    }

    public static func features(
        _ options: CodexFeaturesOptions,
        globalOptions: CodexGlobalOptions = CodexGlobalOptions()
    ) -> CodexCommand {
        CodexCommand(globalOptions: globalOptions, command: .features, arguments: options.render())
    }
}

public enum CodexCLIReference {
    public static func supportedTopLevelCommands() -> Set<String> {
        Set(CodexTopLevelCommand.allCases.map(\.rawValue))
    }

    public static func expectedSubcommandsByTopLevel() -> [String: Set<String>] {
        [
            "exec": ["resume", "review"],
            "login": ["status"],
            "mcp": ["list", "get", "add", "remove", "login", "logout"],
            "app-server": ["generate-ts", "generate-json-schema"],
            "sandbox": ["macos", "linux", "windows"],
            "debug": ["app-server"],
            "cloud": ["exec", "status", "list", "apply", "diff"],
            "features": ["list", "enable", "disable"],
        ]
    }
}
