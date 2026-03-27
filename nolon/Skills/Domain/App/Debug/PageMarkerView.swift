import SwiftUI
import AppKit
import Foundation
import Observation
import ProviderCatalog
import NolonResourceKit
import NolonUI

struct PageMarkerItem: Identifiable, Equatable {
    let title: String

    var id: String { title }
}

struct PageMarkerSource: Equatable {
    let file: String
    let line: Int
    let function: String
}

protocol DebugPageLocatable: View {
    var debugPageMarkerItems: [PageMarkerItem] { get }
}

protocol DebugCardLocatable: View {
    var debugCardMarkerItems: [PageMarkerItem] { get }
}

enum PageMarkerRouteResolver {
    static var isEnabledInCurrentBuild: Bool {
        #if DEBUG
        true
        #else
        false
        #endif
    }

    static func accountsItems() -> [PageMarkerItem] {
        [PageMarkerItem(title: NSLocalizedString("sidebar.tools.accounts", value: "Accounts", comment: "Accounts sidebar item"))]
    }

    static func pluginManagementItems() -> [PageMarkerItem] {
        [PageMarkerItem(title: NSLocalizedString("sidebar.plugins.management", value: "Plugin Management", comment: "Plugin management sidebar item"))]
    }

    static func providerNavigationItems(provider: Provider?) -> [PageMarkerItem] {
        guard let provider else { return [] }
        return [PageMarkerItem(title: provider.displayName)]
    }

    static func providerDetailItems(
        provider: Provider?,
        selectedTab: ProviderContentTabType?
    ) -> [PageMarkerItem] {
        var items = providerNavigationItems(provider: provider)
        if let provider, let selectedTab {
            items.append(PageMarkerItem(title: selectedTab.localizedName(for: provider)))
        }
        return items
    }

    static func resourceCenterItems(selectedTab: ResourceCenterTabID?) -> [PageMarkerItem] {
        var items = [PageMarkerItem(title: NSLocalizedString("resource.center.title", value: "Resource Center", comment: "Resource center title"))]
        if let selectedTab {
            items.append(PageMarkerItem(title: selectedTab.localizedName))
        }
        return items
    }

    static func source(
        fileID: String = #fileID,
        line: Int = #line,
        function: String = #function
    ) -> PageMarkerSource {
        PageMarkerSource(
            file: (fileID as NSString).lastPathComponent,
            line: line,
            function: function.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }

    static func metadataText(source: PageMarkerSource) -> String {
        "#\(source.file) #\(source.line) #\(source.function)"
    }

    static func locatorText(
        for items: [PageMarkerItem],
        source: PageMarkerSource
    ) -> String {
        let parts = items.map(\.title) + [metadataText(source: source)]
        return parts.joined(separator: " / ")
    }
}

@MainActor
@Observable
final class DebugMarkerToastCenter {
    static let shared = DebugMarkerToastCenter()

    private(set) var isVisible = false
    private(set) var message = ""

    private var hideTask: Task<Void, Never>?

    func showCopiedPageMarkerToast(_ text: String) {
        hideTask?.cancel()
        message = text.isEmpty
            ? NSLocalizedString(
                "debug.page_marker.copied",
                value: "Copied Page Marker",
                comment: "Toast after copying debug page marker"
            )
            : text
        isVisible = true

        hideTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(1400))
            self?.isVisible = false
        }
    }
}

@MainActor
private func copyPageMarkerToPasteboard(_ text: String) {
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(text, forType: .string)
    DebugMarkerToastCenter.shared.showCopiedPageMarkerToast(text)
}

private struct DebugLocatorButton: View {
    let text: String
    let compact: Bool

    @State private var commandState = AppCommandState.shared

