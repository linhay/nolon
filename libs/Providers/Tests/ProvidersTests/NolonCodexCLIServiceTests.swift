import Foundation
import Testing
@testable import NolonCoreCLIKit
@testable import ProviderUsage
@testable import CodexProvider

@Suite("Nolon Codex CLI Service")
struct NolonCodexCLIServiceTests {
    @Test("auth list canonicalizes codexxcode provider id")
    func authListCanonicalProviderID() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("nolon-codex-cli-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let service = NolonLiveCodexCLIService(
            authManager: CodexAuthManager(rootURL: root),
            binaryManager: CodexBinaryManager(homeURL: root),
            loginRunner: .init(),
            environment: [:]
        )

        let payload = try await service.authList(providerID: "codexxcode")
        #expect(payload.providerID == "codex-xcode")
    }

    @Test("status probe rejects unsupported provider in service")
    func statusProbeRejectsUnsupportedProvider() async {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("nolon-codex-cli-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let service = NolonLiveCodexCLIService(
            authManager: CodexAuthManager(rootURL: root),
            binaryManager: CodexBinaryManager(homeURL: root),
            loginRunner: .init(),
            environment: [:]
        )

        do {
            _ = try await service.statusProbe(providerID: "claude")
            Issue.record("Expected invalidArguments error")
        } catch let error as NolonCoreCLIError {
            guard case .invalidArguments = error else {
                Issue.record("Unexpected error: \(error)")
                return
            }
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
    }

    @Test("auth delete returns domain error when account is missing")
    func authDeleteMissingAccount() async {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("nolon-codex-cli-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let service = NolonLiveCodexCLIService(
            authManager: CodexAuthManager(rootURL: root),
            binaryManager: CodexBinaryManager(homeURL: root),
            loginRunner: .init(),
            environment: [:]
        )

        do {
            _ = try await service.authDelete(
                providerID: "codex",
                accountID: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
            )
            Issue.record("Expected codex_auth_account_not_found error")
        } catch let error as NolonCoreCLIError {
            guard case let .domainFailed(code, _) = error else {
                Issue.record("Unexpected error: \(error)")
                return
            }
            #expect(code == "codex_auth_account_not_found")
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
    }
}
