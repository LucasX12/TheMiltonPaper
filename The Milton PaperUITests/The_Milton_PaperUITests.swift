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

    /// The floating tab bar occasionally swallows a tap that lands while it is
    /// still animating in, so every tab switch gets one retry before failing.
    private func switchTo(_ tab: String, in app: XCUIApplication,
                          expecting element: XCUIElement,
                          file: StaticString = #filePath, line: UInt = #line) {
        app.tabBars.buttons[tab].tap()
        if element.waitForExistence(timeout: 15) { return }
        app.tabBars.buttons[tab].tap()
        XCTAssertTrue(element.waitForExistence(timeout: 20),
                      "\(tab) tab did not present its content", file: file, line: line)
    }

    func testEditorialNavigationShell() {
        let app = launch()
        for title in ["Today", "Sections", "TMPlay", "Saved", "You"] {
            XCTAssertTrue(app.tabBars.buttons[title].exists)
        }
        capture(app, name: "Today")
        let news = app.buttons["section.category-news"]
        switchTo("Sections", in: app, expecting: news)
        news.tap()
        XCTAssertTrue(app.navigationBars["News"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.buttons["story.article-1"].exists)
        capture(app, name: "News")
    }

    func testTodayArticleAndSaveSignInPrompt() {
        let app = launch()
        let story = app.buttons["story.article-1"]
        XCTAssertTrue(story.waitForExistence(timeout: 15))
        story.tap()
        let save = app.buttons["Save Story"]
        // The simulator occasionally drops the first synthesized tap after
        // launch, so retry once before failing.
        if !save.waitForExistence(timeout: 15) {
            story.tap()
            XCTAssertTrue(save.waitForExistence(timeout: 15))
        }
        capture(app, name: "Article")
        save.tap()
        XCTAssertTrue(app.buttons["Continue with Google"].waitForExistence(timeout: 15))
    }

    func testSearchFindsAStory() {
        let app = launch()
        app.buttons["Search"].tap()
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 15))
        search.tap()
        search.typeText("Science")
        let result = app.buttons["story.article-1"]
        XCTAssertTrue(result.waitForExistence(timeout: 15))
        result.tap()
        XCTAssertTrue(app.buttons["Article actions"].waitForExistence(timeout: 15))
    }

    func testSavedAndYouGuestStates() {
        let app = launch()
        switchTo("Saved", in: app, expecting: app.staticTexts["Sign in to save articles"])
        capture(app, name: "Saved")
        switchTo("You", in: app, expecting: app.staticTexts["Your reading, in one place"])
        capture(app, name: "You")
    }

    func testTMPlayStartsAndAcceptsInput() {
        let app = launch()
        // TMPlay now opens behind a Wordle | Connections picker. Wordle is the
        // default and the inactive game is hidden from the accessibility tree,
        // so "Start", "How to play" and "Q" each still match one element.
        switchTo("TMPlay", in: app, expecting: app.buttons["Start"])
        XCTAssertTrue(app.segmentedControls["tmplay.game-picker"].exists)
        capture(app, name: "TMPlay")
        app.buttons["Start"].tap()
        XCTAssertTrue(app.buttons["How to play"].waitForExistence(timeout: 15))
        app.buttons["Q"].tap()
        capture(app, name: "TMPlay-playing")
    }

    func testIssueOpensFullScreenAndCloses() {
        let app = launch()
        let thisWeek = app.buttons["section.this-week"]
        switchTo("Sections", in: app, expecting: thisWeek)
        thisWeek.tap()
        let expand = app.buttons["Open issue full screen"]
        XCTAssertTrue(expand.waitForExistence(timeout: 15))
        expand.tap()
        let close = app.buttons["Close full screen issue"]
        XCTAssertTrue(close.waitForExistence(timeout: 15))
        XCTAssertFalse(app.tabBars.firstMatch.isHittable)
        capture(app, name: "Issue-fullscreen")
        close.tap()
        XCTAssertTrue(expand.waitForExistence(timeout: 15))
    }

    func testHiddenFeaturesHaveNoDestinations() {
        let app = launch(["-hideTMPlay", "-hideSports"])
        XCTAssertFalse(app.tabBars.buttons["TMPlay"].exists)
        switchTo("Sections", in: app, expecting: app.buttons["section.category-news"])
        XCTAssertFalse(app.buttons["section.category-sports"].exists)
    }

    func testLogoOpensTheMasthead() {
        let app = launch()
        let logo = app.buttons["masthead.logo"]
        XCTAssertTrue(logo.waitForExistence(timeout: 15))
        logo.tap()
        // The page content is scraped from the website, so assert on the
        // screen's own chrome rather than on staff names.
        let masthead = app.buttons["Masthead"]
        if !masthead.waitForExistence(timeout: 15) {
            logo.tap()
            XCTAssertTrue(masthead.waitForExistence(timeout: 15))
        }
        XCTAssertTrue(app.buttons["About"].exists)
        XCTAssertTrue(masthead.isSelected)
        capture(app, name: "Masthead")
    }

    func testHomeModulesRenderAndCanBeHidden() {
        let app = launch()
        let spotlight = app.buttons["home.module.senior-of-the-week"]
        XCTAssertTrue(spotlight.waitForExistence(timeout: 15))
        XCTAssertTrue(app.staticTexts["Spring Sports"].exists)
        capture(app, name: "HomeModules")

        let hidden = launch(["-hideHomeModules"])
        XCTAssertTrue(hidden.buttons["story.article-1"].waitForExistence(timeout: 15))
        XCTAssertFalse(hidden.buttons["home.module.senior-of-the-week"].exists)
    }

    func testConnectionsIsPlayableFromTheGamePicker() {
        let app = launch()
        switchTo("TMPlay", in: app, expecting: app.buttons["Start"])
        app.segmentedControls["tmplay.game-picker"].buttons["Connections"].tap()

        let tile = app.buttons["connections.tile.CELTICS"]
        XCTAssertTrue(tile.waitForExistence(timeout: 15))
        XCTAssertFalse(app.buttons["Start"].exists)   // Wordle layer is out of the tree

        for word in ["CELTICS", "BRUINS", "SOX", "PATRIOTS"] {
            app.buttons["connections.tile.\(word)"].tap()
        }
        app.buttons["Submit"].tap()
        // The solved band combines its children into one accessibility
        // element, whose type is not guaranteed, so match on the identifier.
        let solved = app.descendants(matching: .any)["connections.solved.group1"]
        XCTAssertTrue(solved.waitForExistence(timeout: 15))
        capture(app, name: "Connections")
    }

    func testHiddenConnectionsLeavesWordleAlone() {
        let app = launch(["-hideConnections"])
        switchTo("TMPlay", in: app, expecting: app.buttons["Start"])
        XCTAssertFalse(app.segmentedControls["tmplay.game-picker"].exists)
    }

    func testSectionsFooterShowsTheAINotice() {
        let app = launch()
        switchTo("Sections", in: app, expecting: app.buttons["section.category-news"])
        let notice = app.descendants(matching: .any)["ai.notice"]
        XCTAssertTrue(notice.waitForExistence(timeout: 15))
        XCTAssertFalse(app.buttons["section.about"].exists)
        capture(app, name: "Sections-footer")
    }

    private func capture(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
