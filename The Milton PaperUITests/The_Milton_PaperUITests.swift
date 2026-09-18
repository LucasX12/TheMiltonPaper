import XCTest

@MainActor
final class The_Milton_PaperUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    private func launch(_ arguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-useMockData"] + arguments
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["Today"].waitForExistence(timeout: 15))
        return app
    }

    func testEditorialNavigationShell() {
        let app = launch()
        for title in ["Today", "Sections", "TMPlay", "Saved", "You"] {
            XCTAssertTrue(app.tabBars.buttons[title].exists)
        }
        capture(app, name: "Today")
        app.tabBars.buttons["Sections"].tap()
        let news = app.buttons["section.category-news"]
        XCTAssertTrue(news.waitForExistence(timeout: 5))
        news.tap()
        XCTAssertTrue(app.navigationBars["News"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["story.article-1"].exists)
        capture(app, name: "News")
    }

    func testTodayArticleAndSaveSignInPrompt() {
        let app = launch()
        let story = app.buttons["story.article-1"]
        XCTAssertTrue(story.waitForExistence(timeout: 10))
        story.tap()
        let save = app.buttons["Save Story"]
        // The simulator occasionally drops the first synthesized tap after
        // launch, so retry once before failing.
        if !save.waitForExistence(timeout: 5) {
            story.tap()
            XCTAssertTrue(save.waitForExistence(timeout: 10))
        }
        capture(app, name: "Article")
        save.tap()
        XCTAssertTrue(app.buttons["Continue with Google"].waitForExistence(timeout: 5))
    }

    func testSearchFindsAStory() {
        let app = launch()
        app.buttons["Search"].tap()
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        search.typeText("Science")
        let result = app.buttons["story.article-1"]
        XCTAssertTrue(result.waitForExistence(timeout: 5))
        result.tap()
        XCTAssertTrue(app.buttons["Article actions"].waitForExistence(timeout: 5))
    }

    func testSavedAndYouGuestStates() {
        let app = launch()
        app.tabBars.buttons["Saved"].tap()
        XCTAssertTrue(app.staticTexts["Sign in to save articles"].waitForExistence(timeout: 5))
        capture(app, name: "Saved")
        app.tabBars.buttons["You"].tap()
        XCTAssertTrue(app.staticTexts["Your reading, in one place"].waitForExistence(timeout: 5))
        capture(app, name: "You")
    }

    func testTMPlayStartsAndAcceptsInput() {
        let app = launch()
        app.tabBars.buttons["TMPlay"].tap()
        XCTAssertTrue(app.buttons["Start"].waitForExistence(timeout: 5))
        capture(app, name: "TMPlay")
        app.buttons["Start"].tap()
        XCTAssertTrue(app.buttons["How to play"].waitForExistence(timeout: 5))
        app.buttons["Q"].tap()
        capture(app, name: "TMPlay-playing")
    }

    func testIssueOpensFullScreenAndCloses() {
        let app = launch()
        app.tabBars.buttons["Sections"].tap()
        app.buttons["section.this-week"].tap()
        let expand = app.buttons["Open issue full screen"]
        XCTAssertTrue(expand.waitForExistence(timeout: 5))
        expand.tap()
        let close = app.buttons["Close full screen issue"]
        XCTAssertTrue(close.waitForExistence(timeout: 5))
        XCTAssertFalse(app.tabBars.firstMatch.isHittable)
        capture(app, name: "Issue-fullscreen")
        close.tap()
        XCTAssertTrue(expand.waitForExistence(timeout: 5))
    }

    func testHiddenFeaturesHaveNoDestinations() {
        let app = launch(["-hideTMPlay", "-hideSports"])
        XCTAssertFalse(app.tabBars.buttons["TMPlay"].exists)
        // A tap during the tab bar's entrance animation can be dropped, so
        // retry once before failing.
        app.tabBars.buttons["Sections"].tap()
        if !app.buttons["section.category-news"].waitForExistence(timeout: 5) {
            app.tabBars.buttons["Sections"].tap()
            XCTAssertTrue(app.buttons["section.category-news"].waitForExistence(timeout: 10))
        }
        XCTAssertFalse(app.buttons["section.category-sports"].exists)
    }

    private func capture(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
