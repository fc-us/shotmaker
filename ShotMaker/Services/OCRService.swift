import Foundation
import Vision
import AppKit

/// Performs on-device OCR using Apple Vision framework.
/// All processing happens on a background queue. Completions fire on background queue.
final class OCRService {
    private let processingQueue = DispatchQueue(label: "org.frontiercommons.shot-maker.ocr", qos: .utility)

    /// Perform OCR on an image file. Completion fires on a background queue.
    func recognizeText(at filePath: String, completion: @escaping (String?) -> Void) {
        processingQueue.async {
            guard let image = NSImage(contentsOfFile: filePath),
                  let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
                completion(nil)
                return
            }

            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    print("[ShotMaker] OCR error: \(error.localizedDescription)")
                    completion(nil)
                    return
                }

                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    completion(nil)
                    return
                }

                let text = observations.compactMap { observation in
                    observation.topCandidates(1).first?.string
                }.joined(separator: "\n")

                completion(text.isEmpty ? nil : text)
            }

            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                print("[ShotMaker] Vision request failed: \(error.localizedDescription)")
                completion(nil)
            }
        }
    }

    /// Generate a small JPEG thumbnail using CoreGraphics (thread-safe, no AppKit drawing).
    func generateThumbnail(at filePath: String, maxDimension: CGFloat = 200) -> Data? {
        guard let image = NSImage(contentsOfFile: filePath),
              let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }

        let originalWidth = CGFloat(cgImage.width)
        let originalHeight = CGFloat(cgImage.height)
        let scale = min(maxDimension / originalWidth, maxDimension / originalHeight, 1.0)
        let newWidth = Int(originalWidth * scale)
        let newHeight = Int(originalHeight * scale)

        guard let context = CGContext(
            data: nil,
            width: newWidth, height: newHeight,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        context.interpolationQuality = .high
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: newWidth, height: newHeight))

        guard let resultCG = context.makeImage() else { return nil }

        let bitmap = NSBitmapImageRep(cgImage: resultCG)
        return bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.3])
    }
}
