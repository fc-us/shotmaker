import Foundation
import SQLite3

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

final class SQLiteStorage: ScreenshotStorage {
    private var db: OpaquePointer?
    private let dbPath: String
    private let queue = DispatchQueue(label: "org.frontiercommons.shot-maker.db")

    init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support")
        let appSupport = base.appendingPathComponent("ShotMaker", isDirectory: true)

        try? FileManager.default.createDirectory(
            at: appSupport,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        dbPath = appSupport.appendingPathComponent("screenshots.db").path(percentEncoded: false)

        if sqlite3_open_v2(dbPath, &db, SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX, nil) != SQLITE_OK {
            print("[ShotMaker] Failed to open database at \(dbPath): \(lastError())")
            return
        }

        execute("PRAGMA journal_mode=WAL")
        createTables()
        migrateAddEmbedding()
    }

    deinit {
        sqlite3_close(db)
    }

    // MARK: - Schema

    private func createTables() {
        let sql = """
        CREATE TABLE IF NOT EXISTS screenshots (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            file_path TEXT NOT NULL,
            ocr_text TEXT,
            tag TEXT DEFAULT 'other',
            app_name TEXT,
            created_at REAL NOT NULL,
            thumbnail BLOB
        );
        CREATE INDEX IF NOT EXISTS idx_created_at ON screenshots(created_at DESC);
        CREATE INDEX IF NOT EXISTS idx_tag ON screenshots(tag);
        CREATE INDEX IF NOT EXISTS idx_app_name ON screenshots(app_name);
        CREATE INDEX IF NOT EXISTS idx_file_path ON screenshots(file_path);
        """
        execute(sql)

        let fts = """
        CREATE VIRTUAL TABLE IF NOT EXISTS screenshots_fts USING fts5(
            ocr_text,
            content='screenshots',
            content_rowid='id'
        );
        """
        execute(fts)

        let triggers = """
        CREATE TRIGGER IF NOT EXISTS screenshots_ai AFTER INSERT ON screenshots BEGIN
            INSERT INTO screenshots_fts(rowid, ocr_text) VALUES (new.id, new.ocr_text);
        END;
        CREATE TRIGGER IF NOT EXISTS screenshots_ad AFTER DELETE ON screenshots BEGIN
            INSERT INTO screenshots_fts(screenshots_fts, rowid, ocr_text) VALUES('delete', old.id, old.ocr_text);
        END;
        CREATE TRIGGER IF NOT EXISTS screenshots_au AFTER UPDATE ON screenshots BEGIN
            INSERT INTO screenshots_fts(screenshots_fts, rowid, ocr_text) VALUES('delete', old.id, old.ocr_text);
            INSERT INTO screenshots_fts(rowid, ocr_text) VALUES (new.id, new.ocr_text);
        END;
        """
        execute(triggers)
    }

    private func migrateAddEmbedding() {
        // Idempotent: ALTER TABLE fails silently via execute() if column exists
        execute("ALTER TABLE screenshots ADD COLUMN embedding BLOB")
    }

    // MARK: - CRUD

