import Foundation
import SwiftUI

/// Tag categories for auto-classification of screenshot content.
enum ScreenshotTag: String, CaseIterable, Identifiable {
    case code
    case conversation
    case article
    case notes
    case receipt
    case design
    case data
    case other

    var id: String { rawValue }

    var displayName: String {
        rawValue.capitalized
    }

    var tagColor: Color {
        switch self {
        case .code: return Color(red: 0.3, green: 0.65, blue: 0.3)
        case .conversation: return Color(red: 0.3, green: 0.5, blue: 0.85)
        case .article: return Color(red: 0.75, green: 0.55, blue: 0.2)
        case .notes: return Color(red: 0.65, green: 0.4, blue: 0.75)
        case .receipt: return Color(red: 0.2, green: 0.7, blue: 0.65)
        case .design: return Color(red: 0.8, green: 0.35, blue: 0.35)
        case .data: return Color(red: 0.35, green: 0.55, blue: 0.85)
        case .other: return Color(red: 0.45, green: 0.45, blue: 0.45)
        }
    }
}

/// A single screenshot entry with OCR text, tag, and metadata.
struct ScreenshotItem: Identifiable, Equatable {
    let id: Int64
    let filePath: String
    let ocrText: String?
    let tag: ScreenshotTag
    let appName: String?
    let createdAt: Date
    let thumbnail: Data?

    /// First line of OCR text for preview display
    var preview: String {
        guard let text = ocrText, !text.isEmpty else { return "No text found" }
        let firstLine = text.components(separatedBy: .newlines).first(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty }) ?? text
        if firstLine.count > 100 {
            return String(firstLine.prefix(100)) + "..."
        }
        return firstLine
    }

    /// Relative time string for display
    private static let timeFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f
    }()

    var relativeTime: String {
        Self.timeFormatter.localizedString(for: createdAt, relativeTo: Date())
    }

    /// File name extracted from path
    var fileName: String {
        (filePath as NSString).lastPathComponent
    }

    /// Whether the source file still exists on disk
    var fileExists: Bool {
        FileManager.default.fileExists(atPath: filePath)
    }

    static func == (lhs: ScreenshotItem, rhs: ScreenshotItem) -> Bool {
        lhs.id == rhs.id
    }
}
