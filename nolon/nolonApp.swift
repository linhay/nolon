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
import SwiftGit

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

    func application(_ application: NSApplication, open urls: [URL]) {
        logger.info("Received URL count: \(urls.count, privacy: .public)")
        for url in urls {
            Task { @MainActor in
                URLSchemeHandler.shared.handleURL(url)
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
