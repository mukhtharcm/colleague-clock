import Foundation

final class BundledTimeZoneDatabase: @unchecked Sendable {
    static let shared = BundledTimeZoneDatabase()
    private static let resourceBundleName = "TimeZoneMenuBar_TimeZoneMenuBar.bundle"

    let version: String
    let allChoices: [TimeZoneChoice]

    private let aliasTargets: [String: String]
    private let choiceByIdentifier: [String: TimeZoneChoice]
    private let metadataByIdentifier: [String: TimeZoneMetadata]
    private let zoneInfoRootURL: URL

    private var timeZoneCache: [String: TimeZone] = [:]
    private let timeZoneCacheLock = NSLock()

    private init(bundle: Bundle = BundledTimeZoneDatabase.locateResourceBundle()) {
        guard let resourceURL = bundle.resourceURL else {
            fatalError("Missing bundle resources for bundled time zone data.")
        }

        let rootURL = resourceURL.appendingPathComponent("TZDB", isDirectory: true)
        let zoneInfoRootURL = rootURL.appendingPathComponent("zoneinfo", isDirectory: true)
        self.zoneInfoRootURL = zoneInfoRootURL

        version = Self.loadVersion(from: rootURL.appendingPathComponent("version.txt", isDirectory: false))

        let countryNamesByCode = Self.loadCountryNames(
            from: rootURL.appendingPathComponent("iso3166.tab", isDirectory: false)
        )

        let canonicalMetadata = Self.loadCanonicalMetadata(
            from: rootURL.appendingPathComponent("zone1970.tab", isDirectory: false),
            countryNamesByCode: countryNamesByCode
        )

        aliasTargets = Self.loadAliasTargets(
            from: rootURL.appendingPathComponent("backward", isDirectory: false)
        )

        metadataByIdentifier = Self.makeMetadataLookup(
            canonicalMetadata: canonicalMetadata,
            aliasTargets: aliasTargets
        )

        let choices: [TimeZoneChoice] = canonicalMetadata.values.compactMap { metadata -> TimeZoneChoice? in
            guard let timeZone = Self.loadBundledTimeZone(
                named: metadata.canonicalIdentifier,
                zoneInfoRootURL: zoneInfoRootURL
            ) else {
                return nil
            }

            return TimeZoneChoice(
                identifier: metadata.canonicalIdentifier,
                metadata: metadata,
                timeZone: timeZone
            )
        }
        .sorted { left, right in
            if left.cityName == right.cityName {
                return left.identifier < right.identifier
            }
            return left.cityName < right.cityName
        }

        allChoices = choices
        choiceByIdentifier = Dictionary(uniqueKeysWithValues: choices.map { ($0.identifier, $0) })
    }

    func canonicalIdentifier(for identifier: String) -> String {
        var currentIdentifier = identifier
        var visitedIdentifiers = Set<String>()

        while let nextIdentifier = aliasTargets[currentIdentifier],
              !visitedIdentifiers.contains(currentIdentifier) {
            visitedIdentifiers.insert(currentIdentifier)
            currentIdentifier = nextIdentifier
        }

        return currentIdentifier
    }

    func choice(for identifier: String) -> TimeZoneChoice? {
        choiceByIdentifier[canonicalIdentifier(for: identifier)]
    }

    func metadata(for identifier: String) -> TimeZoneMetadata? {
        metadataByIdentifier[identifier] ?? metadataByIdentifier[canonicalIdentifier(for: identifier)]
    }

    func timeZone(for identifier: String) -> TimeZone? {
        let resolvedIdentifier = canonicalIdentifier(for: identifier)

        timeZoneCacheLock.lock()
        if let cachedTimeZone = timeZoneCache[resolvedIdentifier] {
            timeZoneCacheLock.unlock()
            return cachedTimeZone
        }
        timeZoneCacheLock.unlock()

        guard let loadedTimeZone = Self.loadBundledTimeZone(
            named: resolvedIdentifier,
            zoneInfoRootURL: zoneInfoRootURL
        ) else {
            return TimeZone(identifier: resolvedIdentifier) ?? TimeZone(identifier: identifier)
        }

        timeZoneCacheLock.lock()
        timeZoneCache[resolvedIdentifier] = loadedTimeZone
        timeZoneCacheLock.unlock()

        return loadedTimeZone
    }

