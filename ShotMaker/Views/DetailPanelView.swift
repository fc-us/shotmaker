import SwiftUI

struct DetailPanelView: View {
    let item: ScreenshotItem?
    var searchQuery: String = ""
    let onDelete: (ScreenshotItem) -> Void
    var onRetag: ((ScreenshotItem, ScreenshotTag) -> Void)? = nil
    @State private var copyFeedback: String? = nil

    var body: some View {
        VStack(spacing: 0) {
            if let item = item {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        // Large thumbnail preview
                        if let thumbnailData = item.thumbnail,
                           let nsImage = NSImage(data: thumbnailData) {
                            Image(nsImage: nsImage)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .cornerRadius(6)
                                .frame(maxWidth: .infinity)
                        } else {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.white.opacity(0.04))
                                .frame(height: 140)
                                .overlay(
                                    Image(systemName: "photo")
                                        .font(.system(size: 28))
                                        .foregroundColor(.secondary)
                                )
                        }

                        // Metadata section
                        VStack(alignment: .leading, spacing: 8) {
                            // Tag (click to change)
                            HStack {
                                Text("Tag")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundColor(.secondary)
                                Spacer()
                                Menu {
                                    ForEach(ScreenshotTag.allCases) { tag in
                                        Button(tag.displayName) {
                                            onRetag?(item, tag)
                                        }
                                    }
                                } label: {
                                    TagBadge(tag: item.tag)
                                }
                                .menuStyle(.borderlessButton)
                                .fixedSize()
                            }

                            // App
                            if let appName = item.appName {
                                HStack {
                                    Text("App")
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Text(appName)
                                        .font(.system(size: 11))
                                        .foregroundColor(.white.opacity(0.8))
                                }
                            }

                            // Captured time
                            HStack {
                                Text("Captured")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(formatDate(item.createdAt))
                                    .font(.system(size: 11))
                                    .foregroundColor(.white.opacity(0.8))
                            }

                            // File name
                            HStack {
                                Text("File")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(item.fileName)
                                    .font(.system(size: 10))
                                    .foregroundColor(.white.opacity(0.6))
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                        }
                        .padding(10)
                        .background(Color.white.opacity(0.04))
                        .cornerRadius(6)

                        // Extracted text
                        VStack(alignment: .leading, spacing: 4) {
                            Text("EXTRACTED TEXT")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(.secondary)

                            if let ocrText = item.ocrText, !ocrText.isEmpty {
                                Text(TextHighlighter.highlight(ocrText, query: searchQuery))
                                    .font(.system(size: 11))
                                    .textSelection(.enabled)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            } else {
                                Text("No text found in this image")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                                    .italic()
                            }
                        }
                        .padding(10)
                        .background(Color.white.opacity(0.04))
                        .cornerRadius(6)

                        // Action buttons
                        VStack(spacing: 6) {
                            // Copy Image
                            Button(action: { copyImage(item) }) {
                                HStack {
                                    Image(systemName: "photo.on.rectangle")
                                        .font(.system(size: 11))
                                    Text("Copy Image")
                                        .font(.system(size: 12))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 6)
                                .background(Color.white.opacity(0.08))
                                .cornerRadius(5)
                            }
                            .buttonStyle(.plain)
                            .disabled(!item.fileExists)

                            // Copy Text
                            Button(action: { copyText(item) }) {
                                HStack {
                                    Image(systemName: "doc.on.doc")
                                        .font(.system(size: 11))
                                    Text("Copy Text")
                                        .font(.system(size: 12))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 6)
                                .background(Color.white.opacity(0.08))
                                .cornerRadius(5)
                            }
                            .buttonStyle(.plain)
                            .disabled(item.ocrText == nil || item.ocrText?.isEmpty == true)

                            // Open in Finder
                            Button(action: { openInFinder(item) }) {
                                HStack {
                                    Image(systemName: "folder")
                                        .font(.system(size: 11))
                                    Text("Show in Finder")
                                        .font(.system(size: 12))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 6)
                                .background(Color.white.opacity(0.08))
                                .cornerRadius(5)
                            }
                            .buttonStyle(.plain)
                            .disabled(!item.fileExists)

                            // Delete from DB
                            Button(action: { onDelete(item) }) {
                                HStack {
                                    Image(systemName: "trash")
                                        .font(.system(size: 11))
                                    Text("Remove from Library")
                                        .font(.system(size: 12))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 6)
                                .background(Color.red.opacity(0.15))
                                .cornerRadius(5)
                                .foregroundColor(Color.red.opacity(0.9))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(12)
                }
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "sidebar.right")
                        .font(.system(size: 28))
                        .foregroundColor(.secondary)
                    Text("Click one to see details")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(width: 240)
        .background(Color(nsColor: NSColor(calibratedWhite: 0.10, alpha: 1.0)))
        .overlay(alignment: .top) {
            if let feedback = copyFeedback {
                Text(feedback)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.green.opacity(0.85))
                    .cornerRadius(6)
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .animation(.easeInOut(duration: 0.2), value: feedback)
            }
        }
    }

    // MARK: - Actions

    private func copyImage(_ item: ScreenshotItem) {
        guard let image = NSImage(contentsOfFile: item.filePath) else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.writeObjects([image])
        showCopyFeedback("Image copied")
    }

    private func copyText(_ item: ScreenshotItem) {
        guard let text = item.ocrText else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        showCopyFeedback("Text copied")
    }

    private func showCopyFeedback(_ message: String) {
        copyFeedback = message
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            if copyFeedback == message { copyFeedback = nil }
        }
    }

    private func openInFinder(_ item: ScreenshotItem) {
        let url = URL(fileURLWithPath: item.filePath)
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    private func formatDate(_ date: Date) -> String {
        Self.dateFormatter.string(from: date)
    }
}
