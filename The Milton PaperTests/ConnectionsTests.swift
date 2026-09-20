import Foundation
import Testing
@testable import The_Milton_Paper

private let referenceNow = Date(timeIntervalSince1970: 2_000_000_000)

private func puzzleData(
    words: [[String]] = [["CELTICS", "BRUINS", "SOX", "PATRIOTS"],
                         ["LATIN", "PHYSICS", "HISTORY", "ART"],
                         ["ATLAS", "CARREL", "STACKS", "INDEX"],
                         ["BOAT", "GREEN", "FULL", "OPEN"]],
    enabled: Any = true,
    startsAt: Any? = referenceNow,
    levels: [Any?] = [nil, nil, nil, nil],
    asArrays: Bool = false
) -> [String: Any] {
    var data: [String: Any] = ["enabled": enabled]
    if let startsAt { data["startsAt"] = startsAt }
    for (index, group) in words.enumerated() {
        data["group\(index + 1)Name"] = "GROUP \(index + 1)"
        data["group\(index + 1)Words"] = asArrays ? group : group.joined(separator: ", ")
        if let level = levels[index] { data["group\(index + 1)Level"] = level }
    }
    return data
}

struct ConnectionsParsingTests {
    @Test func parsesCommaSeparatedWords() {
        let puzzle = ConnectionsPuzzle(documentID: "2026-09-23", data: puzzleData())
        #expect(puzzle?.groups.count == 4)
        #expect(puzzle?.groups.first?.words == ["CELTICS", "BRUINS", "SOX", "PATRIOTS"])
        #expect(puzzle?.allWords.count == 16)
    }

    @Test func parsesArraysAndNormalisesCase() {
        let data = puzzleData(words: [["celtics", " bruins ", "Sox", "patriots"],
                                      ["LATIN", "PHYSICS", "HISTORY", "ART"],
                                      ["ATLAS", "CARREL", "STACKS", "INDEX"],
                                      ["BOAT", "GREEN", "FULL", "OPEN"]], asArrays: true)
        let puzzle = ConnectionsPuzzle(documentID: "2026-09-23", data: data)
        #expect(puzzle?.groups.first?.words == ["CELTICS", "BRUINS", "SOX", "PATRIOTS"])
    }

    @Test func rejectsPuzzlesThatCannotBePlayed() {
        // A group of three.
        #expect(ConnectionsPuzzle(documentID: "d", data: puzzleData(words:
            [["A", "B", "C"], ["D", "E", "F", "G"], ["H", "I", "J", "K"], ["L", "M", "N", "O"]])) == nil)
        // The same word twice inside one group.
        #expect(ConnectionsPuzzle(documentID: "d", data: puzzleData(words:
            [["A", "A", "B", "C"], ["D", "E", "F", "G"], ["H", "I", "J", "K"], ["L", "M", "N", "O"]])) == nil)
        // The same word in two different groups.
        #expect(ConnectionsPuzzle(documentID: "d", data: puzzleData(words:
            [["A", "B", "C", "D"], ["A", "E", "F", "G"], ["H", "I", "J", "K"], ["L", "M", "N", "O"]])) == nil)
        // A missing category name.
        var missingName = puzzleData()
        missingName["group3Name"] = ""
        #expect(ConnectionsPuzzle(documentID: "d", data: missingName) == nil)
    }

    @Test func enabledFailsClosedAndDatesAreLenient() {
        var noFlag = puzzleData()
        noFlag.removeValue(forKey: "enabled")
        #expect(ConnectionsPuzzle(documentID: "2026-09-23", data: noFlag)?.isEnabled == false)
        #expect(ConnectionsPuzzle(documentID: "d", data: puzzleData(enabled: "true"))?.isEnabled == true)

        // Epoch seconds and an ISO string both parse.
        #expect(ConnectionsPuzzle(documentID: "d", data:
            puzzleData(startsAt: 2_000_000_000 as NSNumber))?.startsAt == referenceNow)
        #expect(ConnectionsPuzzle(documentID: "d", data:
            puzzleData(startsAt: "2033-05-18T03:33:20Z"))?.startsAt == referenceNow)
    }

    @Test func missingStartDateFallsBackToTheDocumentName() {
        let puzzle = ConnectionsPuzzle(documentID: "2026-09-23", data: puzzleData(startsAt: nil))
        #expect(puzzle != nil)
        // ...but only when the name is a date.
        #expect(ConnectionsPuzzle(documentID: "week-seven", data: puzzleData(startsAt: nil)) == nil)
    }

    @Test func levelsAreNormalisedToOneOfEachColour() {
        let puzzle = ConnectionsPuzzle(documentID: "d", data: puzzleData(levels: [2, 2, 2, 9]))
        #expect(puzzle?.groups.map(\.level) == [1, 2, 3, 4])
        // Explicit ordering is respected.
        let reordered = ConnectionsPuzzle(documentID: "d", data: puzzleData(levels: [4, 3, 2, 1]))
        #expect(reordered?.groups.map(\.name) == ["GROUP 4", "GROUP 3", "GROUP 2", "GROUP 1"])
    }

    @Test func boardOrderIsStableAcrossCalls() {
        let puzzle = ConnectionsPuzzle(documentID: "2026-09-23", data: puzzleData())
        #expect(puzzle?.initialBoardOrder == puzzle?.initialBoardOrder)
        #expect(Set(puzzle?.initialBoardOrder ?? []) == Set(puzzle?.allWords ?? []))
    }
}

