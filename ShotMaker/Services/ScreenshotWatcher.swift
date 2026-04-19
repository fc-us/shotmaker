import Foundation
import AppKit
import Combine
import UserNotifications

/// Watches a directory for new PNG files and processes them through OCR + tagging.
final class ScreenshotWatcher: ObservableObject {
    @Published var items: [ScreenshotItem] = []
    @Published var isWatching: Bool = true
    @Published var tagCounts: [(String, Int)] = []
    @Published var appCounts: [(String, Int)] = []
    @Published var processingCount: Int = 0

    var totalCount: Int { items.count }
    var recentCount: Int {
        let startOfDay = Calendar.current.startOfDay(for: Date())
        return items.filter { $0.createdAt >= startOfDay }.count
    }

    private var pollTimer: Timer?
    private let storage: ScreenshotStorage
    private let ocrService = OCRService()
    private let taggerService = TaggerService()
    private let settings: AppSettings
    private var knownFiles: Set<String> = []
    private let processingQueue = DispatchQueue(label: "org.frontiercommons.shot-maker.watcher")
    private var lastWatchDir: String = ""

    init(storage: ScreenshotStorage = SQLiteStorage(), settings: AppSettings = .shared) {
        self.storage = storage
        self.settings = settings
        self.lastWatchDir = settings.watchDirectory
        loadItems()
        loadFilterCounts()
        requestNotificationPermission()
        if settings.isWatching {
            startWatching()
        }
    }

    deinit {
        stopWatching()
    }

