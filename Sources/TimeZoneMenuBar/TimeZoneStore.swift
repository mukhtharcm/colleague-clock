import Combine
import Foundation

@MainActor
final class TimeZoneStore: ObservableObject {
    @Published private(set) var entries: [ClockEntry] = []

    private let fileManager: FileManager
    private let storageURL: URL
    private let defaults: UserDefaults
    private let legacyStorageKey = "savedClockEntries"
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(
        fileManager: FileManager = .default,
        defaults: UserDefaults = .standard,
        storageURL: URL? = nil
    ) {
        self.fileManager = fileManager
        self.defaults = defaults
        self.storageURL = storageURL ?? Self.defaultStorageURL(fileManager: fileManager)
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        load()
    }

    func save(name: String, timeZoneIdentifier: String, editing existingEntry: ClockEntry?) {
        let normalizedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedTimeZoneIdentifier = TimeZoneCatalog.canonicalIdentifier(for: timeZoneIdentifier)

        guard !normalizedName.isEmpty else {
            return
        }

        if let existingEntry,
           let index = entries.firstIndex(where: { $0.id == existingEntry.id }) {
            entries[index].name = normalizedName
            entries[index].timeZoneIdentifier = normalizedTimeZoneIdentifier
        } else {
            entries.append(
                ClockEntry(
                    name: normalizedName,
                    timeZoneIdentifier: normalizedTimeZoneIdentifier
                )
            )
        }

        persist()
    }

    func delete(_ entry: ClockEntry) {
        entries.removeAll { $0.id == entry.id }
        persist()
    }

    func moveEntries(fromOffsets offsets: IndexSet, toOffset destination: Int) {
        guard !offsets.isEmpty else {
            return
        }

        entries.move(fromOffsets: offsets, toOffset: destination)
        persist()
    }

    private func load() {
        if let data = try? Data(contentsOf: storageURL) {
            if decodeEntries(from: data) {
                persist()
            }
            return
        }

        guard let legacyData = defaults.data(forKey: legacyStorageKey) else {
            entries = []
            return
        }

        _ = decodeEntries(from: legacyData)

        if !entries.isEmpty {
            persist()
            defaults.removeObject(forKey: legacyStorageKey)
        }
    }

    private func persist() {
        do {
            let directoryURL = storageURL.deletingLastPathComponent()
            try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
            let data = try encoder.encode(entries)
            try data.write(to: storageURL, options: .atomic)
        } catch {
            assertionFailure("Failed to persist time zone entries: \(error)")
        }
    }

    private func decodeEntries(from data: Data) -> Bool {
        do {
            entries = try decoder.decode([ClockEntry].self, from: data)
            return normalizeEntries()
        } catch {
            entries = []
            return false
        }
    }

    private func normalizeEntries() -> Bool {
        var didNormalize = false

        entries = entries.map { entry in
            let canonicalIdentifier = TimeZoneCatalog.canonicalIdentifier(for: entry.timeZoneIdentifier)
            guard canonicalIdentifier != entry.timeZoneIdentifier else {
                return entry
            }

            didNormalize = true

            return ClockEntry(
                id: entry.id,
                name: entry.name,
                timeZoneIdentifier: canonicalIdentifier
            )
        }

        return didNormalize
    }

    private static func defaultStorageURL(fileManager: FileManager) -> URL {
        let baseURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.homeDirectoryForCurrentUser
                .appendingPathComponent("Library", isDirectory: true)
                .appendingPathComponent("Application Support", isDirectory: true)

        return baseURL
            .appendingPathComponent("ColleagueClock", isDirectory: true)
            .appendingPathComponent("clock-entries.json", isDirectory: false)
    }
}
