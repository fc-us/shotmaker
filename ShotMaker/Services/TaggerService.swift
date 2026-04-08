import Foundation
import NaturalLanguage

/// Auto-tags screenshots into categories using keyword heuristics and NLTagger fallback.
final class TaggerService {

    /// Classify OCR text into a screenshot tag category.
    func classify(text: String?) -> ScreenshotTag {
        guard let text = text, !text.isEmpty else { return .other }

        let lower = text.lowercased()
        let scores = computeKeywordScores(lower)

        // Return the tag with the highest score, if any keywords matched
        if let best = scores.max(by: { $0.value < $1.value }), best.value > 0 {
            return best.key
        }

        // Fallback: use NLTagger to detect if it's article-like prose
        return classifyWithNLTagger(text)
    }

    // MARK: - Keyword Heuristics

    private func computeKeywordScores(_ text: String) -> [ScreenshotTag: Int] {
        var scores: [ScreenshotTag: Int] = [:]

        let codeTerms = ["func ", "var ", "let ", "class ", "import ", "def ", "return ", "=>",
                         "error:", "stack trace", "typeerror", "exception", "syntax error",
                         "console.log", "print(", "println", "struct ", "enum ", "interface ",
                         "const ", "async ", "await ", "function ", "module ", "require(",
                         "nil", "null", "undefined", "boolean", "string", "int "]
        let codeSymbols = ["{ }", "{ {", "} }", "();", "->", "::", "//", "/*", "*/", "&&", "||", "!=", "=="]

        let conversationTerms = ["said", "hey", "lol", "thanks", "sent", "replied", "message",
                                  "chat", "typing...", "delivered", "read ", "online", "offline",
                                  "dm", "reacted", "haha", "bruh", "ok ", "okay",
                                  "idk", "lmao", "nah", "yeah"]

        let articleTerms = ["published", "author", "read more", "subscribe", "by ", "share",
                            "min read", "views", "comments", "article", "opinion", "editorial",
                            "according to", "reported", "source:", "updated", "breaking"]

        let notesTerms = ["todo", "action item", "meeting", "agenda", "minutes", "bullet",
                          "note:", "notes:", "reminder", "follow up", "due date", "assigned",
                          "priority", "status:", "blocked", "in progress", "done", "task"]

        let receiptTerms = ["invoice", "total", "payment", "order", "amount", "tax", "subtotal",
                            "receipt", "paid", "billing", "charge", "transaction", "qty",
                            "quantity", "unit price", "shipping", "discount"]

        let designTerms = ["px", "rem", "figma", "sketch", "layer", "artboard", "opacity",
                           "gradient", "border-radius", "font-size", "line-height", "padding",
                           "margin", "flexbox", "grid", "component", "prototype", "wireframe"]

        let dataTerms = ["chart", "graph", "table", "row", "column", "metric", "dashboard",
                         "analytics", "kpi", "report", "quarterly", "revenue", "growth",
                         "trend", "average", "median", "sum", "count"]

        scores[.code] = countMatches(text, terms: codeTerms) * 2 + countMatches(text, terms: codeSymbols)
        scores[.conversation] = countMatches(text, terms: conversationTerms) * 2
        scores[.article] = countMatches(text, terms: articleTerms)
        scores[.notes] = countMatches(text, terms: notesTerms) * 2
        scores[.receipt] = countMatches(text, terms: receiptTerms) * 2
        scores[.design] = countMatches(text, terms: designTerms)
        scores[.data] = countMatches(text, terms: dataTerms)

        // Boost receipt if dollar signs present
        let dollarCount = text.components(separatedBy: "$").count - 1
        scores[.receipt] = (scores[.receipt] ?? 0) + dollarCount * 3

        // Boost code if lots of special characters
        let specialChars = text.filter { "{}[]();=<>|&!@#".contains($0) }.count
        if specialChars > 10 {
            scores[.code] = (scores[.code] ?? 0) + specialChars / 5
        }

        // Boost article if long paragraph-like text
        let lines = text.components(separatedBy: "\n").filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        let longLines = lines.filter { $0.count > 80 }.count
        if longLines > 3 {
            scores[.article] = (scores[.article] ?? 0) + longLines
        }

        // Boost data if percentage signs present
        let pctCount = text.components(separatedBy: "%").count - 1
        scores[.data] = (scores[.data] ?? 0) + pctCount * 2

        // Detect hex colors for design
        let hexPattern = "#[0-9a-f]{3,8}"
        if let regex = try? NSRegularExpression(pattern: hexPattern, options: []) {
            let hexCount = regex.numberOfMatches(in: text, range: NSRange(text.startIndex..., in: text))
            scores[.design] = (scores[.design] ?? 0) + hexCount * 2
        }

        return scores
    }

    private func countMatches(_ text: String, terms: [String]) -> Int {
        var count = 0
        for term in terms {
            if text.contains(term) {
                count += 1
            }
        }
        return count
    }

    // MARK: - NLTagger Fallback

    private func classifyWithNLTagger(_ text: String) -> ScreenshotTag {
        let tagger = NLTagger(tagSchemes: [.lexicalClass])
        tagger.string = text

        var nounCount = 0
        var verbCount = 0
        var totalWords = 0

        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .lexicalClass) { tag, _ in
            totalWords += 1
            if tag == .noun { nounCount += 1 }
            if tag == .verb { verbCount += 1 }
            return totalWords < 200 // Limit processing for long texts
        }

        // High noun+verb density suggests prose (article)
        if totalWords > 30 && Double(nounCount + verbCount) / Double(totalWords) > 0.5 {
            return .article
        }

        return .other
    }
}
