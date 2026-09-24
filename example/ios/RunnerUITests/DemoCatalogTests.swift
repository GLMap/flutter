import XCTest

final class DemoCatalogTests: XCTestCase {
    let app = XCUIApplication()
    override func setUpWithError() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        app.launch()
        XCTAssertTrue(app.textFields.firstMatch.waitForExistence(timeout: 25))
    }
    func open(_ title: String) {
        let filter = app.textFields.firstMatch
        filter.tap(); filter.typeText(title)
        let entry = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", title)).firstMatch
        XCTAssertTrue(entry.waitForExistence(timeout: 5), app.debugDescription)
        entry.tap()
        XCTAssertTrue(app.otherElements["GLMap canvas"].waitForExistence(timeout: 10))
    }
    func textAppears(_ text: String) {
        let label = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", text)).firstMatch
        XCTAssertTrue(label.waitForExistence(timeout: 10), app.debugDescription)
    }
    func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
    func testNativeTapAndLongPress() {
        open("Image Group")
        textAppears("5 pins share one image")
        let point = app.otherElements["GLMap canvas"].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.4))
        point.press(forDuration: 1)
        textAppears("6 pins share one image")
        point.tap()
        textAppears("5 pins share one image")
        capture("demo-native-image-group")
    }
    func testForegroundLocation() {
        addUIInterruptionMonitor(withDescription: "Location permission") { alert in
            let allow = alert.buttons["Allow While Using App"]
            if allow.exists { allow.tap(); return true }
            let once = alert.buttons["Allow Once"]
            if once.exists { once.tap(); return true }
            return false
        }
        open("User Location")
        app.buttons["Use GPS"].tap()
        app.tap()
        textAppears("42.43410, 19.26000")
        capture("demo-foreground-location")
        app.buttons["Stop"].tap()
        textAppears("Location updates stopped")
    }
}
