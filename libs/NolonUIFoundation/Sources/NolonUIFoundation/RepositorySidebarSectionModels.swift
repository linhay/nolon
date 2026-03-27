import Foundation

public struct RepositorySidebarSectionData: Identifiable {
    public let id: String
    public let title: String
    public let rows: [RepositorySidebarRowData]

    public init(
        id: String,
        title: String,
        rows: [RepositorySidebarRowData]
    ) {
        self.id = id
        self.title = title
        self.rows = rows
    }
}
