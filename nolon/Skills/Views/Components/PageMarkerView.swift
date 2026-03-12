import SwiftUI
import AppKit
import Foundation
import ProviderCatalog
import NolonResourceKit

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
        [item(NSLocalizedString("sidebar.tools.accounts", value: "Accounts", comment: "Accounts sidebar item"))]
    }

    static func pluginManagementItems() -> [PageMarkerItem] {
        [item(NSLocalizedString("sidebar.plugins.management", value: "Plugin Management", comment: "Plugin management sidebar item"))]
    }

    static func providerNavigationItems(provider: Provider?) -> [PageMarkerItem] {
        guard let provider else { return [] }
        return [item(provider.displayName)]
    }

    static func providerDetailItems(
        provider: Provider?,
        selectedTab: ProviderContentTabType?
    ) -> [PageMarkerItem] {
        var items = providerNavigationItems(provider: provider)
        if let provider, let selectedTab {
            items.append(item(selectedTab.localizedName(for: provider)))
        }
        return items
    }

    static func resourceCenterItems(selectedTab: ResourceContentTabType?) -> [PageMarkerItem] {
        var items = [item(NSLocalizedString("resource.center.title", value: "Resource Center", comment: "Resource center title"))]
        if let selectedTab {
            items.append(item(selectedTab.localizedName))
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

    private static func item(_ title: String) -> PageMarkerItem {
        PageMarkerItem(title: title)
    }
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
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(text, forType: .string)
            } label: {
                Image(systemName: "scope")
                    .font(.system(size: compact ? 10 : 12, weight: .black))
                .foregroundStyle(DesignSystem.Colors.Text.onAccent)
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
                    color: DesignSystem.Colors.Shadow.floating.opacity(0.32),
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

private struct PageMarkerModifier: ViewModifier {
    let items: [PageMarkerItem]
    let source: PageMarkerSource

    func body(content: Content) -> some View {
        let locatorText = PageMarkerRouteResolver.locatorText(for: items, source: source)
        content.safeAreaInset(edge: .top, spacing: 0) {
            HStack {
                Spacer(minLength: 0)
                DebugLocatorButton(text: locatorText, compact: false)
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)
            .padding(.bottom, 4)
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
}
