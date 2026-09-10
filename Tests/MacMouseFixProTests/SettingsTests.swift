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
        settings.setScrollGestureAction(.nextApp, forButton: 3, direction: .down)

        let data = try JSONEncoder().encode(settings)
        let decoded = try JSONDecoder().decode(MouseSettings.self, from: data)

        XCTAssertEqual(decoded.auxiliaryButton1PhysicalID, 8)
        XCTAssertEqual(decoded.auxiliaryButton2PhysicalID, 9)
        XCTAssertEqual(decoded.action(forButton: 3), .copy)
        XCTAssertEqual(decoded.scrollGestureAction(forButton: 3, direction: .down), .nextApp)
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
        XCTAssertEqual(decoded.scrollGestureAction(forButton: 3, direction: .up), .volumeUp)
        XCTAssertEqual(decoded.scrollGestureAction(forButton: 4, direction: .down), .zoomOut)
        XCTAssertEqual(decoded.language, .simplifiedChinese)
    }

    func testVersionThreePreservesPointerSmoothing() throws {
        let versionThree = """
        {
          "settingsVersion": 3,
          "pointerSmoothing": true
        }
        """

        let decoded = try JSONDecoder().decode(MouseSettings.self, from: Data(versionThree.utf8))
        XCTAssertTrue(decoded.pointerSmoothing)
    }

    func testPassingBothGestureDirectionsDisablesGestureCapture() {
        var settings = MouseSettings()
        settings.setScrollGestureAction(.passThrough, forButton: 3, direction: .up)
        settings.setScrollGestureAction(.passThrough, forButton: 3, direction: .down)

        XCTAssertFalse(settings.hasScrollGesture(forButton: 3))
    }

    func testSideButtonGestureSuppressesClickAfterScroll() {
        var tracker = SideButtonGestureTracker()
        XCTAssertTrue(tracker.press(
            physicalButton: 5,
            logicalButton: 3,
            clickAction: .back,
            hasScrollGesture: true
        ))

        XCTAssertEqual(tracker.activeButton?.logicalButton, 3)
        XCTAssertEqual(tracker.markActiveScrollGestureUsed()?.usedScrollGesture, true)
        XCTAssertEqual(tracker.release(physicalButton: 5)?.usedScrollGesture, true)
        XCTAssertNil(tracker.activeButton)
    }

    func testSideButtonClickRemainsWhenNoScrollOccurs() {
        var tracker = SideButtonGestureTracker()
        XCTAssertTrue(tracker.press(
            physicalButton: 4,
            logicalButton: 4,
            clickAction: .forward,
            hasScrollGesture: true
        ))

        let released = tracker.release(physicalButton: 4)
        XCTAssertEqual(released?.clickAction, .forward)
        XCTAssertEqual(released?.usedScrollGesture, false)
    }

    func testMagnificationGestureHasCompleteLifecycle() {
        var samples: [MagnificationGestureSimulator.Sample] = []
        let simulator = MagnificationGestureSimulator { samples.append($0) }

        XCTAssertTrue(simulator.update(action: .zoomIn, wheelDelta: 1, button: 4))
        XCTAssertTrue(simulator.update(action: .zoomOut, wheelDelta: -2, button: 4))
        simulator.end(for: 4)

        XCTAssertEqual(samples.map(\.phase), [.began, .changed, .changed, .changed, .ended])
        XCTAssertEqual(samples[2].magnification, 0.055, accuracy: 0.0001)
        XCTAssertEqual(samples[3].magnification, -0.11, accuracy: 0.0001)
        XCTAssertNil(simulator.activeButton)
    }

    func testMagnificationGestureIgnoresWrongButtonEnd() {
        var samples: [MagnificationGestureSimulator.Sample] = []
        let simulator = MagnificationGestureSimulator { samples.append($0) }

        simulator.update(action: .zoomIn, wheelDelta: 1, button: 4)
        simulator.end(for: 3)

        XCTAssertEqual(simulator.activeButton, 4)
        XCTAssertFalse(samples.contains { $0.phase == .ended })
    }

    func testMagnificationPulseIsSelfContained() {
        var samples: [MagnificationGestureSimulator.Sample] = []
        let simulator = MagnificationGestureSimulator { samples.append($0) }

        simulator.pulse(action: .zoomOut)

        XCTAssertEqual(samples.map(\.phase), [.began, .changed, .changed, .ended])
        XCTAssertLessThan(samples[2].magnification, 0)
        XCTAssertNil(simulator.activeButton)
    }

    func testLanguageSelectionSurvivesEncoding() throws {
        var settings = MouseSettings()
        settings.language = .english

        let data = try JSONEncoder().encode(settings)
        let decoded = try JSONDecoder().decode(MouseSettings.self, from: data)

        XCTAssertEqual(decoded.language, .english)
        XCTAssertEqual(decoded.settingsVersion, MouseSettings.currentVersion)
    }

    func testEnglishActionAndButtonNames() {
        XCTAssertEqual(MouseAction.zoomIn.menuTitle(for: .english), "Pinch to Zoom In")
        XCTAssertEqual(MouseAction.volumeDown.menuTitle(for: .english), "Volume Down")
        XCTAssertEqual(
            MouseSettings.displayName(forCGButton: 4, language: .english),
            "Auxiliary Button 2"
        )
        XCTAssertEqual(ScrollGestureDirection.up.menuTitle(for: .english), "Wheel Up")
    }
}
