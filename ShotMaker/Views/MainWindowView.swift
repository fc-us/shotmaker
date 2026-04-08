import SwiftUI

struct MainWindowView: View {
    @EnvironmentObject var watcher: ScreenshotWatcher
    @EnvironmentObject var settings: AppSettings

    @State private var searchQuery: String = ""
    @State private var selectedTag: String? = nil
    @State private var selectedApp: String? = nil
    @State private var selectedItem: ScreenshotItem? = nil
    @State private var exportMessage: String? = nil

    var body: some View {
        HStack(spacing: 0) {
            // Left sidebar: search + filters
            SidebarView(
                searchQuery: $searchQuery,
                selectedTag: $selectedTag,
                selectedApp: $selectedApp,
                tagCounts: watcher.tagCounts,
                appCounts: watcher.appCounts,
                onSearch: performSearch
            )

            Divider()

            // Center: thumbnail grid
            ThumbnailGridView(
                items: watcher.items,
                selectedItem: $selectedItem,
                thumbnailSize: settings.thumbnailSize
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(nsColor: NSColor(calibratedWhite: 0.12, alpha: 1.0)))

            Divider()

            // Right: detail panel
            DetailPanelView(
                item: selectedItem,
                onDelete: { item in
                    watcher.delete(item)
                    if selectedItem?.id == item.id {
                        selectedItem = nil
                    }
                },
                onRetag: { item, tag in
                    watcher.retag(item, tag: tag)
                    if selectedItem?.id == item.id {
                        selectedItem = watcher.items.first(where: { $0.id == item.id })
                    }
                }
            )
        }
        .toolbar {
            ToolbarItem(placement: .automatic) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(watcher.isWatching ? Color.green : Color.red)
                        .frame(width: 7, height: 7)
                    Text(watcher.isWatching ? "Watching" : "Paused")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    Button(action: { watcher.toggleWatching() }) {
                        Image(systemName: watcher.isWatching ? "pause.circle" : "play.circle")
                    }
                    .help(watcher.isWatching ? "Pause watching" : "Resume watching")
                }
            }
            ToolbarItem(placement: .automatic) {
                Text("\(watcher.totalCount) screenshots · \(settings.watchDirectory.components(separatedBy: "/").last ?? "Desktop")")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            ToolbarItem(placement: .automatic) {
                Button(action: { exportToObsidian() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "square.and.arrow.up")
                        Text("Obsidian")
                            .font(.system(size: 11))
                    }
                }
                .help("Export all screenshots as Obsidian markdown notes")
            }
            ToolbarItem(placement: .automatic) {
                Button(action: {
                    NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
                }) {
                    Image(systemName: "gear")
                }
                .help("Preferences")
            }
        }
        .frame(minWidth: 900, minHeight: 600)
        .background(Color(nsColor: NSColor(calibratedWhite: 0.11, alpha: 1.0)))
        .preferredColorScheme(.dark)
        .overlay(alignment: .bottom) {
            if let msg = exportMessage {
                Text(msg)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.green.opacity(0.85))
                    .cornerRadius(8)
                    .padding(.bottom, 16)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .animation(.easeInOut(duration: 0.2), value: msg)
            }
        }
        .onDeleteCommand {
            if let item = selectedItem {
                watcher.delete(item)
                selectedItem = nil
            }
        }
        .onAppear {
            if let delegate = NSApplication.shared.delegate as? StatusBarDelegate {
                delegate.setWatcher(watcher)
            }
        }
    }

    private func exportToObsidian() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.prompt = "Export Here"
        panel.message = "Choose a folder to export Obsidian markdown notes"

        guard panel.runModal() == .OK, let url = panel.url else { return }

        let items = watcher.items
        var exported = 0

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd-HHmmss"
        let readableDateFormatter = DateFormatter()
        readableDateFormatter.dateStyle = .medium
        readableDateFormatter.timeStyle = .short

        for item in items {
            let dateStr = dateFormatter.string(from: item.createdAt)
            let readableDate = readableDateFormatter.string(from: item.createdAt)

            let text = (item.ocrText ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let firstLine = text.components(separatedBy: .newlines).first(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty }) ?? "No text"
            let safeTitle = firstLine.prefix(40)
                .replacingOccurrences(of: "[^\\w\\s-]", with: "", options: .regularExpression)
                .trimmingCharacters(in: .whitespaces)
                .replacingOccurrences(of: " ", with: "-")

            let filename = "screenshot-\(dateStr)-\(safeTitle).md"
            let basename = (item.filePath as NSString).lastPathComponent

            let content = """
            ---
            type: screenshot
            tag: \(item.tag.rawValue)
            app: \(item.appName ?? "unknown")
            captured: \(readableDate)
            source: \(item.filePath)
            ---

            # \(firstLine)

            **App:** \(item.appName ?? "unknown")
            **Tag:** \(item.tag.displayName)
            **Captured:** \(readableDate)
            **File:** `\(basename)`

            ## Extracted Text

            \(text)
            """.replacingOccurrences(of: "            ", with: "")

            let fileURL = url.appendingPathComponent(filename)
            try? content.write(to: fileURL, atomically: true, encoding: .utf8)
            exported += 1
        }

        exportMessage = "Exported \(exported) notes"
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            if exportMessage == "Exported \(exported) notes" { exportMessage = nil }
        }

        // Open the folder in Finder
        NSWorkspace.shared.open(url)
    }

    private func performSearch() {
        watcher.search(
            query: searchQuery,
            tag: selectedTag,
            appName: selectedApp
        )
    }
}
