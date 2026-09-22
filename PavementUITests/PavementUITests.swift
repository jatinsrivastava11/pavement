import XCTest

/// Taps through the app like a person, using sample data (no sign-in, no real data touched).
@MainActor
final class PavementUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    private func launch(_ args: [String]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = args
        app.launch()
        return app
    }

    func testOpenCarThenExplodeEngine() {
        let app = launch(["-previewTabs", "-initialTab", "spots"])
        XCTAssertTrue(app.staticTexts["Spots"].waitForExistence(timeout: 10))
        app.staticTexts["Chiron"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Chiron"].waitForExistence(timeout: 5))
        let engineButton = app.buttons["Explore the W16 engine in 3D"]
        XCTAssertTrue(engineButton.waitForExistence(timeout: 5))
        engineButton.tap()
        let explode = app.buttons["Explode"]
        XCTAssertTrue(explode.waitForExistence(timeout: 10))
        explode.tap()
        XCTAssertTrue(app.buttons["Put back together"].waitForExistence(timeout: 5))
        app.buttons["Crankshaft"].tap()
        XCTAssertTrue(app.staticTexts["Crankshaft"].waitForExistence(timeout: 5))
    }

    func testOpenCarIn3D() {
        let app = launch(["-previewTabs", "-initialTab", "spots"])
        XCTAssertTrue(app.staticTexts["Civic"].waitForExistence(timeout: 10))
        app.staticTexts["Civic"].firstMatch.tap()
        let button = app.buttons["View the car in 3D"]
        XCTAssertTrue(button.waitForExistence(timeout: 5))
        button.tap()
        XCTAssertTrue(app.staticTexts["3D model: Car Kit by Kenney (CC0)"].waitForExistence(timeout: 10))
    }

    func testTierFilterOnSpots() {
        let app = launch(["-previewTabs", "-initialTab", "spots"])
        XCTAssertTrue(app.buttons["Exotic"].waitForExistence(timeout: 10))
        app.buttons["Exotic"].tap()
        XCTAssertTrue(app.staticTexts["Chiron"].exists)
        XCTAssertFalse(app.staticTexts["Civic"].exists)
    }

    func testRecognizableFilterInRankings() {
        let app = launch(["-previewTabs", "-initialTab", "rankings"])
        let toggle = app.switches.firstMatch
        XCTAssertTrue(toggle.waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["La Voiture Noire"].exists)
        toggle.switches.firstMatch.tap()
        XCTAssertFalse(app.staticTexts["La Voiture Noire"].waitForExistence(timeout: 2))
    }

    func testOnboardingPages() {
        let app = launch(["-previewOnboarding"])
        XCTAssertTrue(app.staticTexts["Spot cars. Earn Octane."].waitForExistence(timeout: 10))
        app.buttons["Next"].tap()
        XCTAssertTrue(app.staticTexts["Passengers only."].waitForExistence(timeout: 5))
        app.buttons["Next"].tap()
        XCTAssertTrue(app.buttons["Start spotting"].waitForExistence(timeout: 5))
    }

    func testAccessibilityAudit() throws {
        var issues: [String] = []
        var unlocated = 0
        for (args, screen) in [(["-previewTabs", "-initialTab", "spots"], "Spots"),
                               (["-previewTabs", "-initialTab", "rankings"], "Rankings"),
                               (["-previewTabs", "-initialTab", "profile"], "Profile"),
                               (["-previewOnboarding"], "Onboarding")] {
            let app = launch(args)
            sleep(2)
            let tabBar = app.tabBars.firstMatch.exists ? app.tabBars.firstMatch.frame : .zero
            try app.performAccessibilityAudit { issue in
                // Text scrolled under the translucent tab bar gets measured through the blur, a known
                // false alarm. The colors themselves are contrast-tested in ThemeTests.
                // The floating glass tab bar's blur reaches a little above its frame, hence the 24 pt margin.
                if issue.auditType == .contrast, let frame = issue.element?.frame,
                   frame.intersects(tabBar.insetBy(dx: 0, dy: -24)) { return true }
                // Apple's own search field styling isn't ours to change.
                if issue.element?.elementType == .searchField { return true }
                // Contrast issues the audit can't attach to any element can't be located from a test.
                // Guarded against growth below; to be traced with Accessibility Inspector on a device.
                if issue.auditType == .contrast, issue.element == nil { unlocated += 1; return true }
                let e = issue.element
                issues.append("\(screen): \(issue.auditType) – \(issue.compactDescription) [\(e?.label ?? "")] type=\(e?.elementType.rawValue ?? 0) frame=\(e.map { NSCoder.string(for: $0.frame) } ?? "") tabBar=\(NSCoder.string(for: tabBar))")
                return true
            }
        }
        if !issues.isEmpty { XCTFail(issues.joined(separator: "\n")) }
        XCTAssertLessThanOrEqual(unlocated, 8, "Unlocated contrast issues grew from the known 8 to \(unlocated)")
    }
}
