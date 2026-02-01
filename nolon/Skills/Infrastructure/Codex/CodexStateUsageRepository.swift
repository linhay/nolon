import Foundation
import OSLog
import GRDB

struct CodexProjectUsage: Identifiable, Hashable, Sendable {
    var cwd: String
    var threads: Int
    var tokens: Int64

    var id: String { cwd }
}

struct CodexUsageSummary: Hashable, Sendable {
    var threads: Int
    var tokens: Int64
    var projects: [CodexProjectUsage]
}

enum CodexUsageTimeRange: String, CaseIterable, Identifiable, Sendable {
    case today
    case last7Days
    case last30Days
    case allTime

    var id: String { rawValue }

    var localizedTitle: String {
        switch self {
        case .today:
            return NSLocalizedString("codex.usage.range.today", value: "Today", comment: "Usage range")
        case .last7Days:
            return NSLocalizedString("codex.usage.range.7d", value: "Last 7 days", comment: "Usage range")
        case .last30Days:
            return NSLocalizedString("codex.usage.range.30d", value: "Last 30 days", comment: "Usage range")
        case .allTime:
            return NSLocalizedString("codex.usage.range.all", value: "All time", comment: "Usage range")
        }
    }

    func sinceDate(now: Date = .init()) -> Date? {
        let calendar = Calendar.current
        switch self {
        case .today:
            return calendar.startOfDay(for: now)
        case .last7Days:
            return calendar.date(byAdding: .day, value: -7, to: now)
        case .last30Days:
            return calendar.date(byAdding: .day, value: -30, to: now)
        case .allTime:
            return nil
        }
    }
}

final class CodexStateUsageRepository {
    private static let logger = Logger(subsystem: "com.nolon", category: "CodexStateUsageRepository")

    func fetchUsage(dbURL: URL, range: CodexUsageTimeRange) throws -> CodexUsageSummary {
        var configuration = Configuration()
        configuration.readonly = true

        let queue: DatabaseQueue
        do {
            queue = try DatabaseQueue(path: dbURL.path, configuration: configuration)
        } catch {
            Self.logger.error("Failed to open Codex state database: \(error.localizedDescription)")
            throw NSError(domain: "CodexStateUsageRepository", code: 1, userInfo: [
                NSLocalizedDescriptionKey: NSLocalizedString("codex.usage.error.open_db", value: "Failed to open Codex state database.", comment: "Error message"),
                NSUnderlyingErrorKey: error,
            ])
        }

        let since = range.sinceDate().map { Int64($0.timeIntervalSince1970) }

        do {
            return try queue.read { db in
                let totals = try queryTotals(db: db, since: since)
                let projects = try queryProjects(db: db, since: since)
                return CodexUsageSummary(threads: totals.threads, tokens: totals.tokens, projects: projects)
            }
        } catch {
            Self.logger.error("Failed to query Codex state database: \(error.localizedDescription)")
            throw error
        }
    }

    private func queryTotals(db: Database, since: Int64?) throws -> (threads: Int, tokens: Int64) {
        let sql: String
        let arguments: StatementArguments
        if let since {
            sql = """
            SELECT COUNT(*) AS threads, COALESCE(SUM(tokens_used), 0) AS tokens
            FROM threads
            WHERE updated_at >= ?
            """
            arguments = [since]
        } else {
            sql = """
            SELECT COUNT(*) AS threads, COALESCE(SUM(tokens_used), 0) AS tokens
            FROM threads
            """
            arguments = []
        }

        let row = try Row.fetchOne(db, sql: sql, arguments: arguments)
        let threads: Int = row?["threads"] ?? 0
        let tokens: Int64 = row?["tokens"] ?? 0
        return (threads, tokens)
    }

    private func queryProjects(db: Database, since: Int64?) throws -> [CodexProjectUsage] {
        let sql: String
        let arguments: StatementArguments
        if let since {
            sql = """
            SELECT cwd, COUNT(*) AS threads, COALESCE(SUM(tokens_used), 0) AS tokens
            FROM threads
            WHERE updated_at >= ?
            GROUP BY cwd
            ORDER BY tokens DESC
            LIMIT 50
            """
            arguments = [since]
        } else {
            sql = """
            SELECT cwd, COUNT(*) AS threads, COALESCE(SUM(tokens_used), 0) AS tokens
            FROM threads
            GROUP BY cwd
            ORDER BY tokens DESC
            LIMIT 50
            """
            arguments = []
        }

        let rows = try Row.fetchAll(db, sql: sql, arguments: arguments)
        return rows.compactMap { row in
            guard let cwd: String = row["cwd"] else { return nil }
            let threads: Int = row["threads"]
            let tokens: Int64 = row["tokens"]
            return CodexProjectUsage(cwd: cwd, threads: threads, tokens: tokens)
        }
    }
}
