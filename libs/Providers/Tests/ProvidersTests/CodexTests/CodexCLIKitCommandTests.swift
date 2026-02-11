import Testing
@testable import CodexCLIKit

@Suite("CodexCLIKit Command")
struct CodexCLIKitCommandTests {
    @Test("Render global options and command args")
    func renderCommand() {
        let command = CodexCommand(
            globalOptions: CodexGlobalOptions(
                configOverrides: ["model=\"gpt-5\""],
                enabledFeatures: ["featureA"],
                disabledFeatures: ["featureB"]
            ),
            command: .exec,
            arguments: ["--json", "hello"]
        )

        #expect(command.render() == [
            "--config", "model=\"gpt-5\"",
            "--enable", "featureA",
            "--disable", "featureB",
            "exec", "--json", "hello",
        ])
    }

    @Test("Raw command keeps argument order")
    func rawCommand() {
        let command = CodexCommand.raw(CodexRawCommand(args: ["app-server", "--help"]))
        #expect(command.render() == ["app-server", "--help"])
    }

    @Test("Render extended global CLI options")
    func renderExtendedGlobalOptions() {
        let command = CodexCommand(
            globalOptions: CodexGlobalOptions(
                images: ["/tmp/a.png", "/tmp/b.png"],
                model: "gpt-5-codex",
                useOSS: true,
                localProvider: .ollama,
                profile: "dev",
                sandbox: .workspaceWrite,
                askForApproval: .onRequest,
                fullAuto: true,
                bypassApprovalsAndSandbox: true,
                workingDirectory: "/repo",
                search: true,
                additionalWritableDirectories: ["/repo/shared"],
                noAltScreen: true,
                rawOptions: ["--extra-flag"]
            ),
            command: .exec,
            arguments: ["--json", "hello"]
        )

        #expect(command.render() == [
            "--image", "/tmp/a.png",
            "--image", "/tmp/b.png",
            "--model", "gpt-5-codex",
            "--oss",
            "--local-provider", "ollama",
            "--profile", "dev",
            "--sandbox", "workspace-write",
            "--ask-for-approval", "on-request",
            "--full-auto",
            "--dangerously-bypass-approvals-and-sandbox",
            "--cd", "/repo",
            "--search",
            "--add-dir", "/repo/shared",
            "--no-alt-screen",
            "--extra-flag",
            "exec", "--json", "hello",
        ])
    }

    @Test("Render exec builder options")
    func renderExecBuilder() {
        let command = CodexCommand.exec(
            CodexExecOptions(
                skipGitRepoCheck: true,
                outputSchemaFile: "/tmp/schema.json",
                color: .auto,
                json: true,
                outputLastMessageFile: "/tmp/last.txt",
                subcommand: .resume(last: true, sessionID: "sess_123", prompt: nil)
            ),
            globalOptions: CodexGlobalOptions(model: "gpt-5-codex")
        )

        #expect(command.render() == [
            "--model", "gpt-5-codex",
            "exec",
            "--skip-git-repo-check",
            "--output-schema", "/tmp/schema.json",
            "--color", "auto",
            "--json",
            "--output-last-message", "/tmp/last.txt",
            "resume", "--last", "sess_123",
        ])
    }

    @Test("Render review/app-server/mcp builders")
    func renderOtherBuilders() {
        let review = CodexCommand.review(
            CodexReviewOptions(
                prompt: "security focus",
                uncommitted: true,
                baseBranch: "main",
                title: "Review auth changes"
            )
        )
        #expect(review.render() == [
            "review",
            "--uncommitted",
            "--base", "main",
            "--title", "Review auth changes",
            "security focus",
        ])

        let appServer = CodexCommand.appServer(
            CodexAppServerOptions(
                analyticsDefaultEnabled: true,
                subcommand: .generateJSONSchema
            )
        )
        #expect(appServer.render() == [
            "app-server",
            "--analytics-default-enabled",
            "generate-json-schema",
        ])

        let mcp = CodexCommand.mcp(
            CodexMCPOptions(action: .add(name: "docs", command: ["npx", "@example/mcp"], env: ["DEBUG=1"]))
        )
        #expect(mcp.render() == [
            "mcp",
            "add",
            "docs",
            "--env", "DEBUG=1",
            "--",
            "npx", "@example/mcp",
        ])
    }

    @Test("Render complete top-level command builders")
    func renderCompleteTopLevelBuilders() {
        let login = CodexCommand.login(
            CodexLoginOptions(withAPIKey: true, deviceAuth: true, subcommand: .status)
        )
        #expect(login.render() == [
            "login",
            "--with-api-key",
            "--device-auth",
            "status",
        ])

        let logout = CodexCommand.logout()
        #expect(logout.render() == ["logout"])

        let mcpServer = CodexCommand.mcpServer()
        #expect(mcpServer.render() == ["mcp-server"])

        let app = CodexCommand.app(CodexAppOptions(path: "/repo", downloadURL: "https://example.com/Codex.dmg"))
        #expect(app.render() == [
            "app",
            "--download-url", "https://example.com/Codex.dmg",
            "/repo",
        ])

        let completion = CodexCommand.completion(CodexCompletionOptions(shell: .zsh))
        #expect(completion.render() == ["completion", "zsh"])

        let sandbox = CodexCommand.sandbox(
            CodexSandboxOptions(target: .macos, fullAuto: true, logDenials: true, command: ["echo", "ok"])
        )
        #expect(sandbox.render() == [
            "sandbox",
            "macos",
            "--full-auto",
            "--log-denials",
            "echo", "ok",
        ])

        let debug = CodexCommand.debug(
            CodexDebugOptions(action: .appServer(.sendMessageV2(arguments: ["--session", "abc"])))
        )
        #expect(debug.render() == [
            "debug",
            "app-server",
            "send-message-v2",
            "--session", "abc",
        ])

        let apply = CodexCommand.apply(CodexApplyOptions(taskID: "task_123"))
        #expect(apply.render() == ["apply", "task_123"])

        let resume = CodexCommand.resume(CodexResumeOptions(sessionID: "sess_1", prompt: "continue", last: true, all: true))
        #expect(resume.render() == [
            "resume",
            "--last",
            "--all",
            "sess_1",
            "continue",
        ])

        let fork = CodexCommand.fork(CodexForkOptions(sessionID: "sess_2", prompt: "fork"))
        #expect(fork.render() == [
            "fork",
            "sess_2",
            "fork",
        ])

        let cloud = CodexCommand.cloud(
            CodexCloudOptions(action: .exec(CodexCloudExecOptions(environmentID: "env_1", query: "fix", attempts: 2, branch: "main")))
        )
        #expect(cloud.render() == [
            "cloud",
            "exec",
            "--env", "env_1",
            "--attempts", "2",
            "--branch", "main",
            "fix",
        ])

        let features = CodexCommand.features(CodexFeaturesOptions(action: .enable(feature: "unified_exec")))
        #expect(features.render() == [
            "features",
            "enable",
            "unified_exec",
        ])
    }
}