struct ConnectionsSelectionTests {
    private func puzzle(_ id: String, day: Int, enabled: Bool = true) -> ConnectionsPuzzle {
        ConnectionsPuzzle(
            id: id, isEnabled: enabled,
            startsAt: referenceNow.addingTimeInterval(Double(day) * 86_400),
            groups: (1...4).map {
                ConnectionsGroup(id: "group\($0)", name: "G\($0)",
                                 words: ["\($0)A", "\($0)B", "\($0)C", "\($0)D"], level: $0)
            }
        )
    }

    @Test func newestStartedPuzzleWins() {
        let puzzles = [puzzle("old", day: -14), puzzle("current", day: -2), puzzle("future", day: 7)]
        #expect(ConnectionsPuzzleFilter.live(puzzles, at: referenceNow)?.id == "current")
    }

    @Test func disabledAndEmptyAreHandled() {
        #expect(ConnectionsPuzzleFilter.live([], at: referenceNow) == nil)
        let puzzles = [puzzle("old", day: -14), puzzle("current", day: -2, enabled: false)]
        #expect(ConnectionsPuzzleFilter.live(puzzles, at: referenceNow)?.id == "old")
    }

    @Test func sameDateResolvesByIDAndIsStable() {
        let puzzles = [puzzle("b", day: -1), puzzle("a", day: -1)]
        #expect(ConnectionsPuzzleFilter.live(puzzles, at: referenceNow)?.id == "b")
        #expect(ConnectionsPuzzleFilter.live(puzzles, at: referenceNow)?.id
                == ConnectionsPuzzleFilter.live(puzzles, at: referenceNow)?.id)
    }

    /// The guarantee the whole design rests on: a broken upload must leave
    /// last week's puzzle playable rather than emptying the tab.
    @Test func aBrokenNewPuzzleLeavesLastWeeksPlayable() {
        let good = puzzleData()
        var broken = puzzleData()
        broken["group2Words"] = "ONLY, THREE, WORDS"

        let documents: [(String, [String: Any])] = [
            ("2026-09-16", good),
            ("2026-09-23", broken),
        ]
        let parsed = documents.compactMap { ConnectionsPuzzle(documentID: $0.0, data: $0.1) }
        #expect(parsed.count == 1)
        #expect(ConnectionsPuzzleFilter.live(parsed, at: Date(timeIntervalSince1970: 2_100_000_000))?.id
                == "2026-09-16")
    }
}

struct ConnectionsGuessTests {
    private let groups = [
        ConnectionsGroup(id: "g1", name: "A", words: ["A1", "A2", "A3", "A4"], level: 1),
        ConnectionsGroup(id: "g2", name: "B", words: ["B1", "B2", "B3", "B4"], level: 2),
        ConnectionsGroup(id: "g3", name: "C", words: ["C1", "C2", "C3", "C4"], level: 3),
        ConnectionsGroup(id: "g4", name: "D", words: ["D1", "D2", "D3", "D4"], level: 4),
    ]

    @Test func evaluatesEveryOutcome() {
        #expect(ConnectionsGuess.evaluate(selection: ["A1", "A2", "A3", "A4"], groups: groups)
                == .correct(groupID: "g1"))
        #expect(ConnectionsGuess.evaluate(selection: ["A1", "A2", "A3", "B1"], groups: groups) == .oneAway)
        // A two-and-two split is wrong, not one away.
        #expect(ConnectionsGuess.evaluate(selection: ["A1", "A2", "B1", "B2"], groups: groups) == .wrong)
        #expect(ConnectionsGuess.evaluate(selection: ["A1", "B1", "C1", "D1"], groups: groups) == .wrong)
        // Fewer than four is never a guess.
        #expect(ConnectionsGuess.evaluate(selection: ["A1", "A2", "A3"], groups: groups) == .wrong)
    }
}

@MainActor
struct ConnectionsGameTests {
    private func makeViewModel() -> ConnectionsViewModel {
        let suite = UserDefaults(suiteName: "connections.tests.\(UUID().uuidString)")!
        // ownerID is injected because AuthService.init attaches a Firebase auth
        // listener outside UI testing, and unit tests have no configured app.
        let viewModel = ConnectionsViewModel(ownerID: "test", defaults: suite)
        viewModel.adopt(ConnectionsPuzzle(documentID: "2026-09-23", data: puzzleData()))
        return viewModel
    }

