import Foundation
import AppKit

/// Reads an image from the pasteboard, writes it to a temp PNG,
/// and returns the path so the watcher can process it like any other screenshot.
enum ClipboardImageService {
    static func captureToTempPNG() -> String? {
        let pb = NSPasteboard.general

        var nsImage: NSImage?
        if let img = NSImage(pasteboard: pb) {
            nsImage = img
        } else if let data = pb.data(forType: .tiff), let img = NSImage(data: data) {
            nsImage = img
        } else if let data = pb.data(forType: .png), let img = NSImage(data: data) {
            nsImage = img
        }

        guard let image = nsImage,
              let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let png = bitmap.representation(using: .png, properties: [:]) else {
            return nil
        }

        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd-HHmmss"
        let filename = "clipboard-\(fmt.string(from: Date()))-\(UUID().uuidString.prefix(8)).png"
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("ShotMaker-clipboard", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let url = dir.appendingPathComponent(filename)
        do {
            try png.write(to: url)
            return url.path
        } catch {
            return nil
        }
    }
}
