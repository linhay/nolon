//
//  nolonApp.swift
//  nolon
//
//  Created by linhey on 1/20/26.
//

import SwiftUI
import Sparkle
import Combine
import OSLog
import ProviderCatalog
import ProviderUsage
import NolonResourceKit

// This view model class publishes when new updates can be checked by the user
final class CheckForUpdatesViewModel: ObservableObject {
    @Published var canCheckForUpdates = false

    init(updater: SPUUpdater) {
        updater.publisher(for: \.canCheckForUpdates)
            .assign(to: &$canCheckForUpdates)
    }
}

// This is the view for the Check for Updates menu item
// Note this intermediate view is necessary for the disabled state on the menu item to work properly before Monterey.
// See https://stackoverflow.com/questions/68553092/menu-not-updating-swiftui-bug for more info
struct CheckForUpdatesView: View {
    @ObservedObject private var checkForUpdatesViewModel: CheckForUpdatesViewModel
    private let updater: SPUUpdater

    init(updater: SPUUpdater) {
        self.updater = updater

        // Create our view model for our CheckForUpdatesView
        self.checkForUpdatesViewModel = CheckForUpdatesViewModel(updater: updater)
    }

    var body: some View {
        Button("Check for Updates…", action: updater.checkForUpdates)
            .disabled(!checkForUpdatesViewModel.canCheckForUpdates)
    }
}

// MARK: - URL Scheme Handler

/// Singleton to share pending URL across app
@MainActor
final class URLSchemeHandler: ObservableObject {
    private static let logger = Logger(subsystem: "com.nolon.app", category: "URLSchemeHandler")
    static let shared = URLSchemeHandler()
    
    @Published var pendingURL: URL?
    
    private init() {}
    
    func handleURL(_ url: URL) {
        guard let httpsURL = Self.normalizeIncomingURL(url) else { return }
        Self.logger.info("Received URL: \(httpsURL.absoluteString, privacy: .public)")
        pendingURL = httpsURL
    }

    static func normalizeIncomingURL(_ url: URL) -> URL? {
        guard url.scheme == "nolon" || url.scheme == "nln" else { return nil }
        guard url.host != nil else { return nil }

        // Reconstruct the original URL:
        // nolon://github.com/owner/repo -> https://github.com/owner/repo
        // nln://github.com/owner/repo -> https://github.com/owner/repo
        var components = URLComponents(url: url, resolvingAgainstBaseURL: true)
        components?.scheme = "https"
        return components?.url
    }
}

/// AppDelegate to handle URL events on macOS
class AppDelegate: NSObject, NSApplicationDelegate {
    private let logger = Logger(subsystem: "com.nolon.app", category: "AppDelegate")

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        logger.info("Received URL count: \(urls.count, privacy: .public)")
        for url in urls {
            Task { @MainActor in
                URLSchemeHandler.shared.handleURL(url)
            }
        }
    }
}

@MainActor
final class CodexAuthBackgroundPoller {
    static let shared = CodexAuthBackgroundPoller()

    private static let logger = Logger(subsystem: "com.nolon.app", category: "CodexAuthBackgroundPoller")
    private let authManager = CodexAuthManager()
    private var pollTask: Task<Void, Never>?
    private let pollIntervalNanoseconds: UInt64 = 60 * 1_000_000_000
    private let enabledDefaultsKey = "codex.auth.background_poll.enabled"

    private init() {}

    func start() {
        guard pollTask == nil else { return }
        pollTask = Task { [weak self] in
            guard let self else { return }
            await self.runLoop()
        }
        Self.logger.info("Codex auth background poller started.")
    }

    func stop() {
        pollTask?.cancel()
        pollTask = nil
        Self.logger.info("Codex auth background poller stopped.")
    }

    private var isEnabled: Bool {
        UserDefaults.standard.object(forKey: enabledDefaultsKey) as? Bool ?? true
    }

    private func runLoop() async {
        while !Task.isCancelled {
            if isEnabled {
                await pollOnce()
            }
            do {
                try await Task.sleep(nanoseconds: pollIntervalNanoseconds)
            } catch {
                break
            }
        }
    }

    private func pollOnce() async {
        let providers = ProviderSettings.shared.providers.filter { provider in
            provider.templateId == ProviderTemplate.codex.rawValue
                || provider.templateId == ProviderTemplate.codexXcode.rawValue
        }
        guard !providers.isEmpty else { return }

        for provider in providers {
            do {
                _ = try await authManager.preflightManagedAuthIfNeeded(
                    for: provider,
                    forceBackup: false,
                    reason: "background_poll"
                )
            } catch {
                Self.logger.error(
                    "Codex auth preflight failed in background poll. provider=\(provider.id, privacy: .public) error=\(String(describing: error), privacy: .public)"
                )
            }
        }
    }
}

@main
struct nolonApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    static var updaterController: SPUStandardUpdaterController?

    init() {
        // Load provider template configurations from JSON
        ProviderTemplateLoader.shared.load()
        
        // Apply app settings (appearance, etc.)
        AppSettingsStore.shared.applyAllSettings()
        
        // Skip Sparkle in Previews to avoid launch timeout
        if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] != "1" {
            let controller = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)
            Self.updaterController = controller
        }
    }

    var body: some Scene {
        Window("nolon", id: "main") {
            ContentView()
                .onOpenURL { url in
                    URLSchemeHandler.shared.handleURL(url)
                }
                .task {
                    CodexAuthBackgroundPoller.shared.start()
                }
        }
        .handlesExternalEvents(matching: [])  // Prevent new windows from URL events
        
        .commands {
            CommandGroup(replacing: .appSettings) {
                Button(NSLocalizedString("settings.app", value: "Settings...", comment: "Menu item")) {
                    AppCommandState.shared.showingSettings = true
                }
                .keyboardShortcut(",", modifiers: .command)
            }
            
            CommandGroup(after: .appInfo) {
                if let controller = Self.updaterController {
                    CheckForUpdatesView(updater: controller.updater)
                }
            }
        }
    }
}
