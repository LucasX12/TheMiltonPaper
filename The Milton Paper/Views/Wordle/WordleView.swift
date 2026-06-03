import SwiftUI

// MARK: - Main Page (embedded in ArticleFeedView's NavigationStack)

struct WordlePageView: View {
    @StateObject private var viewModel = WordleViewModel()
    @EnvironmentObject private var authViewModel: AuthViewModel
    @State private var showHelp = false
    @State private var showLeaderboard = false
    @State private var scoreSubmitted = false

    var body: some View {
        ZStack {
            Color.miltonBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                // Inline header
                HStack {
                    Button {
                        Task { await viewModel.loadLeaderboard() }
                        showLeaderboard = true
                    } label: {
                        Image(systemName: "list.number")
                            .font(.system(size: 18))
                            .foregroundColor(.miltonPrimary)
                    }

                    Spacer()

                    VStack(spacing: 2) {
                        Text("MORDLE")
                            .font(.custom("Georgia", size: 22).weight(.bold))
                            .foregroundColor(.miltonText)
                        if viewModel.phase == .playing {
                            Text(timeString(viewModel.elapsedSeconds))
                                .font(.system(size: 12, weight: .medium).monospacedDigit())
                                .foregroundColor(.miltonSecondary)
                        } else {
                            Text(viewModel.dateString)
                                .font(.miltonLabel)
                                .foregroundColor(.miltonSecondary)
                        }
                    }

                    Spacer()

                    Button { showHelp = true } label: {
                        Image(systemName: "questionmark.circle")
                            .font(.system(size: 18))
                            .foregroundColor(.miltonPrimary)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)

                Divider()

                // Error toast
                if let msg = viewModel.errorMessage {
                    Text(msg)
                        .font(.miltonCaption)
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(Color.black.opacity(0.78))
                        .cornerRadius(8)
                        .padding(.top, 6)
                        .transition(.opacity)
                }

                Spacer(minLength: 6)

                // Grid
                WordleGrid(viewModel: viewModel)

                Spacer(minLength: 10)

                // Keyboard
                if viewModel.phase == .playing {
                    WordleKeyboard(viewModel: viewModel)
                        .padding(.bottom, 8)
                }
            }

            // Cover overlay
            if viewModel.phase == .cover {
                WordleCoverOverlay(onStart: { viewModel.startGame() })
                    .transition(.opacity)
            }

            // Result card
            if viewModel.phase == .won || viewModel.phase == .lost {
                VStack {
                    Spacer()
                    WordleResultCard(
                        viewModel: viewModel,
                        isAuthenticated: authViewModel.isAuthenticated,
                        scoreSubmitted: scoreSubmitted
                    )
                    .padding(.horizontal, 28)
                    .padding(.bottom, 32)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            // Help overlay
            if showHelp {
                WordleHelpOverlay(onDismiss: { showHelp = false })
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: viewModel.phase)
        .animation(.easeInOut(duration: 0.2), value: showHelp)
        .animation(.easeInOut(duration: 0.2), value: viewModel.errorMessage != nil)
        .sheet(isPresented: $showLeaderboard) {
            WordleLeaderboardSheet(viewModel: viewModel)
        }
        .task(id: viewModel.phase) {
            guard viewModel.phase == .won || viewModel.phase == .lost,
                  !scoreSubmitted,
                  let user = authViewModel.currentUser else { return }
            viewModel.submitScore(uid: user.uid, displayName: user.displayName)
            scoreSubmitted = true
        }
    }

    private func timeString(_ s: Int) -> String {
        String(format: "%d:%02d", s / 60, s % 60)
    }
}

// MARK: - Cover Overlay

struct WordleCoverOverlay: View {
    let onStart: () -> Void

    private let exampleLetters = ["M", "O", "R", "D", "L"]
    private let exampleStates: [LetterState] = [.correct, .present, .absent, .empty, .empty]

    var body: some View {
        ZStack {
            Color.miltonBackground
                .ignoresSafeArea()

            VStack(spacing: 36) {
                VStack(spacing: 10) {
                    Text("MORDLE")
                        .font(.custom("Georgia", size: 42).weight(.bold))
                        .foregroundColor(.miltonText)

                    Text("Guess the 5-letter word of the day")
                        .font(.miltonCaption)
                        .foregroundColor(.miltonSecondary)
                        .multilineTextAlignment(.center)
                }

                HStack(spacing: 6) {
                    ForEach(exampleLetters.indices, id: \.self) { i in
                        WordleTile(letter: exampleLetters[i],
                                   state: exampleStates[i], size: 46)
                    }
                }

                Button(action: onStart) {
                    Text("Start")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 200, height: 52)
                        .background(Color.miltonPrimary)
                        .cornerRadius(13)
                }
            }
            .padding(.horizontal, 32)
        }
    }
}

// MARK: - Grid

struct WordleGrid: View {
    @ObservedObject var viewModel: WordleViewModel

    var body: some View {
        VStack(spacing: 5) {
            ForEach(0..<WordleViewModel.maxGuesses, id: \.self) { row in
                HStack(spacing: 5) {
                    ForEach(0..<WordleViewModel.wordLength, id: \.self) { col in
                        WordleTile(
                            letter: viewModel.grid[row][col].letter,
                            state:  viewModel.grid[row][col].state,
                            size:   50,
                            flipDelay: Double(col) * 0.12
                        )
                    }
                }
            }
        }
    }
}

// MARK: - Tile

struct WordleTile: View {
    let letter: String
    let state: LetterState
    let size: CGFloat
    var flipDelay: Double = 0

    @State private var revealed: LetterState
    @State private var flipAngle: Double = 0
    @State private var bounceScale: CGFloat = 1.0

    init(letter: String, state: LetterState, size: CGFloat, flipDelay: Double = 0) {
        self.letter = letter
        self.state = state
        self.size = size
        self.flipDelay = flipDelay
        _revealed = State(initialValue: state)
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 4)
                .fill(backgroundColor(for: revealed))
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(borderColor(for: revealed), lineWidth: 2)
                )
            if !letter.isEmpty {
                Text(letter)
                    .font(.custom("Georgia", size: size * 0.48).weight(.bold))
                    .foregroundColor(textColor(for: revealed))
            }
        }
        .frame(width: size, height: size)
        .scaleEffect(bounceScale)
        .rotation3DEffect(.degrees(flipAngle), axis: (x: 1, y: 0, z: 0))
        .onChange(of: letter) { newLetter in
            // Spring pop when a letter is typed
            guard !newLetter.isEmpty else { return }
            withAnimation(.spring(response: 0.1, dampingFraction: 0.5)) {
                bounceScale = 1.12
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.spring(response: 0.15, dampingFraction: 0.8)) {
                    bounceScale = 1.0
                }
            }
        }
        .onChange(of: state) { newState in
            guard newState == .correct || newState == .present || newState == .absent else {
                revealed = newState
                return
            }
            // Phase 1: ease-in fold to 90°
            DispatchQueue.main.asyncAfter(deadline: .now() + flipDelay) {
                withAnimation(.easeIn(duration: 0.2)) { flipAngle = 90 }
            }
            // Midpoint: swap colour, then ease-out unfold
            DispatchQueue.main.asyncAfter(deadline: .now() + flipDelay + 0.2) {
                revealed = newState
                withAnimation(.easeOut(duration: 0.2)) { flipAngle = 0 }
            }
        }
    }

    private func backgroundColor(for s: LetterState) -> Color {
        switch s {
        case .correct: return Color(hex: "#538d4e")
        case .present: return Color(hex: "#b59f3b")
        case .absent:  return Color(hex: "#3a3a3c")
        default:       return Color.miltonBackground
        }
    }

    private func borderColor(for s: LetterState) -> Color {
        switch s {
        case .correct:         return Color(hex: "#538d4e")
        case .present:         return Color(hex: "#b59f3b")
        case .absent:          return Color(hex: "#3a3a3c")
        case .tbd:             return Color.miltonSecondary
        case .empty, .unknown: return Color.miltonSecondary.opacity(0.3)
        }
    }

    private func textColor(for s: LetterState) -> Color {
        switch s {
        case .correct, .present, .absent: return .white
        default: return .miltonText
        }
    }
}

