//
//  nolonApp.swift
//  nolon
//
//  Created by linhey on 1/20/26.
//

import SwiftUI
import Sparkle
import Combine
import Observation
import OSLog
import ProviderCatalog
import ProviderUsage
import NolonResourceKit

// This view model class publishes when new updates can be checked by the user
@Observable
final class CheckForUpdatesViewModel {
    var canCheckForUpdates = false
    @ObservationIgnored private var updatesCancellable: AnyCancellable?

    init(updater: SPUUpdater) {
        canCheckForUpdates = updater.canCheckForUpdates
        updatesCancellable = updater.publisher(for: \.canCheckForUpdates)
            .receive(on: RunLoop.main)
            .sink { [weak self] value in
                self?.canCheckForUpdates = value
            }
    }
}

// This is the view for the Check for Updates menu item
// Note this intermediate view is necessary for the disabled state on the menu item to work properly before Monterey.
// See https://stackoverflow.com/questions/68553092/menu-not-updating-swiftui-bug for more info
struct CheckForUpdatesView: View {
    @State private var checkForUpdatesViewModel: CheckForUpdatesViewModel
    private let updater: SPUUpdater

    init(updater: SPUUpdater) {
        self.updater = updater

        // Create our view model for our CheckForUpdatesView
        self._checkForUpdatesViewModel = State(initialValue: CheckForUpdatesViewModel(updater: updater))
    }

    var body: some View {
        Button("Check for Updates…", action: updater.checkForUpdates)
            .disabled(!checkForUpdatesViewModel.canCheckForUpdates)
    }
}

// MARK: - URL Scheme Handler

/// Singleton to share pending URL across app
@MainActor
@Observable
final class URLSchemeHandler {
    private static let logger = Logger(subsystem: "com.nolon.app", category: "URLSchemeHandler")
    static let shared = URLSchemeHandler()
    
    var pendingURL: URL?
    
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
        guard !UITestSupport.isRunningUnitTests else { return }
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
    private let isRunningSwiftUIPreviews: Bool

    init() {
        self.isRunningSwiftUIPreviews = RuntimeEnvironment.isSwiftUIPreview()

        // Load provider template configurations from JSON
        ProviderTemplateLoader.shared.load()

        // Skip startup side effects in SwiftUI previews to keep launch fast/stable.
        if !isRunningSwiftUIPreviews {
            // Apply app settings (appearance, etc.)
            AppSettingsStore.shared.applyAllSettings()

            let controller = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)
            Self.updaterController = controller
        }
    }

    var body: some Scene {
        Window("nolon", id: "main") {
            rootContentView
        }
        .handlesExternalEvents(matching: [])  // Prevent new windows from URL events
        .commands {
            appCommands
        }

        Window(
            NSLocalizedString("detail.skill.window.title", value: "Skill Detail", comment: "Skill detail window title"),
            id: SkillDetailWindowCoordinator.windowID
        ) {
            SkillDetailWindowRootView()
        }
        .defaultSize(width: 1100, height: 720)

        MenuBarExtra("nolon", systemImage: "arrow.triangle.2.circlepath.circle") {
            CodexQuickSwitchMenuBarView()
        }
        .menuBarExtraStyle(.window)
    }

    @ViewBuilder
    private var rootContentView: some View {
        if isRunningSwiftUIPreviews {
            PreviewBootstrapView()
        } else {
            ContentView()
                .onOpenURL { url in
                    URLSchemeHandler.shared.handleURL(url)
                }
                .task {
                    if !UITestSupport.isRunningUnitTests {
                        CodexAuthBackgroundPoller.shared.start()
                    }
                }
        }
    }

    @CommandsBuilder
    private var appCommands: some Commands {
        SidebarCommands()

        CommandGroup(replacing: .appSettings) {
            Button(NSLocalizedString("settings.app", value: "Settings...", comment: "Menu item")) {
                AppCommandState.shared.showingSettings = true
            }
            .keyboardShortcut(",", modifiers: .command)
        }

        #if DEBUG
        CommandMenu(NSLocalizedString("debug.menu.title", value: "Debug", comment: "Debug menu")) {
            Toggle(
                NSLocalizedString("debug.menu.page_markers", value: "Show Page Markers", comment: "Toggle debug page markers"),
                isOn: Binding(
                    get: { AppCommandState.shared.isDebugPageMarkersEnabled },
                    set: { AppCommandState.shared.isDebugPageMarkersEnabled = $0 }
                )
            )
        }
        #endif
        
        CommandGroup(after: .appInfo) {
            if let controller = Self.updaterController {
                CheckForUpdatesView(updater: controller.updater)
            }
        }
    }
}

private struct PreviewBootstrapView: View {
    var body: some View {
        Color.clear
            .frame(width: 1, height: 1)
    }
}
