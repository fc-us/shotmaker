import SwiftUI

/// Builds an AttributedString with case-insensitive highlights for a search query.
enum TextHighlighter {
    static func highlight(_ text: String, query: String, baseColor: Color = .white.opacity(0.85)) -> AttributedString {
        var attr = AttributedString(text)
        attr.foregroundColor = baseColor

        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count >= 2 else { return attr }

        // Split multi-word queries into tokens for per-token highlighting
        let tokens = trimmed
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            .map(String.init)
            .filter { $0.count >= 2 }

        for token in tokens {
            var searchRange = attr.startIndex..<attr.endIndex
            while let range = attr[searchRange].range(of: token, options: .caseInsensitive) {
                attr[range].backgroundColor = Color.yellow.opacity(0.35)
                attr[range].foregroundColor = .white
                searchRange = range.upperBound..<attr.endIndex
            }
        }

        return attr
    }
}