// MARK: - Keyboard

struct WordleKeyboard: View {
    @ObservedObject var viewModel: WordleViewModel

    private let rows: [[String]] = [
        ["Q","W","E","R","T","Y","U","I","O","P"],
        ["A","S","D","F","G","H","J","K","L"],
        ["ENTER","Z","X","C","V","B","N","M","⌫"]
    ]

    var body: some View {
        VStack(spacing: 6) {
            ForEach(rows, id: \.self) { row in
                HStack(spacing: 4) {
                    ForEach(row, id: \.self) { key in
                        WordleKeyButton(
                            key: key,
                            state: viewModel.letterStates[key] ?? .unknown,
                            action: { viewModel.pressKey(key) }
                        )
                    }
                }
            }
        }
        .padding(.horizontal, 6)
    }
}

struct WordleKeyButton: View {
    let key: String
    let state: LetterState
    let action: () -> Void

    private var isWide: Bool { key == "ENTER" || key == "⌫" }

    var body: some View {
        Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: 5)
                    .fill(keyColor)
                Text(key)
                    .font(.system(size: key == "ENTER" ? 10 : 14, weight: .semibold))
                    .foregroundColor(textColor)
                    .minimumScaleFactor(0.7)
            }
            .frame(width: isWide ? 48 : 31, height: 46)
        }
        .buttonStyle(.plain)
    }

    private var keyColor: Color {
        switch state {
        case .correct: return Color(hex: "#538d4e")
        case .present: return Color(hex: "#b59f3b")
        case .absent:  return Color(hex: "#3a3a3c")
        default:       return Color.miltonSecondary.opacity(0.22)
        }
    }

    private var textColor: Color {
        switch state {
        case .correct, .present, .absent: return .white
        default: return .miltonText
        }
    }
}

