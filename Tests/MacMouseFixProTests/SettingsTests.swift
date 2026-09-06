import XCTest
@testable import MacMouseFixPro

final class SettingsTests: XCTestCase {
    func testDefaultPhysicalButtonMapping() {
        let settings = MouseSettings()

        XCTAssertEqual(settings.logicalButton(forPhysicalButton: 2), 2)
        XCTAssertEqual(settings.logicalButton(forPhysicalButton: 3), 3)
        XCTAssertEqual(settings.logicalButton(forPhysicalButton: 4), 4)
        XCTAssertNil(settings.logicalButton(forPhysicalButton: 5))
    }

    func testChangingPhysicalButtonMapping() {
        var settings = MouseSettings()
        settings.setPhysicalButton(5, forLogicalButton: 3)
        settings.setPhysicalButton(6, forLogicalButton: 4)

        XCTAssertEqual(settings.logicalButton(forPhysicalButton: 5), 3)
        XCTAssertEqual(settings.logicalButton(forPhysicalButton: 6), 4)
        XCTAssertNil(settings.logicalButton(forPhysicalButton: 3))
        XCTAssertNil(settings.logicalButton(forPhysicalButton: 4))
    }

    func testDuplicatePhysicalButtonSelectionSwapsMappings() {
        var settings = MouseSettings()
        settings.setPhysicalButton(4, forLogicalButton: 3)

        XCTAssertEqual(settings.auxiliaryButton1PhysicalID, 4)
        XCTAssertEqual(settings.auxiliaryButton2PhysicalID, 3)
    }

    func testPhysicalButtonMappingSurvivesEncoding() throws {
        var settings = MouseSettings()
        settings.setPhysicalButton(8, forLogicalButton: 3)
        settings.setPhysicalButton(9, forLogicalButton: 4)
        settings.setAction(.copy, forButton: 3)

        let data = try JSONEncoder().encode(settings)
        let decoded = try JSONDecoder().decode(MouseSettings.self, from: data)

        XCTAssertEqual(decoded.auxiliaryButton1PhysicalID, 8)
        XCTAssertEqual(decoded.auxiliaryButton2PhysicalID, 9)
        XCTAssertEqual(decoded.action(forButton: 3), .copy)
        XCTAssertEqual(decoded.settingsVersion, MouseSettings.currentVersion)
    }

    func testLegacySettingsUseSafeDefaults() throws {
        let legacy = """
        {
          "settingsVersion": 2,
          "enabled": true,
          "buttonActions": {"2":"Mission Control","3":"Back","4":"Forward"}
        }
        """

        let decoded = try JSONDecoder().decode(MouseSettings.self, from: Data(legacy.utf8))

        XCTAssertEqual(decoded.auxiliaryButton1PhysicalID, 3)
        XCTAssertEqual(decoded.auxiliaryButton2PhysicalID, 4)
        XCTAssertFalse(decoded.pointerSmoothing)
    }
}
