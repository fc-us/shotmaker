import Foundation
import SwiftUI

class AppSettings: ObservableObject {
    static let shared = AppSettings()

    @AppStorage("launchAtLogin") var launchAtLogin: Bool = false
    @AppStorage("thumbnailSize") var thumbnailSize: Double = 200
    @AppStorage("isWatching") var isWatching: Bool = true

    private static let bookmarkKey = "watchDirectoryBookmark"

    // Resolved path for code that just needs a string (FileManager calls etc.)
    var watchDirectory: String {
        resolvedWatchURL?.path ?? (NSHomeDirectory() + "/Desktop")
    }

    var hasWatchDirectoryPermission: Bool {
        UserDefaults.standard.data(forKey: Self.bookmarkKey) != nil
    }

    // Resolves the stored security-scoped bookmark back to a URL.
    // Returns nil if no bookmark is stored yet (first launch).
    var resolvedWatchURL: URL? {
        guard let data = UserDefaults.standard.data(forKey: Self.bookmarkKey) else { return nil }
        var isStale = false
        guard let url = try? URL(
            resolvingBookmarkData: data,
            options: .withSecurityScope,
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        ) else { return nil }
        if isStale, let fresh = try? url.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        ) {
            UserDefaults.standard.set(fresh, forKey: Self.bookmarkKey)
        }
        return url
    }

    // Call this with a URL returned from NSOpenPanel to store a security-scoped bookmark.
    func saveWatchDirectory(_ url: URL) throws {
        let data = try url.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        UserDefaults.standard.set(data, forKey: Self.bookmarkKey)
        objectWillChange.send()
    }
}