// MARK: - Result Card

struct WordleResultCard: View {
    @ObservedObject var viewModel: WordleViewModel
    let isAuthenticated: Bool
    let scoreSubmitted: Bool

    var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 6) {
                Text(viewModel.phase == .won ? "Brilliant!" : "Better luck next time")
                    .font(.miltonTitle)
                    .foregroundColor(.miltonText)
                if viewModel.phase == .lost {
                    Text("The word was \(viewModel.todayWord)")
                        .font(.miltonCaption)
                        .foregroundColor(.miltonSecondary)
                }
            }

            HStack(spacing: 40) {
                statView(label: "Guesses",
                         value: viewModel.phase == .won ? "\(viewModel.currentRow)" : "X")
                statView(label: "Time",
                         value: timeString(viewModel.elapsedSeconds))
            }

            if !isAuthenticated {
                Text("Sign in to appear on the leaderboard")
                    .font(.miltonCaption)
                    .foregroundColor(.miltonSecondary)
                    .multilineTextAlignment(.center)
            } else if scoreSubmitted {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(Color(hex: "#538d4e"))
                    Text("Score submitted!")
                        .font(.miltonCaption)
                        .foregroundColor(Color(hex: "#538d4e"))
                }
            }
        }
        .padding(24)
        .background(Color.miltonSurface)
        .cornerRadius(18)
        .shadow(color: Color.black.opacity(0.12), radius: 18, x: 0, y: 6)
    }

    @ViewBuilder
    private func statView(label: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.custom("Georgia", size: 34).weight(.bold))
                .foregroundColor(.miltonText)
            Text(label)
                .font(.miltonCaption)
                .foregroundColor(.miltonSecondary)
        }
    }

    private func timeString(_ s: Int) -> String {
        String(format: "%d:%02d", s / 60, s % 60)
    }
}

// MARK: - Help Overlay

