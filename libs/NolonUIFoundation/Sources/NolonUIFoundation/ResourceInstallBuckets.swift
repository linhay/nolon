public struct ResourceInstallBuckets<Item> {
    public let installed: [Item]
    public let installing: [Item]
    public let available: [Item]

    public init(
        items: [Item],
        isInstalled: (Item) -> Bool,
        isInstalling: (Item) -> Bool
    ) {
        self.installed = items.filter(isInstalled)
        self.installing = items.filter { item in
            isInstalling(item) && !isInstalled(item)
        }
        self.available = items.filter { item in
            !isInstalled(item) && !isInstalling(item)
        }
    }
}
