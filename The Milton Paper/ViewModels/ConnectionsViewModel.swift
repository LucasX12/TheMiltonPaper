import Combine
import Foundation

enum ConnectionsPhase: String, Equatable {
    case empty
    case playing
    case won
    case lost
}

/// The Connections rule engine. There is no cover/Start screen: Wordle needs
/// one to gate its timer, and Connections has neither timer nor leaderboard,
/// so a Start button would be pure friction.
@MainActor
final class ConnectionsViewModel: ObservableObject {
    static let maxMistakes = 4
    static let selectionLimit = 4

    @Published private(set) var puzzle: ConnectionsPuzzle?
    @Published private(set) var tiles: [String] = []
    @Published private(set) var solved: [ConnectionsGroup] = []
    @Published private(set) var selection: Set<String> = []
    @Published private(set) var mistakesRemaining = ConnectionsViewModel.maxMistakes
    @Published private(set) var phase: ConnectionsPhase = .empty
    @Published private(set) var message: String?
    @Published private(set) var shakeToken = 0

    private(set) var guessHistory: [[String]] = []

    var canSubmit: Bool { phase == .playing && selection.count == Self.selectionLimit }
    var isFinished: Bool { phase == .won || phase == .lost }

    private let ownerID: String
    private let defaults: UserDefaults
    private var messageTask: Task<Void, Never>?

    /// `ownerID` is injected because `AuthService.init` attaches a Firebase
    /// auth listener whenever the app is not UI testing, and unit tests do not
    /// pass `-useMockData` — touching `AuthService.shared` from a test would
    /// call `Auth.auth()` with no configured app. Production uses the default.
    /// A default argument is evaluated outside the actor, so the owner is
    /// resolved inside the initialiser instead.
    init(ownerID: String? = nil, defaults: UserDefaults = .standard) {
        self.ownerID = ownerID ?? AuthService.shared.currentUser?.uid ?? "guest"
        self.defaults = defaults
    }

    // MARK: - Puzzle lifecycle

    /// A newer puzzle never interrupts a game in progress: the board you are
    /// holding is the board you finish. It is picked up once this game ends or
    /// the screen is rebuilt.
    func adopt(_ incoming: ConnectionsPuzzle?) {
        guard let incoming else {
            if puzzle == nil { phase = .empty }
            return
        }
        if phase == .playing, let current = puzzle, current.id != incoming.id { return }
        if puzzle?.id == incoming.id, phase != .empty { return }

        puzzle = incoming
        tiles = incoming.initialBoardOrder
        solved = []
        selection = []
        guessHistory = []
        mistakesRemaining = Self.maxMistakes
        phase = .playing
        if !Config.isUITesting { restoreState() }
    }

    // MARK: - Play

    func toggle(_ word: String) {
        guard phase == .playing else { return }
        if selection.contains(word) {
            selection.remove(word)
        } else if selection.count < Self.selectionLimit {
            selection.insert(word)
        }
    }

    func deselectAll() {
        guard phase == .playing else { return }
        selection.removeAll()
    }

    func shuffle() {
        guard phase == .playing, tiles.count > 1 else { return }
        var next = tiles.shuffled()
        // A shuffle that changes nothing reads as a broken button.
        if next == tiles { next = tiles.shuffled() }
        tiles = next
    }

    func submit() {
        guard canSubmit, let puzzle else { return }
        let guess = selection.sorted()
        guard !guessHistory.contains(guess) else {
            flash("Already guessed")
            return
        }
        guessHistory.append(guess)

        switch ConnectionsGuess.evaluate(selection: selection, groups: puzzle.groups) {
        case .correct(let groupID):
            guard let group = puzzle.groups.first(where: { $0.id == groupID }) else { return }
            solved.append(group)
            tiles.removeAll { group.words.contains($0) }
            selection.removeAll()
            if solved.count == puzzle.groups.count { phase = .won }
        case .oneAway:
            registerMistake(saying: "One away…")
        case .wrong:
            registerMistake(saying: nil)
        }
        saveState()
    }

    private func registerMistake(saying text: String?) {
        mistakesRemaining -= 1
        shakeToken += 1
        if let text { flash(text) }
        guard mistakesRemaining <= 0 else { return }
        phase = .lost
        revealRemaining()
    }

    /// Losing reveals the rest of the board, so reopening a lost puzzle shows
    /// the same finished screen.
    private func revealRemaining() {
        guard let puzzle else { return }
        let solvedIDs = Set(solved.map(\.id))
        solved.append(contentsOf: puzzle.groups.filter { !solvedIDs.contains($0.id) })
        tiles = []
        selection = []
    }

    private func flash(_ text: String) {
        messageTask?.cancel()
        message = text
        messageTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            guard !Task.isCancelled else { return }
            self?.message = nil
        }
    }

    // MARK: - Persistence

    private var stateKey: String { "connections.state.\(puzzle?.id ?? "none").\(ownerID)" }

    private func saveState() {
        guard !Config.isUITesting, let puzzle else { return }
        defaults.set([
            "solvedGroupIDs": solved.map(\.id),
            "tiles": tiles,
            "mistakesRemaining": mistakesRemaining,
            "phase": phase.rawValue,
            "guesses": guessHistory,
            "signature": puzzle.signature,
        ] as [String: Any], forKey: stateKey)
    }

    private func restoreState() {
        guard let puzzle, let data = defaults.dictionary(forKey: stateKey) else { return }
        // The editor corrected the live puzzle: start clean rather than
        // restore tiles that are no longer on the board.
        guard data["signature"] as? String == puzzle.signature else { return }

        if let ids = data["solvedGroupIDs"] as? [String] {
            solved = ids.compactMap { id in puzzle.groups.first { $0.id == id } }
        }
        if let saved = data["tiles"] as? [String] { tiles = saved }
        if let mistakes = data["mistakesRemaining"] as? Int { mistakesRemaining = mistakes }
        if let guesses = data["guesses"] as? [[String]] { guessHistory = guesses }
        if let raw = data["phase"] as? String, let restored = ConnectionsPhase(rawValue: raw) {
            phase = restored == .empty ? .playing : restored
        }
    }

    /// Wordle prunes every key that is not today's. Here the key is a puzzle
    /// id and a mid-game board has to survive a newer puzzle arriving, so only
    /// puzzles the service can currently see are kept — and nothing is deleted
    /// when it can see nothing, as on a cold offline launch.
    func cleanupStaleStates(keeping knownIDs: Set<String>) {
        guard !Config.isUITesting, !knownIDs.isEmpty else { return }
        let prefix = "connections.state."
        for key in defaults.dictionaryRepresentation().keys where key.hasPrefix(prefix) {
            let remainder = key.dropFirst(prefix.count)
            guard let puzzleID = remainder.split(separator: ".").first.map(String.init) else { continue }
            if !knownIDs.contains(puzzleID) { defaults.removeObject(forKey: key) }
        }
    }
}
