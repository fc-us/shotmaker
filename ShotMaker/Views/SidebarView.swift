import SwiftUI

struct SidebarView: View {
    @Binding var searchQuery: String
    @Binding var selectedTag: String?
    @Binding var selectedApp: String?
    @Binding var semanticMode: Bool
    let tagCounts: [(String, Int)]
    let appCounts: [(String, Int)]
    let onSearch: () -> Void
    let onPasteAndSearch: () -> Void

    @FocusState private var searchFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Search field
            HStack(spacing: 6) {
                Image(systemName: semanticMode ? "sparkles" : "magnifyingglass")
                    .foregroundColor(semanticMode ? .purple : .secondary)
                    .font(.system(size: 12))
                TextField(semanticMode ? "Search by meaning..." : "Search text...", text: $searchQuery)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .focused($searchFocused)
                    .onSubmit { onSearch() }
                if !searchQuery.isEmpty {
                    Button(action: {
                        searchQuery = ""
                        onSearch()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                            .font(.system(size: 11))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
            .background(Color.white.opacity(0.06))
            .cornerRadius(6)
            .padding(.horizontal, 12)
            .padding(.top, 12)
            .padding(.bottom, 6)

            // Mode toggle + paste
            HStack(spacing: 6) {
                Button(action: {
                    semanticMode.toggle()
                    onSearch()
                }) {
                    HStack(spacing: 3) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 9))
                        Text(semanticMode ? "Smart" : "Exact")
                            .font(.system(size: 10, weight: .medium))
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(semanticMode ? Color.purple.opacity(0.25) : Color.white.opacity(0.06))
                    .cornerRadius(4)
                    .foregroundColor(semanticMode ? .purple : .secondary)
                }
                .buttonStyle(.plain)
                .help("Toggle semantic vs exact search")

                Button(action: onPasteAndSearch) {
                    HStack(spacing: 3) {
                        Image(systemName: "doc.on.clipboard")
                            .font(.system(size: 9))
                        Text("Paste")
                            .font(.system(size: 10, weight: .medium))
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.white.opacity(0.06))
                    .cornerRadius(4)
                    .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Paste image from clipboard and ingest")

                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 8)

            Divider()
                .padding(.horizontal, 12)

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Tag filters
                    if !tagCounts.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("TAGS")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 12)
                                .padding(.top, 8)

                            // "All" option
                            FilterRow(
                                label: "All",
                                count: tagCounts.reduce(0) { $0 + $1.1 },
                                isSelected: selectedTag == nil,
                                color: .white
                            ) {
                                selectedTag = nil
                                onSearch()
                            }

                            ForEach(tagCounts, id: \.0) { tag, count in
                                let screenshotTag = ScreenshotTag(rawValue: tag) ?? .other
                                FilterRow(
                                    label: screenshotTag.displayName,
                                    count: count,
                                    isSelected: selectedTag == tag,
                                    color: screenshotTag.tagColor
                                ) {
                                    selectedTag = selectedTag == tag ? nil : tag
                                    onSearch()
                                }
                            }
                        }
                    }

                    // App filters
                    if !appCounts.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("APPS")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 12)

                            ForEach(appCounts, id: \.0) { app, count in
                                FilterRow(
                                    label: app,
                                    count: count,
                                    isSelected: selectedApp == app,
                                    color: .white
                                ) {
                                    selectedApp = selectedApp == app ? nil : app
                                    onSearch()
                                }
                            }
                        }
                    }
                }
                .padding(.bottom, 12)
            }
        }
        .frame(width: 180)
        .background(Color(nsColor: NSColor(calibratedWhite: 0.10, alpha: 1.0)))
        .onReceive(NotificationCenter.default.publisher(for: .focusSearch)) { _ in
            searchFocused = true
        }
    }

}

struct FilterRow: View {
    let label: String
    let count: Int
    let isSelected: Bool
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Circle()
                    .fill(color)
                    .frame(width: 6, height: 6)
                Text(label)
                    .font(.system(size: 12))
                    .foregroundColor(isSelected ? .white : .secondary)
                    .lineLimit(1)
                Spacer()
                Text("\(count)")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .background(isSelected ? Color.white.opacity(0.1) : Color.clear)
            .cornerRadius(4)
        }
        .buttonStyle(.plain)
    }
}
