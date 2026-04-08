import Foundation
import SwiftUI

/// Persisted app settings via UserDefaults
class AppSettings: ObservableObject {
    static let shared = AppSettings()

    @AppStorage("watchDirectory") var watchDirectory: String = NSHomeDirectory() + "/Desktop"
    @AppStorage("launchAtLogin") var launchAtLogin: Bool = false
    @AppStorage("thumbnailSize") var thumbnailSize: Double = 200
    @AppStorage("isWatching") var isWatching: Bool = true
}
