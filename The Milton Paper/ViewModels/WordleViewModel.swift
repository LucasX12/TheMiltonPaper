import Foundation
import Combine
import UIKit
import FirebaseFirestore
import os

// MARK: - Types

enum LetterState: Equatable {
    case unknown   // keyboard key not yet used
    case empty     // grid cell is empty
    case tbd       // typed but not submitted
    case absent    // gray: not in word
    case present   // yellow: in word, wrong position
    case correct   // green: right letter, right position
}

struct LetterCell: Identifiable {
    let id = UUID()
    var letter: String = ""
    var state: LetterState = .empty
}

struct WordleScore: Identifiable {
    let id: String
    let uid: String
    let displayName: String
    let tries: Int      // 1–6, or 7 = did not solve
    let seconds: Int
    let date: String
}

enum WordlePhase: Equatable {
    case cover
    case playing
    case won
    case lost
}

// MARK: - ViewModel

@MainActor
final class WordleViewModel: ObservableObject {
    static let wordLength = 5
    static let maxGuesses = 6

    @Published var grid: [[LetterCell]]
    @Published var currentRow = 0
    @Published var currentCol = 0
    @Published var letterStates: [String: LetterState] = [:]
    @Published var phase: WordlePhase = .cover
    @Published var elapsedSeconds = 0
    @Published var errorMessage: String? = nil
    @Published var leaderboard: [WordleScore] = []
    @Published var isLoadingLeaderboard = false
    @Published var leaderboardError: String?

    let todayWord: String
    let dateString: String

    private var timerTask: Task<Void, Never>?