    @discardableResult
    func save(filePath: String, ocrText: String?, tag: String, appName: String?, createdAt: Date, thumbnail: Data?, embedding: Data? = nil) throws -> Int64 {
        try queue.sync {
            guard let db = db else { throw StorageError.prepareFailed("Database not open") }

            // Check for duplicate file_path
            let checkSql = "SELECT id FROM screenshots WHERE file_path = ?1"
            var checkStmt: OpaquePointer?
            if sqlite3_prepare_v2(db, checkSql, -1, &checkStmt, nil) == SQLITE_OK {
                sqlite3_bind_text(checkStmt, 1, (filePath as NSString).utf8String, -1, SQLITE_TRANSIENT)
                if sqlite3_step(checkStmt) == SQLITE_ROW {
                    let existingId = sqlite3_column_int64(checkStmt, 0)
                    sqlite3_finalize(checkStmt)
                    return existingId
                }
            }
            sqlite3_finalize(checkStmt)

            let sql = """
            INSERT INTO screenshots (file_path, ocr_text, tag, app_name, created_at, thumbnail, embedding)
            VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7)
            """
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
                throw StorageError.prepareFailed(lastError())
            }

            sqlite3_bind_text(stmt, 1, (filePath as NSString).utf8String, -1, SQLITE_TRANSIENT)

            if let ocrText = ocrText {
                sqlite3_bind_text(stmt, 2, (ocrText as NSString).utf8String, -1, SQLITE_TRANSIENT)
            } else {
                sqlite3_bind_null(stmt, 2)
            }

            sqlite3_bind_text(stmt, 3, (tag as NSString).utf8String, -1, SQLITE_TRANSIENT)

            if let appName = appName {
                sqlite3_bind_text(stmt, 4, (appName as NSString).utf8String, -1, SQLITE_TRANSIENT)
            } else {
                sqlite3_bind_null(stmt, 4)
            }

            sqlite3_bind_double(stmt, 5, createdAt.timeIntervalSince1970)

            if let thumbnail = thumbnail {
                thumbnail.withUnsafeBytes { ptr -> Void in
                    _ = sqlite3_bind_blob(stmt, 6, ptr.baseAddress, Int32(thumbnail.count), SQLITE_TRANSIENT)
                }
            } else {
                sqlite3_bind_null(stmt, 6)
            }

            if let embedding = embedding {
                embedding.withUnsafeBytes { ptr -> Void in
                    _ = sqlite3_bind_blob(stmt, 7, ptr.baseAddress, Int32(embedding.count), SQLITE_TRANSIENT)
                }
            } else {
                sqlite3_bind_null(stmt, 7)
            }

            guard sqlite3_step(stmt) == SQLITE_DONE else {
                let err = lastError()
                sqlite3_finalize(stmt)
                throw StorageError.insertFailed(err)
            }

            let rowId = sqlite3_last_insert_rowid(db)
            sqlite3_finalize(stmt)
            return rowId
        }
    }

    /// Load (id, ocrText, embedding) for rows matching optional tag/appName filters.
    /// Filtering in SQL ensures semantic search only scores relevant rows.
    func allEmbeddings(tag: String? = nil, appName: String? = nil) throws -> [(id: Int64, ocrText: String, embedding: Data?)] {
        try queue.sync {
            guard let db = db else { throw StorageError.prepareFailed("Database not open") }
            var conditions = ["ocr_text IS NOT NULL"]
            var params: [String] = []
            if let t = tag { conditions.append("tag = ?"); params.append(t) }
            if let a = appName { conditions.append("app_name = ?"); params.append(a) }
            let sql = "SELECT id, ocr_text, embedding FROM screenshots WHERE \(conditions.joined(separator: " AND "))"
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
                throw StorageError.prepareFailed(lastError())
            }
            for (i, param) in params.enumerated() {
                sqlite3_bind_text(stmt, Int32(i + 1), (param as NSString).utf8String, -1, SQLITE_TRANSIENT)
            }
            var results: [(Int64, String, Data?)] = []
            while sqlite3_step(stmt) == SQLITE_ROW {
                let id = sqlite3_column_int64(stmt, 0)
                guard let cStr = sqlite3_column_text(stmt, 1) else { continue }
                let text = String(cString: cStr)
                var emb: Data? = nil
                if sqlite3_column_type(stmt, 2) != SQLITE_NULL {
                    let blobPtr = sqlite3_column_blob(stmt, 2)
                    let blobSize = sqlite3_column_bytes(stmt, 2)
                    if let blobPtr = blobPtr, blobSize > 0 {
                        emb = Data(bytes: blobPtr, count: Int(blobSize))
                    }
                }
                results.append((id, text, emb))
            }
            sqlite3_finalize(stmt)
            return results
        }
    }

    func updateEmbedding(id: Int64, embedding: Data) throws {
        try queue.sync {
            guard let db = db else { throw StorageError.prepareFailed("Database not open") }
            let sql = "UPDATE screenshots SET embedding = ?1 WHERE id = ?2"
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
                throw StorageError.prepareFailed(lastError())
            }
            embedding.withUnsafeBytes { ptr -> Void in
                _ = sqlite3_bind_blob(stmt, 1, ptr.baseAddress, Int32(embedding.count), SQLITE_TRANSIENT)
            }
            sqlite3_bind_int64(stmt, 2, id)
            guard sqlite3_step(stmt) == SQLITE_DONE else {
                let err = lastError()
                sqlite3_finalize(stmt)
                throw StorageError.insertFailed(err)
            }
            sqlite3_finalize(stmt)
        }
    }

    func fetchByIds(_ ids: [Int64]) throws -> [ScreenshotItem] {
        guard !ids.isEmpty else { return [] }
        let placeholders = ids.map { _ in "?" }.joined(separator: ",")
        let sql = """
        SELECT id, file_path, ocr_text, tag, app_name, created_at, thumbnail
        FROM screenshots WHERE id IN (\(placeholders))
        """
        return try query(sql: sql) { stmt in
            for (i, id) in ids.enumerated() {
                sqlite3_bind_int64(stmt, Int32(i + 1), id)
            }
        }
    }

    func fetchAll(limit: Int = 100, offset: Int = 0) throws -> [ScreenshotItem] {
        let sql = """
        SELECT id, file_path, ocr_text, tag, app_name, created_at, thumbnail
        FROM screenshots
        ORDER BY created_at DESC
        LIMIT ?1 OFFSET ?2
        """
        return try query(sql: sql) { stmt in
            sqlite3_bind_int(stmt, 1, Int32(limit))
            sqlite3_bind_int(stmt, 2, Int32(offset))
        }
    }

    func search(query searchText: String, limit: Int = 100) throws -> [ScreenshotItem] {
        if searchText.trimmingCharacters(in: .whitespaces).isEmpty {
            return try fetchAll(limit: limit)
        }

        let sql = """
        SELECT s.id, s.file_path, s.ocr_text, s.tag, s.app_name, s.created_at, s.thumbnail
        FROM screenshots s
        JOIN screenshots_fts f ON s.id = f.rowid
        WHERE screenshots_fts MATCH ?1
        ORDER BY s.created_at DESC
        LIMIT ?2
        """
        return try self.query(sql: sql) { stmt in
            let escaped = searchText.replacingOccurrences(of: "\"", with: "\"\"")
            let ftsQuery = "\"\(escaped)\""
            sqlite3_bind_text(stmt, 1, (ftsQuery as NSString).utf8String, -1, SQLITE_TRANSIENT)
            sqlite3_bind_int(stmt, 2, Int32(limit))
        }
    }

    func searchWithFilters(query searchText: String, tag: String?, appName: String?, limit: Int = 100) throws -> [ScreenshotItem] {
        var conditions: [String] = []
        var bindings: [(Int32, Any)] = []
        var paramIndex: Int32 = 1
        var usesFTS = false

        let trimmedQuery = searchText.trimmingCharacters(in: .whitespaces)
        if !trimmedQuery.isEmpty {
            usesFTS = true
            conditions.append("screenshots_fts MATCH ?\(paramIndex)")
            let escaped = trimmedQuery.replacingOccurrences(of: "\"", with: "\"\"")
            bindings.append((paramIndex, "\"\(escaped)\""))
            paramIndex += 1
        }

        if let tag = tag {
            conditions.append("s.tag = ?\(paramIndex)")
            bindings.append((paramIndex, tag))
            paramIndex += 1
        }

        if let appName = appName {
            conditions.append("s.app_name = ?\(paramIndex)")
            bindings.append((paramIndex, appName))
            paramIndex += 1
        }

        let fromClause: String
        if usesFTS {
            fromClause = "FROM screenshots s JOIN screenshots_fts f ON s.id = f.rowid"
        } else {
            fromClause = "FROM screenshots s"
        }

        let whereClause = conditions.isEmpty ? "" : "WHERE " + conditions.joined(separator: " AND ")

        let sql = """
        SELECT s.id, s.file_path, s.ocr_text, s.tag, s.app_name, s.created_at, s.thumbnail
        \(fromClause)
        \(whereClause)
        ORDER BY s.created_at DESC
        LIMIT ?\(paramIndex)
        """

        return try self.query(sql: sql) { stmt in
            for (idx, value) in bindings {
                if let str = value as? String {
                    sqlite3_bind_text(stmt, idx, (str as NSString).utf8String, -1, SQLITE_TRANSIENT)
                }
            }
            sqlite3_bind_int(stmt, paramIndex, Int32(limit))
        }
    }

    func updateTag(id: Int64, tag: String) throws {
        try queue.sync {
            guard let db = db else { throw StorageError.prepareFailed("Database not open") }
            let sql = "UPDATE screenshots SET tag = ?1 WHERE id = ?2"
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
                throw StorageError.prepareFailed(lastError())
            }
            sqlite3_bind_text(stmt, 1, (tag as NSString).utf8String, -1, SQLITE_TRANSIENT)
            sqlite3_bind_int64(stmt, 2, id)
            guard sqlite3_step(stmt) == SQLITE_DONE else {
                let err = lastError()
                sqlite3_finalize(stmt)
                throw StorageError.insertFailed(err)
            }
            sqlite3_finalize(stmt)
        }
    }

    func delete(id: Int64) throws {
        try queue.sync {
            guard let db = db else { throw StorageError.prepareFailed("Database not open") }
            let sql = "DELETE FROM screenshots WHERE id = ?1"
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
                throw StorageError.prepareFailed(lastError())
            }
            sqlite3_bind_int64(stmt, 1, id)
            guard sqlite3_step(stmt) == SQLITE_DONE else {
                let err = lastError()
                sqlite3_finalize(stmt)
                throw StorageError.insertFailed(err)
            }
            sqlite3_finalize(stmt)
        }
    }

    func count() throws -> Int {
        queue.sync {
            let sql = "SELECT COUNT(*) FROM screenshots"
            var stmt: OpaquePointer?
            var result = 0
            if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
                if sqlite3_step(stmt) == SQLITE_ROW {
                    result = Int(sqlite3_column_int(stmt, 0))
                }
            }
            sqlite3_finalize(stmt)
            return result
        }
    }

    func tagCounts() throws -> [(String, Int)] {
        queue.sync {
            let sql = "SELECT tag, COUNT(*) as cnt FROM screenshots GROUP BY tag ORDER BY cnt DESC"
            var stmt: OpaquePointer?
            var results: [(String, Int)] = []
            if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
                while sqlite3_step(stmt) == SQLITE_ROW {
                    if sqlite3_column_type(stmt, 0) != SQLITE_NULL {
                        let tag = String(cString: sqlite3_column_text(stmt, 0))
                        let count = Int(sqlite3_column_int(stmt, 1))
                        results.append((tag, count))
                    }
                }
            }
            sqlite3_finalize(stmt)
            return results
        }
    }

    func appCounts() throws -> [(String, Int)] {
        queue.sync {
            let sql = "SELECT app_name, COUNT(*) as cnt FROM screenshots WHERE app_name IS NOT NULL GROUP BY app_name ORDER BY cnt DESC"
            var stmt: OpaquePointer?
            var results: [(String, Int)] = []
            if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
                while sqlite3_step(stmt) == SQLITE_ROW {
                    if sqlite3_column_type(stmt, 0) != SQLITE_NULL {
                        let app = String(cString: sqlite3_column_text(stmt, 0))
                        let count = Int(sqlite3_column_int(stmt, 1))
                        results.append((app, count))
                    }
                }
            }
            sqlite3_finalize(stmt)
            return results
        }
    }

    func recentCount(since: Date) throws -> Int {
        queue.sync {
            let sql = "SELECT COUNT(*) FROM screenshots WHERE created_at >= ?1"
            var stmt: OpaquePointer?
            var result = 0
            if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
                sqlite3_bind_double(stmt, 1, since.timeIntervalSince1970)
                if sqlite3_step(stmt) == SQLITE_ROW {
                    result = Int(sqlite3_column_int(stmt, 0))
                }
            }
            sqlite3_finalize(stmt)
            return result
        }
    }

    // MARK: - Helpers

    private func query(sql: String, bind: (OpaquePointer) -> Void) throws -> [ScreenshotItem] {
        try queue.sync {
            guard let db = db else { throw StorageError.prepareFailed("Database not open") }
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
                throw StorageError.prepareFailed(lastError())
            }

            bind(stmt!)
            var items: [ScreenshotItem] = []

            while sqlite3_step(stmt) == SQLITE_ROW {
                let id = sqlite3_column_int64(stmt, 0)

                guard sqlite3_column_type(stmt, 1) != SQLITE_NULL else { continue }
                let filePath = String(cString: sqlite3_column_text(stmt, 1))

                let ocrText: String? = sqlite3_column_type(stmt, 2) != SQLITE_NULL
                    ? String(cString: sqlite3_column_text(stmt, 2)) : nil

                let tagStr: String = sqlite3_column_type(stmt, 3) != SQLITE_NULL
                    ? String(cString: sqlite3_column_text(stmt, 3)) : "other"
                let tag = ScreenshotTag(rawValue: tagStr) ?? .other

                let appName: String? = sqlite3_column_type(stmt, 4) != SQLITE_NULL
                    ? String(cString: sqlite3_column_text(stmt, 4)) : nil

                let createdAt = Date(timeIntervalSince1970: sqlite3_column_double(stmt, 5))

                var thumbnail: Data? = nil
                if sqlite3_column_type(stmt, 6) != SQLITE_NULL {
                    let blobPtr = sqlite3_column_blob(stmt, 6)
                    let blobSize = sqlite3_column_bytes(stmt, 6)
                    if let blobPtr = blobPtr, blobSize > 0 {
                        thumbnail = Data(bytes: blobPtr, count: Int(blobSize))
                    }
                }

                let item = ScreenshotItem(
                    id: id,
                    filePath: filePath,
                    ocrText: ocrText,
                    tag: tag,
                    appName: appName,
                    createdAt: createdAt,
                    thumbnail: thumbnail
                )
                items.append(item)
            }

            sqlite3_finalize(stmt)
            return items
        }
    }

    private func execute(_ sql: String) {
        var errMsg: UnsafeMutablePointer<CChar>?
        if sqlite3_exec(db, sql, nil, nil, &errMsg) != SQLITE_OK {
            if let errMsg = errMsg {
                print("[ShotMaker] SQLite error: \(String(cString: errMsg))")
                sqlite3_free(errMsg)
            }
        }
    }

    private func lastError() -> String {
        if let err = sqlite3_errmsg(db) {
            return String(cString: err)
        }
        return "Unknown error"
    }
}

enum StorageError: Error, LocalizedError {
    case prepareFailed(String)
    case insertFailed(String)

    var errorDescription: String? {
        switch self {
        case .prepareFailed(let msg): return "SQL prepare failed: \(msg)"
        case .insertFailed(let msg): return "SQL insert failed: \(msg)"
        }
    }
}
