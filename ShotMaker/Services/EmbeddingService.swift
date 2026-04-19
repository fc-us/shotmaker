import Foundation
import NaturalLanguage

/// Computes sentence embeddings on-device using Apple's NLEmbedding.
/// No model download, no network. English only.
final class EmbeddingService {
    static let shared = EmbeddingService()
    private let embedding: NLEmbedding?

    private init() {
        embedding = NLEmbedding.sentenceEmbedding(for: .english)
    }

    var isAvailable: Bool { embedding != nil }

    /// Returns a normalized vector, or nil if unavailable.
    func vector(for text: String) -> [Float]? {
        guard let embedding = embedding else { return nil }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        // NLEmbedding averages across sentences for longer inputs
        let snippet = String(trimmed.prefix(2000))
        guard let vec = embedding.vector(for: snippet) else { return nil }

        let floats = vec.map { Float($0) }
        return normalize(floats)
    }

    /// Serialize a float vector as Data for SQLite BLOB storage.
    static func encode(_ vec: [Float]) -> Data {
        vec.withUnsafeBufferPointer { Data(buffer: $0) }
    }

    /// Deserialize a BLOB back into a float vector.
    static func decode(_ data: Data) -> [Float] {
        let count = data.count / MemoryLayout<Float>.size
        return data.withUnsafeBytes { ptr -> [Float] in
            guard let base = ptr.bindMemory(to: Float.self).baseAddress else { return [] }
            return Array(UnsafeBufferPointer(start: base, count: count))
        }
    }

    /// Cosine similarity between two normalized vectors. Range: -1...1.
    static func cosine(_ a: [Float], _ b: [Float]) -> Float {
        let n = min(a.count, b.count)
        guard n > 0 else { return 0 }
        var sum: Float = 0
        for i in 0..<n { sum += a[i] * b[i] }
        return sum
    }

    private func normalize(_ v: [Float]) -> [Float] {
        let mag = sqrtf(v.reduce(0) { $0 + $1 * $1 })
        guard mag > 0 else { return v }
        return v.map { $0 / mag }
    }
}
