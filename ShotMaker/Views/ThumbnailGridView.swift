import SwiftUI

struct ThumbnailGridView: View {
    let items: [ScreenshotItem]
    @Binding var selectedItem: ScreenshotItem?
    let thumbnailSize: Double
    var searchQuery: String = ""

    private var columns: [GridItem] {
        [GridItem(.adaptive(minimum: max(thumbnailSize, 120)), spacing: 8)]
    }

    var body: some View {
        if items.isEmpty {
            VStack(spacing: 12) {
                Image(systemName: "text.viewfinder")
                    .font(.system(size: 36))
                    .foregroundColor(.secondary)
                Text("Nothing here yet")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                Text("Press ⌘⇧4 — text gets extracted on the spot")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 300)
                Text("All data stays on your Mac")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary.opacity(0.5))
                    .padding(.top, 4)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(items) { item in
                        ThumbnailCard(
                            item: item,
                            isSelected: selectedItem?.id == item.id,
                            size: thumbnailSize,
                            searchQuery: searchQuery
                        )
                        .onDrag {
                            let url = URL(fileURLWithPath: item.filePath)
                            return NSItemProvider(contentsOf: url) ?? NSItemProvider()
                        }
                        .onTapGesture(count: 2) {
                            openInPreview(item)
                        }
                        .onTapGesture {
                            selectedItem = item
                        }
                    }
                }
                .padding(8)
            }
        }
    }

    private func openInPreview(_ item: ScreenshotItem) {
        guard item.fileExists else { return }
        NSWorkspace.shared.open(URL(fileURLWithPath: item.filePath))
    }
}

struct ThumbnailCard: View {
    let item: ScreenshotItem
    let isSelected: Bool
    let size: Double
    var searchQuery: String = ""
    @State private var isHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Thumbnail image
            ZStack {
                Rectangle()
                    .fill(Color.white.opacity(0.04))

                if let thumbnailData = item.thumbnail,
                   let nsImage = NSImage(data: thumbnailData) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } else {
                    Image(systemName: "photo")
                        .font(.system(size: 24))
                        .foregroundColor(.secondary)
                }
            }
            .frame(height: size * 0.6)
            .cornerRadius(4)
            .clipped()

            // Preview text with search highlighting
            Text(TextHighlighter.highlight(item.preview, query: searchQuery, baseColor: .white.opacity(0.8)))
                .font(.system(size: 10))
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Metadata row
            HStack(spacing: 4) {
                if let appName = item.appName {
                    Text(appName)
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                Text(item.relativeTime)
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
            }

            // Tag badge
            TagBadge(tag: item.tag)
        }
        .padding(6)
        .background(Color.white.opacity(isSelected ? 0.08 : isHovered ? 0.06 : 0.03))
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(isSelected ? Color.blue : Color.white.opacity(isHovered ? 0.15 : 0.08), lineWidth: isSelected ? 2 : 1)
        )
        .onHover { hovering in isHovered = hovering }
        .animation(.easeInOut(duration: 0.15), value: isHovered)
    }
}

struct TagBadge: View {
    let tag: ScreenshotTag

    var body: some View {
        Text(tag.displayName)
            .font(.system(size: 9, weight: .medium))
            .foregroundColor(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(tag.tagColor)
            .cornerRadius(3)
    }

}
