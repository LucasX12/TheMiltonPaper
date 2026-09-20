import Foundation

enum ConnectionsField {
    /// Accepts a Firestore array of strings, or one delimited string. Building
    /// a four-element array in the console is several clicks per word, so the
    /// documented path is pasting "Celtics, Bruins, Sox, Patriots".
    static func words(_ any: Any?) -> [String] {
        let raw: [String]
        switch any {
        case let list as [Any]:  raw = list.compactMap { HomeModuleField.string($0) }
        case let text as String: raw = text.components(separatedBy: CharacterSet(charactersIn: ",;\n"))
        default:                 return []
        }
        return raw.compactMap { HomeModuleField.string($0)?.uppercased() }
    }

    /// 1...4, from a number or a numeral typed as text.
    static func level(_ any: Any?, default fallback: Int) -> Int {
        let value = Int(HomeModuleField.double(any, default: Double(fallback)).rounded())
        return (1...4).contains(value) ? value : fallback
    }

    /// Last resort when `startsAt` is missing: the document is named for its
    /// date, so read the name.
    static func dateFromDocumentID(_ id: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: String(id.prefix(10)))
    }
}

struct ConnectionsGroup: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let name: String
    let words: [String]
    let level: Int
}

/// One week's puzzle, typed into the Firebase console. Everything lives in
/// top-level fields rather than a subcollection: a puzzle has to be valid as a
/// single unit, and a half-written subcollection would look complete to the
/// app while being unplayable.
struct ConnectionsPuzzle: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let title: String?
    let author: String?
    let isEnabled: Bool
    let startsAt: Date
    let groups: [ConnectionsGroup]

    var allWords: [String] { groups.flatMap(\.words) }

    /// Content fingerprint. A saved game is discarded when it changes, so an
    /// editor fixing a typo mid-week cannot leave a player holding tiles that
    /// are no longer on the board.
    var signature: String { allWords.sorted().joined(separator: "|") }

    /// A fixed arrangement per puzzle. `String.hashValue` is seeded per process
    /// and would deal a different board every launch, so the shuffle runs off a
    /// stable hash of the puzzle id instead.
    var initialBoardOrder: [String] {
        var generator = StableGenerator(seed: id)
        return allWords.shuffled(using: &generator)
    }

    init(id: String, title: String? = nil, author: String? = nil, isEnabled: Bool = true,
         startsAt: Date, groups: [ConnectionsGroup]) {
        self.id = id
        self.title = title
        self.author = author
        self.isEnabled = isEnabled
        self.startsAt = startsAt
        self.groups = groups
    }

    /// Returns nil for anything unplayable, so one bad document is skipped and
    /// last week's puzzle stays live rather than the tab going empty.
    init?(documentID: String, data: [String: Any]) {
        var parsed: [ConnectionsGroup] = []
        for index in 1...4 {
            guard let name = HomeModuleField.string(data["group\(index)Name"]) else { return nil }
            let words = ConnectionsField.words(data["group\(index)Words"])
            guard words.count == 4, Set(words).count == 4 else { return nil }
            parsed.append(ConnectionsGroup(
                id: "group\(index)",
                name: name,
                words: words,
                level: ConnectionsField.level(data["group\(index)Level"], default: index)
            ))
        }
        // Sixteen distinct words, or the board is ambiguous and unwinnable.
        guard Set(parsed.flatMap(\.words)).count == 16 else { return nil }
        guard let start = HomeModuleField.date(data["startsAt"])
                ?? ConnectionsField.dateFromDocumentID(documentID) else { return nil }

        // Whatever the editor typed, the puzzle ends up with one group at each
        // difficulty, so the four colours always appear exactly once.
        let ordered = parsed.enumerated()
            .sorted { ($0.element.level, $0.offset) < ($1.element.level, $1.offset) }
            .enumerated()
            .map { position, entry in
                ConnectionsGroup(id: entry.element.id, name: entry.element.name,
                                 words: entry.element.words, level: position + 1)
            }

        self.init(
            id: documentID,
            title: HomeModuleField.string(data["title"]),
            author: HomeModuleField.string(data["author"]),
            isEnabled: HomeModuleField.bool(data["enabled"], default: false),
            startsAt: start,
            groups: ordered
        )
    }
}

enum ConnectionsPuzzleFilter {
    /// The most recent puzzle whose start date has passed. Nothing expires, so
    /// once one puzzle exists this never returns nil — that is the whole "it
    /// stays there until a new one comes" guarantee. Future-dated puzzles are
    /// fetched and ignored until their moment, so next week can be loaded early.
    static func live(_ puzzles: [ConnectionsPuzzle], at now: Date = Date()) -> ConnectionsPuzzle? {
        puzzles
            .filter { $0.isEnabled && $0.startsAt <= now }
            .max { ($0.startsAt, $0.id) < ($1.startsAt, $1.id) }
    }
}

enum ConnectionsGuess {
    enum Outcome: Equatable {
        case correct(groupID: String)
        case oneAway
        case wrong
    }

    /// "One away" is the best overlap across all four categories, so a 2+2
    /// split is wrong rather than one away.
    static func evaluate(selection: Set<String>, groups: [ConnectionsGroup]) -> Outcome {
        guard selection.count == 4 else { return .wrong }
        var best = (overlap: 0, id: "")
        for group in groups {
            let overlap = selection.intersection(group.words).count
            if overlap > best.overlap { best = (overlap, group.id) }
        }
        switch best.overlap {
        case 4:  return .correct(groupID: best.id)
        case 3:  return .oneAway
        default: return .wrong
        }
    }
}

/// Seeded so every reader sees the same board and tests can target a tile.
struct StableGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: String) {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in seed.utf8 { hash = (hash ^ UInt64(byte)) &* 0x100_0000_01b3 }
        state = hash == 0 ? 0x9E37_79B9_7F4A_7C15 : hash
    }

    mutating func next() -> UInt64 {
        state ^= state >> 12
        state ^= state << 25
        state ^= state >> 27
        return state &* 2_685_821_657_736_338_717
    }
}