    init() {
        let today = Self.todayDateString()
        self.dateString = today
        self.todayWord = Self.wordForToday()
        self.grid = (0..<Self.maxGuesses).map { _ in
            (0..<Self.wordLength).map { _ in LetterCell() }
        }
        restoreState()

        NotificationCenter.default.addObserver(
            forName: UIApplication.willResignActiveNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in self?.stopTimer() }
        }
        NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard self?.phase == .playing else { return }
                self?.startTimer()
            }
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Game Control

    func startGame() {
        phase = .playing
        startTimer()
    }

    func pressKey(_ key: String) {
        guard phase == .playing else { return }
        switch key {
        case "⌫":    deleteLetter()
        case "ENTER": submitGuess()
        default:
            guard currentCol < Self.wordLength else { return }
            grid[currentRow][currentCol].letter = key
            grid[currentRow][currentCol].state = .tbd
            currentCol += 1
        }
    }

    // MARK: - Private

    private func submitGuess() {
        let word = grid[currentRow].map { $0.letter }.joined()
        guard word.count == Self.wordLength else {
            showError("Word too short")
            return
        }
        guard Self.validWordSet.contains(word.lowercased()) else {
            showError("Not in word list")
            return
        }
        evaluateGuess(word)
    }

    private func deleteLetter() {
        guard currentCol > 0 else { return }
        currentCol -= 1
        grid[currentRow][currentCol].letter = ""
        grid[currentRow][currentCol].state = .empty
    }

    private func evaluateGuess(_ word: String) {
        let guess = Array(word)
        let answer = Array(todayWord)
        var result = Array(repeating: LetterState.absent, count: Self.wordLength)
        var answerUsed = Array(repeating: false, count: Self.wordLength)
        var guessUsed  = Array(repeating: false, count: Self.wordLength)

        for i in 0..<Self.wordLength where guess[i] == answer[i] {
            result[i]      = .correct
            answerUsed[i]  = true
            guessUsed[i]   = true
        }
        for i in 0..<Self.wordLength {
            guard !guessUsed[i] else { continue }
            for j in 0..<Self.wordLength where !answerUsed[j] && guess[i] == answer[j] {
                result[i]     = .present
                answerUsed[j] = true
                break
            }
        }

        for i in 0..<Self.wordLength {
            grid[currentRow][i].state = result[i]
        }
        for i in 0..<Self.wordLength {
            let letter = String(guess[i])
            let existing = letterStates[letter] ?? .unknown
            if rankState(result[i]) > rankState(existing) {
                letterStates[letter] = result[i]
            }
        }

        let won = result.allSatisfy { $0 == .correct }
        currentRow += 1
        currentCol = 0

        if won {
            phase = .won
            stopTimer()
        } else if currentRow >= Self.maxGuesses {
            phase = .lost
            stopTimer()
        }
        saveState()
    }

    private func rankState(_ s: LetterState) -> Int {
        switch s {
        case .unknown, .empty, .tbd: return 0
        case .absent:  return 1
        case .present: return 2
        case .correct: return 3
        }
    }

    private func showError(_ msg: String) {
        errorMessage = msg
        Task {
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            errorMessage = nil
        }
    }

    // MARK: - Timer

    private func startTimer() {
        timerTask?.cancel()
        timerTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                guard !Task.isCancelled else { break }
                elapsedSeconds += 1
            }
        }
    }

    private func stopTimer() {
        timerTask?.cancel()
        timerTask = nil
    }

    // MARK: - Persistence

    private static func todayDateString() -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        return fmt.string(from: Date())
    }

    private var stateKey: String { "wordle.state.\(dateString)" }

    private func saveState() {
        let letters   = grid.map { $0.map { $0.letter } }
        let states    = grid.map { $0.map { stateString($0.state) } }
        let keyStates = letterStates.mapValues { stateString($0) }
        UserDefaults.standard.set([
            "letters": letters, "states": states, "keyStates": keyStates,
            "currentRow": currentRow, "currentCol": currentCol,
            "phase": phaseString(phase), "elapsedSeconds": elapsedSeconds,
            "todayWord": todayWord
        ] as [String: Any], forKey: stateKey)
    }

    private func restoreState() {
        guard let data = UserDefaults.standard.dictionary(forKey: stateKey) else { return }
        // Discard saved state if the daily word changed (e.g. word list was updated)
        if let savedWord = data["todayWord"] as? String, savedWord != todayWord { return }
        if let letters = data["letters"] as? [[String]],
           let states  = data["states"]  as? [[String]] {
            for row in 0..<min(letters.count, Self.maxGuesses) {
                for col in 0..<min(letters[row].count, Self.wordLength) {
                    grid[row][col].letter = letters[row][col]
                    grid[row][col].state  = stateFromString(states[row][col])
                }
            }
        }
        if let ks = data["keyStates"] as? [String: String] {
            letterStates = ks.mapValues { stateFromString($0) }
        }
        if let r = data["currentRow"]      as? Int { currentRow      = r }
        if let c = data["currentCol"]      as? Int { currentCol      = c }
        if let s = data["elapsedSeconds"]  as? Int { elapsedSeconds  = s }
        if let p = data["phase"]           as? String {
            let restored = phaseFromString(p)
            phase = (restored == .won || restored == .lost) ? restored : .cover
        }
    }

    private func stateString(_ s: LetterState) -> String {
        switch s {
        case .unknown: return "unknown"
        case .empty:   return "empty"
        case .tbd:     return "tbd"
        case .absent:  return "absent"
        case .present: return "present"
        case .correct: return "correct"
        }
    }

    private func stateFromString(_ s: String) -> LetterState {
        switch s {
        case "absent":  return .absent
        case "present": return .present
        case "correct": return .correct
        case "tbd":     return .tbd
        default:        return .empty
        }
    }

    private func phaseString(_ p: WordlePhase) -> String {
        switch p {
        case .cover:   return "cover"
        case .playing: return "playing"
        case .won:     return "won"
        case .lost:    return "lost"
        }
    }

    private func phaseFromString(_ s: String) -> WordlePhase {
        switch s {
        case "won":  return .won
        case "lost": return .lost
        default:     return .playing
        }
    }

    // MARK: - Daily Word

    static func wordForToday() -> String {
        let ref   = Calendar.current.date(from: DateComponents(year: 2024, month: 1, day: 1))!
        let today = Calendar.current.startOfDay(for: Date())
        let days  = Calendar.current.dateComponents([.day], from: ref, to: today).day ?? 0
        return wordList[abs(days) % wordList.count].uppercased()
    }

    // MARK: - Leaderboard

    func loadLeaderboard() async {
        isLoadingLeaderboard = true
        leaderboardError = nil
        do {
            let snapshot = try await Firestore.firestore()
                .collection("wordleScores")
                .whereField("date", isEqualTo: dateString)
                .getDocuments()
            leaderboard = snapshot.documents.compactMap { doc -> WordleScore? in
                let d = doc.data()
                guard
                    let uid         = d["uid"]         as? String,
                    let displayName = d["displayName"] as? String,
                    let tries       = d["tries"]       as? Int,
                    let seconds     = d["seconds"]     as? Int,
                    let date        = d["date"]        as? String
                else { return nil }
                return WordleScore(id: doc.documentID, uid: uid, displayName: displayName,
                                   tries: tries, seconds: seconds, date: date)
            }
            leaderboard.sort { ($0.tries, $0.seconds) < ($1.tries, $1.seconds) }
        } catch {
            leaderboardError = error.localizedDescription
        }
        isLoadingLeaderboard = false
    }

    func submitScore(uid: String, displayName: String) {
        let tries = phase == .won ? currentRow : 7
        let docID = "\(dateString)_\(uid)"
        let score = WordleScore(id: docID, uid: uid,
                                displayName: displayName, tries: tries,
                                seconds: elapsedSeconds, date: dateString)
        leaderboard.removeAll { $0.uid == uid }
        leaderboard.append(score)
        leaderboard.sort { ($0.tries, $0.seconds) < ($1.tries, $1.seconds) }

        Task {
            do {
                try await Firestore.firestore()
                    .collection("wordleScores")
                    .document(docID)
                    .setData([
                        "uid": uid,
                        "displayName": displayName,
                        "tries": tries,
                        "seconds": elapsedSeconds,
                        "date": dateString
                    ])
            } catch {
                os_log("[Wordle] Failed to submit score: %@", log: OSLog.default, type: .error, error.localizedDescription)
            }
        }
    }

    // MARK: - Word List (daily answer pool — 1500+ common words)

    static let wordList: [String] = [
        // A
        "abbey", "abide", "abbot", "abhor", "abode", "about", "above", "abuse",
        "acorn", "acrid", "actor", "acute", "adage", "adept", "admit", "adobe",
        "adopt", "adult", "after", "again", "agent", "agree", "ahead", "agile",
        "aglow", "agony", "aisle", "alarm", "album", "alert", "alien", "align",
        "alike", "alive", "alley", "allow", "alone", "along", "aloft", "alter",
        "amaze", "amble", "amend", "amiss", "amuse", "angel", "angle", "angry",
        "annex", "annoy", "apart", "apple", "apply", "apron", "arbor", "ardor",
        "arena", "argue", "arise", "armor", "aroma", "array", "arson", "aside",
        "askew", "asset", "atlas", "atone", "attic", "audio", "audit", "augur",
        "avail", "avoid", "awake", "award", "aware", "awful", "azure",
        // B
        "backs", "bacon", "bagel", "balls", "bands", "banks", "barns", "basic",
        "basis", "batch", "beach", "beard", "beast", "beads", "beams", "beers",
        "began", "begin", "being", "below", "bench", "berry", "bikes", "bills",
        "birds", "birth", "black", "blade", "blame", "bland", "blank", "blast",
        "blaze", "bleed", "blend", "bless", "blind", "blobs", "block", "blood",
        "bloom", "blots", "blues", "blurs", "board", "boats", "bolts", "bonds",
        "books", "boost", "boots", "bound", "boxer", "brain", "brand", "brave",
        "brash", "brawl", "brawn", "bread", "break", "breed", "brick", "bride",
        "brief", "brine", "bring", "broil", "broad", "broke", "brook", "broth",
        "brows", "brown", "brunt", "brush", "bucks", "build", "built", "bulls",
        "bumps", "bunks", "burns", "burst", "buyer",
        // C
        "cabin", "cable", "calls", "camps", "candy", "cards", "cargo", "carry",
        "carts", "catch", "cause", "caves", "cease", "chain", "chair", "champ",
        "chant", "chaos", "charm", "chart", "chase", "cheap", "check", "cheek",
        "chess", "chest", "chief", "child", "chips", "choir", "chord", "civil",
        "claim", "clamp", "clang", "clash", "clasp", "class", "cleat", "cleft",
        "clean", "clear", "clerk", "click", "cliff", "climb", "cling", "cloak",
        "clock", "clone", "close", "cloth", "cloud", "clown", "coast", "coils",
        "coins", "colds", "color", "comet", "comic", "comma", "coral", "cords",
        "costs", "count", "court", "cover", "cower", "craft", "crane", "crank",
        "crash", "crazy", "creak", "cream", "creek", "creep", "crest", "crime",
        "crimp", "crisp", "croak", "crook", "cross", "crowd", "crown", "cruel",
        "crumb", "crush", "crypt", "cults", "curbs", "curls", "curve", "cycle",
        // D
        "daffy", "daily", "daisy", "dames", "dance", "dates", "deals", "death",
        "debut", "decks", "deeds", "delay", "delta", "delve", "demon", "dense",
        "depot", "depth", "derby", "detox", "deuce", "dirty", "disco", "ditzy",
        "dizzy", "dodge", "dolor", "dolls", "doves", "doubt", "dough", "downs",
        "draft", "drain", "drama", "drank", "drawl", "dread", "dream", "dress",
        "drift", "drink", "drive", "drone", "drool", "droop", "drops", "drown",
        "drums", "dryer", "ducts", "duels", "dunes", "dwarf", "dying",
        // E
        "eager", "eagle", "early", "earth", "ebony", "eerie", "eight", "elbow",
        "elite", "ember", "empty", "enact", "endow", "enemy", "enjoy", "ensue",
        "enter", "entry", "envoy", "epoxy", "equal", "equip", "erase", "error",
        "erupt", "essay", "event", "every", "exact", "exist", "extra",
        // F
        "fable", "faces", "faint", "faith", "falls", "false", "fancy", "farms",
        "farce", "fasts", "fatal", "fault", "fawns", "feast", "feats", "felon",
        "fence", "ferry", "fetch", "fever", "fiber", "field", "fiend", "fifth",
        "fifty", "fight", "films", "final", "first", "fists", "fixed", "fizzy",
        "flail", "flake", "flame", "flank", "flaps", "flare", "flash", "flask",
        "flats", "flaws", "fleas", "flesh", "flick", "flint", "flips", "float",
        "flops", "flood", "floor", "flour", "fluid", "flute", "foals", "foams",
        "focus", "foggy", "folds", "fonts", "force", "fords", "forge", "forte",
        "forts", "found", "frail", "frame", "frank", "freak", "fresh", "frond",
        "front", "frost", "froze", "fruit", "fuels", "fumes", "fully", "funny",
        // G
        "gales", "gains", "games", "gaudy", "gavel", "gears", "genre", "germs",
        "ghost", "giant", "giddy", "gifts", "girls", "given", "glean", "glass",
        "glide", "globs", "gloom", "gloat", "glory", "gloss", "glove", "goals",
        "goats", "going", "gorge", "gourd", "grace", "grade", "graft", "grain",
        "grand", "grant", "graph", "grasp", "grass", "grads", "grams", "great",
        "greed", "green", "greet", "grief", "grids", "grime", "grimy", "grind",
        "gripe", "grips", "groan", "grubs", "gruff", "group", "growl", "guild",
        "guile", "gulls", "gusto",
        // H
        "habit", "hands", "handy", "harsh", "haste", "haunt", "haven", "hawks",
        "hazes", "heaps", "heart", "heavy", "heels", "helms", "hence", "herbs",
        "herds", "heron", "hexes", "hills", "hinge", "hoist", "holly", "homey",
        "honor", "hooks", "hoops", "horse", "hosts", "hotel", "house", "hulks",
        "hulls", "human", "humid", "humor", "hunts", "hurry",
        // I
        "ideal", "image", "imply", "imbue", "impel", "indie", "inept", "inert",
        "infer", "ingot", "inner", "input", "irate", "irony", "issue", "ivory",
        // J
        "jacks", "jaded", "jails", "jazzy", "jewel", "jokes", "joint", "joker",
        "jolts", "judge", "jumbo", "jumps", "juicy", "junta",
        // K
        "kicks", "kilns", "knack", "knave", "kneel", "knelt", "knife", "knobs",
        "knock", "knots", "known",
        // L
        "lance", "lamps", "lanes", "lanky", "lapse", "large", "larks", "laser",
        "lathe", "later", "laugh", "lawns", "layer", "leaks", "leaps", "learn",
        "lease", "least", "leave", "ledge", "lemon", "lends", "level", "light",
        "limbo", "limit", "liner", "lingo", "links", "lists", "liver", "loans",
        "local", "locks", "lodge", "lofts", "logic", "loops", "loose", "lucky",
        "lunar", "lures", "lumps", "lurks",
        // M
        "magic", "maids", "major", "maker", "males", "malts", "manor", "manes",
        "maple", "march", "marks", "marsh", "masks", "match", "maxim", "mazes",
        "mealy", "meals", "media", "melts", "mercy", "metal", "might", "mimic",
        "minor", "minus", "mirth", "model", "modes", "moldy", "money", "month",
        "moods", "moons", "moral", "moose", "motel", "motor", "motto", "mouse",
        "mousy", "mulch", "mulls", "murky", "music", "musty", "myths",
        // N
        "nails", "naive", "napes", "nasal", "naval", "needy", "neigh", "nests",
        "nicks", "noble", "noise", "nooks", "norms", "north", "noted", "novel",
        "nurse", "nymph",
        // O
        "oaths", "occur", "ocean", "offer", "offal", "often", "oaken", "olden",
        "olive", "onset", "opera", "orate", "orbit", "order", "other", "ought",
        "outer", "owner", "oxide", "ozone",
        // P
        "packs", "palms", "panel", "panes", "panic", "paper", "parks", "patch",
        "paths", "pause", "pawns", "peace", "peaks", "pearl", "pedal", "peels",
        "penal", "penny", "perch", "perks", "pesky", "petty", "phase", "phone",
        "photo", "piano", "picks", "piece", "pilot", "pills", "pinch", "pipes",
        "pitch", "pixel", "pizza", "place", "plaid", "plain", "plane", "plank",
        "plant", "plate", "pleat", "plead", "plaza", "plods", "ploys", "plumb",
        "plush", "poach", "polar", "ponds", "pools", "poppy", "ports", "posts",
        "power", "prank", "press", "price", "pride", "prime", "print", "prior",
        "prism", "prize", "probe", "prods", "proms", "props", "prose", "proud",
        "prove", "pumps", "pulse", "punch", "pygmy",
        // Q
        "quaff", "qualm", "queen", "query", "queue", "quick", "quiet", "quilt",
        "quirk", "quota", "quote",
        // R
        "rabbi", "rabid", "racks", "raids", "rails", "ramps", "range", "ranks",
        "rapid", "reach", "react", "realm", "rebel", "reefs", "reins", "refer",
        "reign", "relax", "rents", "repay", "reply", "rhyme", "rider", "ridge",
        "right", "rigid", "rigor", "rings", "rinse", "risen", "risky", "rival",
        "river", "rivet", "roads", "roast", "robot", "rocky", "rogue", "rooms",
        "ropes", "rouge", "rough", "round", "route", "rowdy", "royal", "rugby",
        "ruins", "ruler", "rural",
        // S
        "sacks", "saint", "sails", "salad", "sales", "salts", "sands", "sauce",
        "saucy", "saves", "scale", "scalp", "scams", "scare", "scars", "scene",
        "scone", "scorn", "scope", "score", "scout", "seize", "sense", "serfs",
        "serve", "seven", "shade", "shall", "shame", "shank", "shape", "share",
        "shark", "sharp", "sheds", "sheer", "sheep", "sheet", "shelf", "shell",
        "shift", "shins", "ships", "shock", "short", "shots", "shout", "shuts",
        "shrub", "siege", "sight", "sides", "silky", "since", "sixth", "skids",
        "skill", "skimp", "skins", "skirt", "skunk", "slabs", "slant", "slash",
        "slate", "sleds", "sleek", "sleep", "slice", "slide", "slope", "slots",
        "slugs", "smart", "smash", "smear", "smile", "smoke", "snare", "sneer",
        "snide", "snobs", "snore", "soaks", "socks", "soggy", "soils", "solve",
        "sorry", "south", "space", "spans", "spare", "spark", "spawn", "speak",
        "speed", "spend", "spice", "spine", "spins", "spits", "spoke", "sport",
        "spots", "squad", "stabs", "stack", "staff", "stage", "stags", "stain",
        "stake", "stale", "stall", "stamp", "stand", "stare", "start", "stash",
        "state", "steal", "steam", "steel", "steep", "steer", "stems", "stern",
        "steps", "stick", "stiff", "still", "stock", "stomp", "stone", "stood",
        "stool", "stoop", "storm", "story", "stove", "strap", "stray", "strip",
        "strut", "stubs", "studs", "stuck", "study", "style", "suave", "sugar",
        "sulky", "suite", "sunny", "super", "surge", "swamp", "swaps", "swear",
        "sweet", "swept", "swims", "swift", "swoon", "sword", "swore", "sworn",
        // T
        "tales", "talks", "talon", "taint", "tangy", "tasks", "taunt", "tawny",
        "teach", "tease", "teeth", "tempo", "tense", "tenth", "tepid", "terms",
        "terse", "texts", "theft", "their", "theme", "there", "thick", "thing",
        "think", "third", "those", "thong", "thorn", "threw", "throw", "tides",
        "tiger", "tight", "tills", "timid", "timer", "tipsy", "tired", "title",
        "today", "token", "tones", "tools", "torso", "touch", "tough", "towel",
        "tower", "towns", "toxic", "trace", "track", "trade", "train", "trait",
        "tramp", "traps", "trash", "tread", "treat", "trend", "trial", "tribe",
        "trick", "tried", "tripe", "trite", "tromp", "troop", "truck", "truly",
        "trunk", "trust", "truth", "tucks", "tulip", "tumor", "tunes", "tusks",
        "twice", "twang", "tweak", "tweed", "twigs", "twist", "types",
        // U
        "udder", "ulcer", "under", "undue", "unify", "union", "units", "until",
        "upper", "urban", "usage", "usual", "utter",
        // V
        "vague", "valid", "valor", "valve", "value", "veins", "vents", "venue",
        "verge", "verse", "video", "vigor", "viral", "virus", "visit", "vista",
        "vivid", "vixen", "vocal", "vogue", "voice", "voter", "vouch",
        // W
        "wager", "walls", "waltz", "waste", "watch", "water", "weary", "wedge",
        "weird", "whale", "wheat", "wheel", "where", "whine", "which", "while",
        "white", "whole", "wider", "wield", "wimpy", "windy", "winks", "wires",
        "witch", "witty", "woman", "words", "world", "wordy", "worry", "worms",
        "worse", "worst", "worth", "would", "wound", "wring", "wrist", "wrong",
        // Y
        "yacht", "yards", "years", "yearn", "yield", "young", "youth", "yummy",
        // Z
        "zebra", "zippy", "zones"
    ]
}