    private static func loadVersion(from fileURL: URL) -> String {
        guard let version = try? String(contentsOf: fileURL, encoding: .utf8) else {
            return "unknown"
        }

        return version.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func locateResourceBundle() -> Bundle {
        let mainBundleCandidates = [
            Bundle.main.resourceURL?.appendingPathComponent(resourceBundleName, isDirectory: true),
            Bundle.main.bundleURL.appendingPathComponent(resourceBundleName, isDirectory: true)
        ]

        for candidate in mainBundleCandidates.compactMap({ $0 }) {
            if let bundle = Bundle(url: candidate) {
                return bundle
            }
        }

        return .module
    }

    private static func loadCountryNames(from fileURL: URL) -> [String: String] {
        guard let contents = try? String(contentsOf: fileURL, encoding: .utf8) else {
            return [:]
        }

        return contents
            .split(whereSeparator: \.isNewline)
            .reduce(into: [String: String]()) { result, line in
                guard !line.hasPrefix("#") else {
                    return
                }

                let parts = line.split(separator: "\t", omittingEmptySubsequences: false)
                guard parts.count >= 2 else {
                    return
                }

                result[String(parts[0])] = String(parts[1])
            }
    }

    private static func loadCanonicalMetadata(
        from fileURL: URL,
        countryNamesByCode: [String: String]
    ) -> [String: TimeZoneMetadata] {
        guard let contents = try? String(contentsOf: fileURL, encoding: .utf8) else {
            return [:]
        }

        return contents
            .split(whereSeparator: \.isNewline)
            .reduce(into: [String: TimeZoneMetadata]()) { result, line in
                guard !line.hasPrefix("#") else {
                    return
                }

                let parts = line.split(separator: "\t", omittingEmptySubsequences: false)
                guard parts.count >= 3 else {
                    return
                }

                let countryCodes = String(parts[0])
                    .split(separator: ",")
                    .map(String.init)

                let countryNames = countryCodes.map { countryNamesByCode[$0] ?? $0 }
                let identifier = String(parts[2])
                let comment = parts.count > 3 ? String(parts[3]) : nil

                result[identifier] = TimeZoneMetadata(
                    countryCodes: countryCodes,
                    countryNames: countryNames,
                    comment: comment?.isEmpty == true ? nil : comment,
                    canonicalIdentifier: identifier,
                    aliasIdentifiers: []
                )
            }
    }

    private static func loadAliasTargets(from fileURL: URL) -> [String: String] {
        guard let contents = try? String(contentsOf: fileURL, encoding: .utf8) else {
            return [:]
        }

        return contents
            .split(whereSeparator: \.isNewline)
            .reduce(into: [String: String]()) { result, line in
                let trimmedLine = line.trimmingCharacters(in: .whitespaces)
                guard !trimmedLine.isEmpty, !trimmedLine.hasPrefix("#") else {
                    return
                }

                let parts = trimmedLine.split(whereSeparator: \.isWhitespace)
                guard parts.count >= 3, parts[0] == "Link" else {
                    return
                }

                result[String(parts[2])] = String(parts[1])
            }
    }

    private static func makeMetadataLookup(
        canonicalMetadata: [String: TimeZoneMetadata],
        aliasTargets: [String: String]
    ) -> [String: TimeZoneMetadata] {
        func resolveCanonicalIdentifier(for identifier: String) -> String {
            var currentIdentifier = identifier
            var visitedIdentifiers = Set<String>()

            while let nextIdentifier = aliasTargets[currentIdentifier],
                  !visitedIdentifiers.contains(currentIdentifier) {
                visitedIdentifiers.insert(currentIdentifier)
                currentIdentifier = nextIdentifier
            }

            return currentIdentifier
        }

        let aliasesByCanonicalIdentifier = aliasTargets.keys.reduce(into: [String: [String]]()) { result, alias in
            let canonicalIdentifier = resolveCanonicalIdentifier(for: alias)
            guard canonicalMetadata[canonicalIdentifier] != nil else {
                return
            }

            result[canonicalIdentifier, default: []].append(alias)
        }

        return canonicalMetadata.reduce(into: [String: TimeZoneMetadata]()) { result, item in
            let aliases = aliasesByCanonicalIdentifier[item.key, default: []].sorted()
            let enrichedMetadata = TimeZoneMetadata(
                countryCodes: item.value.countryCodes,
                countryNames: item.value.countryNames,
                comment: item.value.comment,
                canonicalIdentifier: item.value.canonicalIdentifier,
                aliasIdentifiers: aliases
            )

            result[item.key] = enrichedMetadata

            for alias in aliases {
                result[alias] = enrichedMetadata
            }
        }
    }

    private static func loadBundledTimeZone(
        named identifier: String,
        zoneInfoRootURL: URL
    ) -> TimeZone? {
        let zoneFileURL = zoneFileURL(for: identifier, zoneInfoRootURL: zoneInfoRootURL)

        guard let data = try? Data(contentsOf: zoneFileURL),
              let timeZone = NSTimeZone(name: identifier, data: data) else {
            return nil
        }

        return timeZone as TimeZone
    }

    private static func zoneFileURL(for identifier: String, zoneInfoRootURL: URL) -> URL {
        let parts = identifier.split(separator: "/").map(String.init)

        return parts.enumerated().reduce(zoneInfoRootURL) { currentURL, item in
            currentURL.appendingPathComponent(
                item.element,
                isDirectory: item.offset < parts.count - 1
            )
        }
    }
}