struct WordleHelpOverlay: View {
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.45)
                .ignoresSafeArea()
                .onTapGesture { onDismiss() }

            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    Text("How to Play")
                        .font(.miltonTitle)
                        .foregroundColor(.miltonText)
                    Spacer()
                    Button(action: onDismiss) {
                        Image(systemName: "xmark")
                            .foregroundColor(.miltonSecondary)
                            .font(.system(size: 16, weight: .semibold))
                    }
                }

                Text("Guess the 5-letter word in 6 tries. After each guess, tiles change color:")
                    .font(.miltonBody)
                    .foregroundColor(.miltonText)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(alignment: .leading, spacing: 14) {
                    HelpExampleRow(
                        letter: "W", state: .correct,
                        description: "W is in the correct spot."
                    )
                    HelpExampleRow(
                        letter: "I", state: .present,
                        description: "I is in the word but in the wrong spot."
                    )
                    HelpExampleRow(
                        letter: "U", state: .absent,
                        description: "U is not in the word at all."
                    )
                }

                Text("A new word is available each day. Timer starts when you press Start.")
                    .font(.miltonCaption)
                    .foregroundColor(.miltonSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                Divider()

                Text("Mordle is inspired by Wordle by The New York Times.")
                    .font(.system(size: 11))
                    .foregroundColor(.miltonSecondary.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(24)
            .background(Color.miltonSurface)
            .cornerRadius(20)
            .padding(.horizontal, 20)
        }
    }
}

struct HelpExampleRow: View {
    let letter: String
    let state: LetterState
    let description: String

    var body: some View {
        HStack(spacing: 12) {
            WordleTile(letter: letter, state: state, size: 36)
            Text(description)
                .font(.miltonCaption)
                .foregroundColor(.miltonText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Leaderboard Sheet

struct WordleLeaderboardSheet: View {
    @ObservedObject var viewModel: WordleViewModel

    var body: some View {
        NavigationStack {
            ZStack {
                Color.miltonBackground.ignoresSafeArea()

                if viewModel.isLoadingLeaderboard {
                    LoadingView()
                } else if let error = viewModel.leaderboardError {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 44))
                            .foregroundColor(.miltonSecondary.opacity(0.4))
                        Text("Couldn't load scores")
                            .font(.miltonTitle)
                            .foregroundColor(.miltonSecondary)
                        Text(error)
                            .font(.miltonCaption)
                            .foregroundColor(.miltonSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                } else if viewModel.leaderboard.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "list.bullet.clipboard")
                            .font(.system(size: 44))
                            .foregroundColor(.miltonSecondary.opacity(0.4))
                        Text("No scores yet today")
                            .font(.miltonTitle)
                            .foregroundColor(.miltonSecondary)
                        Text("Be the first to play!")
                            .font(.miltonCaption)
                            .foregroundColor(.miltonSecondary)
                    }
                } else {
                    List(viewModel.leaderboard.indices, id: \.self) { index in
                        let score = viewModel.leaderboard[index]
                        HStack(spacing: 12) {
                            Text("#\(index + 1)")
                                .font(.system(size: 13, weight: .semibold).monospacedDigit())
                                .foregroundColor(medalColor(index))
                                .frame(width: 28, alignment: .leading)

                            Text(score.displayName)
                                .font(.miltonBody)
                                .foregroundColor(.miltonText)

                            Spacer()

                            VStack(alignment: .trailing, spacing: 2) {
                                Text(score.tries <= 6
                                     ? "\(score.tries)/6"
                                     : "X/6")
                                    .font(.system(size: 14, weight: .semibold).monospacedDigit())
                                    .foregroundColor(.miltonText)
                                Text(timeString(score.seconds))
                                    .font(.system(size: 12).monospacedDigit())
                                    .foregroundColor(.miltonSecondary)
                            }
                        }
                        .listRowBackground(Color.miltonSurface)
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Today's Leaderboard")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func medalColor(_ index: Int) -> Color {
        switch index {
        case 0: return Color(hex: "#b59f3b")
        case 1: return Color.miltonSecondary
        case 2: return Color(hex: "#b05a2f")
        default: return Color.miltonSecondary.opacity(0.6)
        }
    }

    private func timeString(_ s: Int) -> String {
        String(format: "%d:%02d", s / 60, s % 60)
    }
}
