import Foundation
import CodexBarProviderCatalog
import STFilePath

enum CostUsageCacheIO {
    private static func defaultCacheRoot() -> STFolder {
        if let cache = try? STFolder(sanbox: .cache) {
            return cache.folder("CodexBar")
        }
        return STFolder(NSHomeDirectory())
            .folder("Library")
            .folder("Caches")
            .folder("CodexBar")
    }

    static func cacheFile(provider: UsageProvider, cacheRoot: STFolder? = nil) -> STFile {
        let root = cacheRoot ?? self.defaultCacheRoot()
        return root
            .folder("cost-usage")
            .file("\(provider.rawValue)-v1.json")
    }

    static func cacheFileURL(provider: UsageProvider, cacheRoot: URL? = nil) -> URL {
        cacheFile(provider: provider, cacheRoot: cacheRoot.map(STFolder.init)).url
    }

    static func load(provider: UsageProvider, cacheRoot: STFolder? = nil) -> CostUsageCache {
        let file = self.cacheFile(provider: provider, cacheRoot: cacheRoot)
        if let decoded = self.loadCache(file: file) { return decoded }
        return CostUsageCache()
    }

    static func load(provider: UsageProvider, cacheRoot: URL? = nil) -> CostUsageCache {
        load(provider: provider, cacheRoot: cacheRoot.map(STFolder.init))
    }

    private static func loadCache(file: STFile) -> CostUsageCache? {
        guard let data = try? file.data() else { return nil }
        guard let decoded = try? JSONDecoder().decode(CostUsageCache.self, from: data)
        else { return nil }
        guard decoded.version == 1 else { return nil }
        return decoded
    }

    static func save(provider: UsageProvider, cache: CostUsageCache, cacheRoot: STFolder? = nil) {
        let file = self.cacheFile(provider: provider, cacheRoot: cacheRoot)
        let dir = file.parentFolder()?.createIfNotExists() ?? STFolder(file.url.deletingLastPathComponent())
        let tmp = dir.file(".tmp-\(UUID().uuidString).json")
        let data = (try? JSONEncoder().encode(cache)) ?? Data()
        do {
            try tmp.overlay(with: data)
            _ = try tmp.move(to: file, isOverlay: true)
        } catch {
            try? tmp.delete()
        }
    }

    static func save(provider: UsageProvider, cache: CostUsageCache, cacheRoot: URL? = nil) {
        save(provider: provider, cache: cache, cacheRoot: cacheRoot.map(STFolder.init))
    }
}

struct CostUsageCache: Codable, Sendable {
    var version: Int = 1
    var lastScanUnixMs: Int64 = 0

    // filePath -> file usage
    var files: [String: CostUsageFileUsage] = [:]

    // dayKey -> model -> packed usage
    var days: [String: [String: [Int]]] = [:]

}

struct CostUsageFileUsage: Codable, Sendable {
    var mtimeUnixMs: Int64
    var size: Int64
    var days: [String: [String: [Int]]]
    var parsedBytes: Int64?
    var lastModel: String?
    var lastTotals: CostUsageCodexTotals?
    var sessionId: String?
}

struct CostUsageCodexTotals: Codable, Sendable {
    var input: Int
    var cached: Int
    var output: Int
}
