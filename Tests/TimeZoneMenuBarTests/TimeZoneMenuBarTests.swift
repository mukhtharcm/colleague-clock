import XCTest
@testable import TimeZoneMenuBar

final class TimeZoneMenuBarTests: XCTestCase {
    func testBundledTimeZoneDataVersionIsPresent() {
        XCTAssertFalse(TimeZoneCatalog.dataVersion.isEmpty)
        XCTAssertNotEqual(TimeZoneCatalog.dataVersion, "unknown")
    }

    func testCountrySearchReturnsZonesForIndia() {
        let results = TimeZoneCatalog.search(matching: "India")
        XCTAssertTrue(results.contains { $0.countryNames.contains("India") })
        XCTAssertTrue(results.contains { $0.identifier == "Asia/Kolkata" })
    }

    func testCountrySearchReturnsMultipleUnitedStatesZones() {
        let results = TimeZoneCatalog.search(matching: "United States")
        XCTAssertTrue(results.contains { $0.identifier == "America/New_York" })
        XCTAssertTrue(results.contains { $0.identifier == "America/Los_Angeles" })
    }

    func testLegacyAliasCanonicalizesToBundledZone() {
        XCTAssertEqual(
            TimeZoneCatalog.canonicalIdentifier(for: "Asia/Calcutta"),
            "Asia/Kolkata"
        )
    }

    @MainActor
    func testStorePersistsEntriesToDisk() throws {
        let fileManager = FileManager.default
        let rootURL = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let storageURL = rootURL.appendingPathComponent("clock-entries.json", isDirectory: false)
        let suiteName = "TimeZoneMenuBarTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))

        defer {
            defaults.removePersistentDomain(forName: suiteName)
            try? fileManager.removeItem(at: rootURL)
        }

        let store = TimeZoneStore(fileManager: fileManager, defaults: defaults, storageURL: storageURL)
        store.save(name: "Asha", timeZoneIdentifier: "Asia/Kolkata", editing: nil)

        let reloadedStore = TimeZoneStore(fileManager: fileManager, defaults: defaults, storageURL: storageURL)
        XCTAssertEqual(reloadedStore.entries.count, 1)
        XCTAssertEqual(reloadedStore.entries.first?.name, "Asha")
        XCTAssertEqual(reloadedStore.entries.first?.timeZoneIdentifier, "Asia/Kolkata")
    }

    @MainActor
    func testStorePersistsManualReorderToDisk() throws {
        let fileManager = FileManager.default
        let rootURL = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let storageURL = rootURL.appendingPathComponent("clock-entries.json", isDirectory: false)
        let suiteName = "TimeZoneMenuBarTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))

        defer {
            defaults.removePersistentDomain(forName: suiteName)
            try? fileManager.removeItem(at: rootURL)
        }

        let store = TimeZoneStore(fileManager: fileManager, defaults: defaults, storageURL: storageURL)
        store.save(name: "Asha", timeZoneIdentifier: "Asia/Kolkata", editing: nil)
        store.save(name: "Mina", timeZoneIdentifier: "Europe/London", editing: nil)
        store.save(name: "Jon", timeZoneIdentifier: "America/New_York", editing: nil)

        let movedEntryID = try XCTUnwrap(store.entries.last?.id)
        let targetEntryID = try XCTUnwrap(store.entries.first?.id)
        store.moveEntry(withID: movedEntryID, over: targetEntryID)

        let reloadedStore = TimeZoneStore(fileManager: fileManager, defaults: defaults, storageURL: storageURL)
        XCTAssertEqual(reloadedStore.entries.map(\.name), ["Jon", "Asha", "Mina"])
    }
}