    var body: some View {
        if PageMarkerRouteResolver.isEnabledInCurrentBuild,
           commandState.isDebugPageMarkersEnabled,
           !text.isEmpty {
            Button {
                copyPageMarkerToPasteboard(text)
            } label: {
                Image(systemName: "scope")
                    .font(.system(size: compact ? 10 : 12, weight: .black))
                .foregroundStyle(NolonUI.DesignSystem.Colors.Text.onAccent)
                .frame(width: compact ? 20 : 24, height: compact ? 20 : 24)
                .background(
                    Circle()
                        .fill(Color(light: 0xD9480F, dark: 0xFF7A1A))
                )
                .overlay {
                    Circle()
                        .stroke(Color.white.opacity(0.22), lineWidth: 1)
                }
                .shadow(
                    color: NolonUI.DesignSystem.Colors.Shadow.floating.opacity(0.32),
                    radius: compact ? 4 : 8,
                    y: compact ? 2 : 4
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Copy Page Marker")
            .help(text)
        }
    }
}

struct DebugPageMarkerContextMenuItem: View {
    let text: String
    let withDivider: Bool

    init(text: String, withDivider: Bool = true) {
        self.text = text
        self.withDivider = withDivider
    }

    var body: some View {
        if PageMarkerRouteResolver.isEnabledInCurrentBuild,
           AppCommandState.shared.isDebugPageMarkersEnabled,
           !text.isEmpty {
            if withDivider {
                Divider()
            }

            Button {
                copyPageMarkerToPasteboard(text)
            } label: {
                Label(
                    NSLocalizedString("debug.page_marker.copy", value: "Copy Page Marker", comment: "Copy page marker"),
                    systemImage: "scope"
                )
            }
        }
    }
}

private struct PageMarkerModifier: ViewModifier {
    let items: [PageMarkerItem]
    let source: PageMarkerSource

    func body(content: Content) -> some View {
        let locatorText = PageMarkerRouteResolver.locatorText(for: items, source: source)
        content.overlay(alignment: .topTrailing) {
            DebugLocatorButton(text: locatorText, compact: false)
                .padding(.top, 10)
                .padding(.trailing, 12)
        }
    }
}

private struct DebugLocatorOverlayModifier: ViewModifier {
    let text: String

    func body(content: Content) -> some View {
        content.overlay(alignment: .topTrailing) {
            DebugLocatorButton(text: text, compact: true)
                .padding(10)
        }
    }
}

extension View {
    func debugPageLocator(
        _ items: [PageMarkerItem],
        fileID: String = #fileID,
        line: Int = #line,
        function: String = #function
    ) -> some View {
        pageMarker(
            items,
            fileID: fileID,
            line: line,
            function: function
        )
    }

    func debugCardLocator(
        _ items: [PageMarkerItem],
        fileID: String = #fileID,
        line: Int = #line,
        function: String = #function
    ) -> some View {
        debugLocatorOverlay(
            items,
            fileID: fileID,
            line: line,
            function: function
        )
    }

    func pageMarker(
        _ items: [PageMarkerItem],
        fileID: String = #fileID,
        line: Int = #line,
        function: String = #function
    ) -> some View {
        modifier(
            PageMarkerModifier(
                items: items,
                source: PageMarkerRouteResolver.source(
                    fileID: fileID,
                    line: line,
                    function: function
                )
            )
        )
    }

    func debugLocatorOverlay(
        _ items: [PageMarkerItem],
        fileID: String = #fileID,
        line: Int = #line,
        function: String = #function
    ) -> some View {
        modifier(
            DebugLocatorOverlayModifier(
                text: PageMarkerRouteResolver.locatorText(
                    for: items,
                    source: PageMarkerRouteResolver.source(
                        fileID: fileID,
                        line: line,
                        function: function
                    )
                )
            )
        )
    }

    @ViewBuilder
    func debugPageMarkerMenuItem(
        _ items: [PageMarkerItem],
        withDivider: Bool = true,
        fileID: String = #fileID,
        line: Int = #line,
        function: String = #function
    ) -> some View {
        DebugPageMarkerContextMenuItem(
            text: PageMarkerRouteResolver.locatorText(
                for: items,
                source: PageMarkerRouteResolver.source(
                    fileID: fileID,
                    line: line,
                    function: function
                )
            ),
            withDivider: withDivider
        )
    }

    func debugPageMarkerContextMenu(
        _ items: [PageMarkerItem],
        withDivider: Bool = true,
        fileID: String = #fileID,
        line: Int = #line,
        function: String = #function,
        @ViewBuilder _ content: () -> some View
    ) -> some View {
        contextMenu {
            content()
            debugPageMarkerMenuItem(
                items,
                withDivider: withDivider,
                fileID: fileID,
                line: line,
                function: function
            )
        }
    }
}

extension DebugPageLocatable {
    func debugPageLocatorText(
        fileID: String = #fileID,
        line: Int = #line,
        function: String = #function
    ) -> String {
        PageMarkerRouteResolver.locatorText(
            for: debugPageMarkerItems,
            source: PageMarkerRouteResolver.source(
                fileID: fileID,
                line: line,
                function: function
            )
        )
    }

    func debugPageLocator(
        fileID: String = #fileID,
        line: Int = #line,
        function: String = #function
    ) -> some View {
        debugPageLocator(
            debugPageMarkerItems,
            fileID: fileID,
            line: line,
            function: function
        )
    }

    func debugPageMarkerContextMenu(
        withDivider: Bool = true,
        fileID: String = #fileID,
        line: Int = #line,
        function: String = #function,
        @ViewBuilder _ content: () -> some View
    ) -> some View {
        debugPageMarkerContextMenu(
            debugPageMarkerItems,
            withDivider: withDivider,
            fileID: fileID,
            line: line,
            function: function,
            content
        )
    }
}

extension DebugCardLocatable {
    func debugCardLocatorText(
        fileID: String = #fileID,
        line: Int = #line,
        function: String = #function
    ) -> String {
        PageMarkerRouteResolver.locatorText(
            for: debugCardMarkerItems,
            source: PageMarkerRouteResolver.source(
                fileID: fileID,
                line: line,
                function: function
            )
        )
    }

    func debugCardLocator(
        fileID: String = #fileID,
        line: Int = #line,
        function: String = #function
    ) -> some View {
        debugCardLocator(
            debugCardMarkerItems,
            fileID: fileID,
            line: line,
            function: function
        )
    }

    func debugCardMarkerContextMenu(
        withDivider: Bool = true,
        fileID: String = #fileID,
        line: Int = #line,
        function: String = #function,
        @ViewBuilder _ content: () -> some View
    ) -> some View {
        debugPageMarkerContextMenu(
            debugCardMarkerItems,
            withDivider: withDivider,
            fileID: fileID,
            line: line,
            function: function,
            content
        )
    }
}
