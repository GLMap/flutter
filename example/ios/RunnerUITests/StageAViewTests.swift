import XCTest

final class StageAViewTests: XCTestCase {
    private let app = XCUIApplication()

    override func setUpWithError() throws {
        continueAfterFailure = true
        XCUIDevice.shared.orientation = .portrait
        app.launch()
        XCTAssertTrue(app.buttons["Read state"].waitForExistence(timeout: 20))
    }

    private func readState() -> String {
        // Single tap waits for the map's double-tap recognizer to fail.
        Thread.sleep(forTimeInterval: 0.5)
        app.buttons["Read state"].tap()
        let state = app.descendants(matching: .any)["native-state"]
        XCTAssertTrue(state.waitForExistence(timeout: 5))
        let value = state.label
        print("GLMapLabTest: \(value)")
        return value
    }

    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testNativeGestures() throws {
        let canvas = app.otherElements["GLMap canvas"]
        XCTAssertTrue(canvas.waitForExistence(timeout: 10))
        XCTAssertTrue(readState().contains("zoom 5.00"))
        capture("A01-initial-map")

        canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        XCTAssertTrue(readState().contains("taps 1"))
        let beforePan = readState()
        canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.6))
            .press(forDuration: 0.1, thenDragTo: canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.7, dy: 0.6)))
        XCTAssertNotEqual(readState(), beforePan)

        // XCUITest chooses the two-finger trajectory. Remove the overlay so neither
        // synthesized finger lands on the Flutter text field instead of the map.
        app.buttons["Toggle overlay"].tap()
        // Scale 4 stayed below the native pitch recognizer's 30 pt movement
        // decision threshold in the RN experiment. Exercise a longer path here.
        canvas.pinch(withScale: 8, velocity: 1)
        app.buttons["Toggle overlay"].tap()
        let pinched = readState()
        XCTAssertFalse(pinched.contains("zoom 5.00"))
        capture("A03-after-pinch")
        app.buttons["Toggle overlay"].tap()
        canvas.rotate(.pi / 4, withVelocity: 1)
        app.buttons["Toggle overlay"].tap()
        let transformed = readState()
        XCTAssertFalse(transformed.contains("angle 0.0"))
        capture("A03-after-native-gestures")
    }

    func testKeyboardAndRotation() throws {
        let field = app.textFields.firstMatch
        field.tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5))
        field.typeText("Native keyboard")
        capture("A04-keyboard-overlay")
        app.buttons["Reset"].tap()
        XCTAssertTrue(readState().contains("zoom 5.00"))

        XCUIDevice.shared.orientation = .landscapeLeft
        XCTAssertTrue(app.buttons["Read state"].waitForExistence(timeout: 5))
        capture("A08-landscape")
        XCUIDevice.shared.orientation = .portrait
    }

    func testBackgroundResume() throws {
        let canvas = app.otherElements["GLMap canvas"]
        XCTAssertTrue(canvas.waitForExistence(timeout: 10))
        for cycle in 1...5 {
            XCUIDevice.shared.press(.home)
            let pause = expectation(description: "Background dwell \(cycle)")
            DispatchQueue.main.asyncAfter(deadline: .now() + 30) { pause.fulfill() }
            wait(for: [pause], timeout: 35)
            app.activate()
            XCTAssertTrue(app.buttons["Read state"].waitForExistence(timeout: 10))
            XCTAssertTrue(readState().contains("zoom 5.00"))
            canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
            XCTAssertTrue(readState().contains("taps \(cycle)"))
            capture("A07-resume-\(cycle)")
        }
    }
}
