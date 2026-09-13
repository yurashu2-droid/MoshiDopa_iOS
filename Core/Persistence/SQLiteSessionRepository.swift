import Foundation
import SQLite3

struct SQLiteStoreError: LocalizedError {
    let operation: String
    let detail: String
    var errorDescription: String? { "保存エラー (\(operation)): \(detail)" }
}

/// Distinct from Expo's moshidopa.db. Never opens or migrates legacy files in this PoC.
final class SQLiteSessionRepository: SessionRepository {
    private var database: OpaquePointer?
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    static func applicationStoreURL() throws -> URL {
        let support = try FileManager.default.url(for: .applicationSupportDirectory,
            in: .userDomainMask, appropriateFor: nil, create: true)
        var directory = support.appendingPathComponent("MoshiDopaNative", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try directory.setResourceValues(values)
        return directory.appendingPathComponent("pip-poc-v1.sqlite")
    }

    init(url: URL) throws {
        guard sqlite3_open_v2(url.path, &database, SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX, nil) == SQLITE_OK else {
            let failure = error("open")
            sqlite3_close(database)
            database = nil
            throw failure
        }
        do {
            try execute("PRAGMA journal_mode=WAL")
            try execute("PRAGMA busy_timeout=3000")
            try execute("CREATE TABLE IF NOT EXISTS native_sessions (id TEXT PRIMARY KEY NOT NULL, payload TEXT NOT NULL)")
            try execute("CREATE UNIQUE INDEX IF NOT EXISTS one_running_session ON native_sessions(json_extract(payload, '$.state')) WHERE json_extract(payload, '$.state') = 'running'")
            try FileManager.default.setAttributes([.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication], ofItemAtPath: url.path)
        } catch {
            sqlite3_close(database)
            database = nil
            throw error
        }
    }

    deinit { sqlite3_close(database) }

    func records() throws -> [SessionRecord] {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, "SELECT payload FROM native_sessions", -1, &statement, nil) == SQLITE_OK else { throw error("read prepare") }
        defer { sqlite3_finalize(statement) }
        var result: [SessionRecord] = []
        while true {
            let status = sqlite3_step(statement)
            if status == SQLITE_DONE { break }
            guard status == SQLITE_ROW, let bytes = sqlite3_column_text(statement, 0) else { throw error("read") }
            let payload = String(cString: bytes)
            result.append(try decoder.decode(SessionRecord.self, from: Data(payload.utf8)))
        }
        return result.sorted { $0.startedAt > $1.startedAt }
    }

    func save(_ record: SessionRecord) throws {
        let payload = String(decoding: try encoder.encode(record), as: UTF8.self)
        try execute("BEGIN IMMEDIATE")
        do {
            var statement: OpaquePointer?
            guard sqlite3_prepare_v2(database, "INSERT INTO native_sessions(id,payload) VALUES (?,?) ON CONFLICT(id) DO UPDATE SET payload=excluded.payload", -1, &statement, nil) == SQLITE_OK else { throw error("write prepare") }
            defer { sqlite3_finalize(statement) }
            let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
            guard sqlite3_bind_text(statement, 1, record.id.uuidString, -1, transient) == SQLITE_OK,
                  sqlite3_bind_text(statement, 2, payload, -1, transient) == SQLITE_OK,
                  sqlite3_step(statement) == SQLITE_DONE else { throw error("write") }
            try execute("COMMIT")
        } catch {
            // Rollback cannot replace the actual write error.
            _ = sqlite3_exec(database, "ROLLBACK", nil, nil, nil)
            throw error
        }
    }

    private func execute(_ sql: String) throws {
        guard sqlite3_exec(database, sql, nil, nil, nil) == SQLITE_OK else { throw error("SQL") }
    }
    private func error(_ operation: String) -> SQLiteStoreError {
        SQLiteStoreError(operation: operation, detail: database.map { String(cString: sqlite3_errmsg($0)) } ?? "database unavailable")
    }
}