    @Test func selectionIsCappedAtFour() {
        let viewModel = makeViewModel()
        for word in ["CELTICS", "BRUINS", "SOX", "PATRIOTS", "LATIN"] { viewModel.toggle(word) }
        #expect(viewModel.selection.count == 4)
        viewModel.toggle("CELTICS")
        #expect(viewModel.selection.count == 3)
        viewModel.deselectAll()
        #expect(viewModel.selection.isEmpty)
    }

    @Test func aCorrectGuessLocksTheGroup() {
        let viewModel = makeViewModel()
        for word in ["CELTICS", "BRUINS", "SOX", "PATRIOTS"] { viewModel.toggle(word) }
        viewModel.submit()
        #expect(viewModel.solved.count == 1)
        #expect(viewModel.tiles.count == 12)
        #expect(viewModel.selection.isEmpty)
        #expect(viewModel.mistakesRemaining == 4)
    }

    @Test func fourMistakesLoseAndRevealEverything() {
        let viewModel = makeViewModel()
        let wrongGuesses = [["CELTICS", "BRUINS", "SOX", "LATIN"],
                            ["CELTICS", "BRUINS", "SOX", "ART"],
                            ["CELTICS", "BRUINS", "SOX", "ATLAS"],
                            ["CELTICS", "BRUINS", "SOX", "BOAT"]]
        for guess in wrongGuesses {
            viewModel.deselectAll()
            for word in guess { viewModel.toggle(word) }
            viewModel.submit()
        }
        #expect(viewModel.phase == .lost)
        #expect(viewModel.solved.count == 4)
        #expect(viewModel.tiles.isEmpty)
    }

    @Test func solvingEverythingWins() {
        let viewModel = makeViewModel()
        for group in viewModel.puzzle!.groups {
            viewModel.deselectAll()
            for word in group.words { viewModel.toggle(word) }
            viewModel.submit()
        }
        #expect(viewModel.phase == .won)
        #expect(viewModel.mistakesRemaining == 4)
    }

    @Test func repeatingAGuessCostsNothing() {
        let viewModel = makeViewModel()
        for word in ["CELTICS", "BRUINS", "SOX", "LATIN"] { viewModel.toggle(word) }
        viewModel.submit()
        #expect(viewModel.mistakesRemaining == 3)
        for word in ["CELTICS", "BRUINS", "SOX", "LATIN"] { viewModel.toggle(word) }
        viewModel.submit()
        #expect(viewModel.mistakesRemaining == 3)
    }

    @Test func shufflePreservesTheBoard() {
        let viewModel = makeViewModel()
        let before = viewModel.tiles
        viewModel.shuffle()
        #expect(Set(viewModel.tiles) == Set(before))
        #expect(viewModel.tiles.count == before.count)
    }

    @Test func aNewPuzzleNeverInterruptsAGameInProgress() {
        let viewModel = makeViewModel()
        viewModel.toggle("CELTICS")
        let newer = ConnectionsPuzzle(documentID: "2026-09-30", data: puzzleData())
        viewModel.adopt(newer)
        #expect(viewModel.puzzle?.id == "2026-09-23")

        // Once the game is over the newer puzzle is taken up.
        for group in viewModel.puzzle!.groups {
            viewModel.deselectAll()
            for word in group.words { viewModel.toggle(word) }
            viewModel.submit()
        }
        #expect(viewModel.phase == .won)
        viewModel.adopt(newer)
        #expect(viewModel.puzzle?.id == "2026-09-30")
    }
}

struct WriterDirectoryTests {
    @Test func slugsSurviveSpacingAccentsAndPunctuation() {
        #expect(Writer.slug(for: "Joanna Zhang") == "joanna-zhang")
        #expect(Writer.slug(for: "  joanna   zhang ") == "joanna-zhang")
        #expect(Writer.slug(for: "Renée O'Brien") == "renee-o-brien")
        #expect(Writer.slug(for: "Joanna Zhang") == Writer.slug(for: "JOANNA ZHANG"))
    }

    @Test func bylinesSplitIntoIndividualWriters() {
        #expect(Writer.names(inByline: "Joanna Zhang") == ["Joanna Zhang"])
        #expect(Writer.names(inByline: "Joanna Zhang and Leo Wan") == ["Joanna Zhang", "Leo Wan"])
        #expect(Writer.names(inByline: "").isEmpty)
    }

    @Test func writersParseLeniently() {
        let writer = Writer(documentID: "joanna-zhang", data: [
            "name": " Joanna Zhang ", "bio": "Covers news.", "role": "News Editor",
            "classYear": "\u{2019}27", "photoURL": "https://example.com/j.jpg",
        ])
        #expect(writer?.name == "Joanna Zhang")
        #expect(writer?.credit == "News Editor \u{2019}27")
        #expect(writer?.photoURL != nil)
        // Writers default to shown, and a bad photo address is simply dropped.
        #expect(Writer(documentID: "x", data: ["name": "A"])?.isEnabled == true)
        #expect(Writer(documentID: "x", data: ["name": "A", "photoURL": "javascript:x"])?.photoURL == nil)
        #expect(Writer(documentID: "x", data: ["bio": "no name"]) == nil)
    }
}
