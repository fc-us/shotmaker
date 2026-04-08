import Foundation

/// Protocol for screenshot storage backends.
/// Swap SQLite for Core Data or anything else by conforming to this.
protocol ScreenshotStorage {
    func save(filePath: String, ocrText: String?, tag: String, appName: String?, createdAt: Date, thumbnail: Data?) throws -> Int64
    func fetchAll(limit: Int, offset: Int) throws -> [ScreenshotItem]
    func search(query: String, limit: Int) throws -> [ScreenshotItem]
    func searchWithFilters(query: String, tag: String?, appName: String?, limit: Int) throws -> [ScreenshotItem]
    func updateTag(id: Int64, tag: String) throws
    func delete(id: Int64) throws
    func count() throws -> Int
    func tagCounts() throws -> [(String, Int)]
    func appCounts() throws -> [(String, Int)]
    func recentCount(since: Date) throws -> Int
}
