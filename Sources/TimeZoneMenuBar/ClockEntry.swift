import Foundation

struct ClockEntry: Codable, Identifiable, Equatable {
    let id: UUID
    var name: String
    var timeZoneIdentifier: String

    init(id: UUID = UUID(), name: String, timeZoneIdentifier: String) {
        self.id = id
        self.name = name
        self.timeZoneIdentifier = timeZoneIdentifier
    }

    var timeZone: TimeZone {
        TimeZoneCatalog.timeZone(for: timeZoneIdentifier) ?? .current
    }

    private var displayIdentifier: String {
        TimeZoneCatalog.canonicalIdentifier(for: timeZoneIdentifier)
    }

    var cityName: String {
        let parts = displayIdentifier.split(separator: "/").map(String.init)
        return parts.last?.replacingOccurrences(of: "_", with: " ") ?? displayIdentifier
    }

    var regionName: String {
        let parts = displayIdentifier.split(separator: "/").map(String.init)
        return parts.dropLast().joined(separator: " / ")
    }

    func timeLabel(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        formatter.timeZone = timeZone
        return formatter.string(from: date)
    }

    func dateLabel(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeZone = timeZone
        formatter.setLocalizedDateFormatFromTemplate("EEE MMM d")
        return formatter.string(from: date)
    }

    func zoneLabel(for date: Date, compact: Bool = false) -> String {
        let abbreviation = timeZone.abbreviation(for: date) ?? "UTC"

        let components: [String?]
        if let metadata = TimeZoneCatalog.metadata(for: timeZoneIdentifier) {
            if compact {
                components = [
                    metadata.comment ?? cityName,
                    abbreviation
                ]
            } else {
                components = [
                    metadata.primaryCountryName,
                    metadata.comment ?? cityName,
                    abbreviation
                ]
            }
        } else {
            components = [
                cityName,
                regionName.isEmpty ? nil : regionName,
                abbreviation
            ]
        }

        return components.compactMap { $0 }.joined(separator: " • ")
    }
}
