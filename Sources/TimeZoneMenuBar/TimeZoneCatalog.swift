import Foundation

struct TimeZoneChoice: Identifiable, Hashable {
    let identifier: String
    let cityName: String
    let regionName: String
    let countryCodes: [String]
    let countryNames: [String]
    let comment: String?
    let aliasIdentifiers: [String]
    let localizedName: String
    let abbreviation: String
    let gmtOffsetText: String

    var id: String { identifier }

    var countrySummary: String? {
        guard !countryNames.isEmpty else {
            return nil
        }

        return countryNames.joined(separator: ", ")
    }

    var primaryCountryName: String? {
        countryNames.first
    }

    var subtitle: String {
        [
            primaryCountryName,
            comment ?? (regionName.isEmpty ? nil : regionName),
            abbreviation,
            gmtOffsetText
        ]
        .compactMap { $0 }
        .joined(separator: " • ")
    }

    var searchableText: String {
        (
            [
                identifier,
                cityName,
                regionName,
                comment,
                localizedName,
                abbreviation,
                gmtOffsetText
            ]
            .compactMap { $0 }
            + countryCodes
            + countryNames
            + aliasIdentifiers
        )
        .joined(separator: " ")
    }

    init(identifier: String, metadata: TimeZoneMetadata, timeZone: TimeZone) {
        let parts = metadata.canonicalIdentifier.split(separator: "/").map(String.init)

        self.identifier = identifier
        self.cityName = parts.last?.replacingOccurrences(of: "_", with: " ") ?? identifier
        self.regionName = parts.dropLast().joined(separator: " / ")
        self.countryCodes = metadata.countryCodes
        self.countryNames = metadata.countryNames
        self.comment = metadata.comment
        self.aliasIdentifiers = metadata.aliasIdentifiers
        self.localizedName = timeZone.localizedName(for: .standard, locale: .current) ?? identifier
        self.abbreviation = timeZone.abbreviation(for: .now) ?? "UTC"
        self.gmtOffsetText = Self.gmtOffsetText(for: timeZone, at: .now)
    }

    private static func gmtOffsetText(for timeZone: TimeZone, at date: Date) -> String {
        let totalSeconds = timeZone.secondsFromGMT(for: date)
        let sign = totalSeconds >= 0 ? "+" : "-"
        let absoluteSeconds = abs(totalSeconds)
        let hours = absoluteSeconds / 3_600
        let minutes = (absoluteSeconds % 3_600) / 60
        return String(format: "GMT%@%02d:%02d", sign, hours, minutes)
    }
}

struct TimeZoneMetadata: Hashable {
    let countryCodes: [String]
    let countryNames: [String]
    let comment: String?
    let canonicalIdentifier: String
    let aliasIdentifiers: [String]

    var primaryCountryName: String? {
        countryNames.first
    }

    var countrySummary: String? {
        guard !countryNames.isEmpty else {
            return nil
        }

        return countryNames.joined(separator: ", ")
    }
}

enum TimeZoneCatalog {
    static let allChoices: [TimeZoneChoice] = BundledTimeZoneDatabase.shared.allChoices

    static var dataVersion: String {
        BundledTimeZoneDatabase.shared.version
    }

    static func choice(for identifier: String) -> TimeZoneChoice? {
        BundledTimeZoneDatabase.shared.choice(for: identifier)
    }

    static func metadata(for identifier: String) -> TimeZoneMetadata? {
        BundledTimeZoneDatabase.shared.metadata(for: identifier)
    }

    static func timeZone(for identifier: String) -> TimeZone? {
        BundledTimeZoneDatabase.shared.timeZone(for: identifier)
    }

    static func canonicalIdentifier(for identifier: String) -> String {
        BundledTimeZoneDatabase.shared.canonicalIdentifier(for: identifier)
    }

    static func search(matching rawQuery: String) -> [TimeZoneChoice] {
        let query = rawQuery.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !query.isEmpty else {
            return allChoices
        }

        return allChoices
            .filter { $0.searchableText.localizedCaseInsensitiveContains(query) }
            .sorted { left, right in
                matchRank(for: query, in: left) < matchRank(for: query, in: right)
            }
    }

    private static func matchRank(for query: String, in choice: TimeZoneChoice) -> Int {
        let loweredQuery = query.lowercased()

        if choice.countryNames.contains(where: { $0.lowercased() == loweredQuery })
            || choice.countryCodes.contains(where: { $0.lowercased() == loweredQuery }) {
            return 0
        }

        if choice.cityName.lowercased() == loweredQuery
            || choice.identifier.lowercased() == loweredQuery
            || choice.aliasIdentifiers.contains(where: { $0.lowercased() == loweredQuery }) {
            return 1
        }

        if choice.countryNames.contains(where: { $0.lowercased().hasPrefix(loweredQuery) }) {
            return 2
        }

        if choice.cityName.lowercased().hasPrefix(loweredQuery) {
            return 3
        }

        if choice.identifier.lowercased().hasPrefix(loweredQuery)
            || choice.aliasIdentifiers.contains(where: { $0.lowercased().hasPrefix(loweredQuery) }) {
            return 4
        }

        if choice.comment?.lowercased().contains(loweredQuery) == true {
            return 5
        }

        if choice.localizedName.lowercased().contains(loweredQuery) {
            return 6
        }

        if choice.regionName.lowercased().contains(loweredQuery) {
            return 7
        }

        return 8
    }
}