    // MARK: - Notifications

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert]) { _, _ in }
    }

    private func sendNotification(tag: ScreenshotTag, ocrText: String?) {
        let content = UNMutableNotificationContent()
        content.title = "Screenshot captured"
        let preview = ocrText.flatMap { String($0.prefix(60)) } ?? "No text found"
        content.body = "Tagged as \(tag.displayName) — \(preview)"
        content.sound = nil
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Directory Watching

    func startWatching() {
        stopWatching()
        isWatching = true
        settings.isWatching = true
        lastWatchDir = settings.watchDirectory
        knownFiles.removeAll()
        scanExistingFiles()

        print("[ShotMaker] Watching directory: \(settings.watchDirectory)")
        print("[ShotMaker] Known files: \(knownFiles.count)")

        pollTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.checkForNewFiles()
        }
    }

    func stopWatching() {
        pollTimer?.invalidate()
        pollTimer = nil
        isWatching = false
        settings.isWatching = false
    }

    func toggleWatching() {
        if isWatching { stopWatching() } else { startWatching() }
    }

    /// Call this when settings change to restart if needed
    func restartIfDirectoryChanged() {
        if settings.watchDirectory != lastWatchDir && isWatching {
            startWatching()
        }
    }

    // MARK: - File Detection

    private func scanExistingFiles() {
        let dir = settings.watchDirectory
        guard let contents = try? FileManager.default.contentsOfDirectory(atPath: dir) else {
            print("[ShotMaker] Could not read directory: \(dir)")
            return
        }
        for file in contents where file.lowercased().hasSuffix(".png") {
            knownFiles.insert((dir as NSString).appendingPathComponent(file))
        }
        print("[ShotMaker] Scanned \(knownFiles.count) existing PNG files")
    }

    private func checkForNewFiles() {
        let dir = settings.watchDirectory
        guard let contents = try? FileManager.default.contentsOfDirectory(atPath: dir) else { return }

        // Capture frontmost app NOW, before any delay
        let frontApp = NSWorkspace.shared.frontmostApplication?.localizedName

        for file in contents where file.lowercased().hasSuffix(".png") {
            let fullPath = (dir as NSString).appendingPathComponent(file)
            if !knownFiles.contains(fullPath) {
                print("[ShotMaker] New file detected: \(file)")
                knownFiles.insert(fullPath)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                    self?.processNewFile(at: fullPath, appName: frontApp)
                }
            }
        }
    }

    // MARK: - File Processing

    func processNewFile(at path: String, appName: String? = nil) {
        guard path.lowercased().hasSuffix(".png") else { return }
        guard FileManager.default.fileExists(atPath: path) else { return }

        DispatchQueue.main.async { self.processingCount += 1 }

        processingQueue.async { [weak self] in
            guard let self = self else { return }

            let thumbnail = self.ocrService.generateThumbnail(at: path)

            self.ocrService.recognizeText(at: path) { [weak self] ocrText in
                guard let self = self else { return }

                let tag = self.taggerService.classify(text: ocrText)
                print("[ShotMaker] OCR result: \(ocrText?.prefix(80) ?? "nil") | tag: \(tag.rawValue)")

                let embeddingData: Data? = {
                    guard let text = ocrText,
                          let vec = EmbeddingService.shared.vector(for: text) else { return nil }
                    return EmbeddingService.encode(vec)
                }()

                do {
                    let _ = try self.storage.save(
                        filePath: path,
                        ocrText: ocrText,
                        tag: tag.rawValue,
                        appName: appName,
                        createdAt: Date(),
                        thumbnail: thumbnail,
                        embedding: embeddingData
                    )
                    DispatchQueue.main.async {
                        self.loadItems()
                        self.loadFilterCounts()
                        self.processingCount -= 1
                    }
                    self.sendNotification(tag: tag, ocrText: ocrText)
                } catch {
                    print("[ShotMaker] Failed to save screenshot: \(error)")
                    DispatchQueue.main.async { self.processingCount -= 1 }
                }
            }
        }
    }

    // MARK: - Data Loading

    func loadItems() {
        do {
            let all = try storage.fetchAll(limit: 500, offset: 0)
            DispatchQueue.main.async { self.items = all }
        } catch {
            print("[ShotMaker] Failed to load items: \(error)")
        }
    }

    func loadFilterCounts() {
        do {
            let tags = try storage.tagCounts()
            let apps = try storage.appCounts()
            DispatchQueue.main.async {
                self.tagCounts = tags
                self.appCounts = apps
            }
        } catch {
            print("[ShotMaker] Failed to load filter counts: \(error)")
        }
    }

    func search(query: String, tag: String? = nil, appName: String? = nil) {
        do {
            let results = try storage.searchWithFilters(query: query, tag: tag, appName: appName, limit: 100)
            DispatchQueue.main.async { self.items = results }
        } catch {
            print("[ShotMaker] Search failed: \(error)")
        }
    }

    /// Semantic search: rank all rows by cosine similarity to query embedding.
    /// Backfills missing embeddings for older rows lazily.
    func semanticSearch(query: String, tag: String? = nil, appName: String? = nil, limit: Int = 100) {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            search(query: "", tag: tag, appName: appName)
            return
        }
        guard let queryVec = EmbeddingService.shared.vector(for: trimmed) else {
            search(query: query, tag: tag, appName: appName)
            return
        }

        processingQueue.async { [weak self] in
            guard let self = self else { return }
            do {
                let rows = try self.storage.allEmbeddings()
                var scored: [(Int64, Float)] = []
                scored.reserveCapacity(rows.count)

                for row in rows {
                    let vec: [Float]
                    if let data = row.embedding {
                        vec = EmbeddingService.decode(data)
                    } else if let computed = EmbeddingService.shared.vector(for: row.ocrText) {
                        vec = computed
                        try? self.storage.updateEmbedding(id: row.id, embedding: EmbeddingService.encode(computed))
                    } else {
                        continue
                    }
                    scored.append((row.id, EmbeddingService.cosine(queryVec, vec)))
                }

                // Keep top matches with positive similarity
                scored.sort { $0.1 > $1.1 }
                let topIds = scored.prefix(limit).filter { $0.1 > 0.15 }.map { $0.0 }

                let items = try self.storage.fetchByIds(topIds)
                // Preserve ranking order
                let orderMap = Dictionary(uniqueKeysWithValues: topIds.enumerated().map { ($1, $0) })
                let ordered = items.sorted {
                    (orderMap[$0.id] ?? .max) < (orderMap[$1.id] ?? .max)
                }.filter { item in
                    (tag == nil || item.tag.rawValue == tag) &&
                    (appName == nil || item.appName == appName)
                }

                DispatchQueue.main.async { self.items = ordered }
            } catch {
                print("[ShotMaker] Semantic search failed: \(error)")
            }
        }
    }

    func retag(_ item: ScreenshotItem, tag: ScreenshotTag) {
        do {
            try storage.updateTag(id: item.id, tag: tag.rawValue)
            loadItems()
            loadFilterCounts()
        } catch {
            print("[ShotMaker] Failed to retag: \(error)")
        }
    }

    func delete(_ item: ScreenshotItem) {
        do {
            try storage.delete(id: item.id)
            loadItems()
            loadFilterCounts()
        } catch {
            print("[ShotMaker] Failed to delete: \(error)")
        }
    }
}
