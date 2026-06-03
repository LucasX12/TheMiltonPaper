extension WordleViewModel {
    static let validWordSet: Set<String> = {
        var set = Set<String>()
        set.reserveCapacity(14855)
        for part in [_wordListPart1, _wordListPart2, _wordListPart3, _wordListPart4, _wordListPart5] {
            for word in part { set.insert(word) }
        }
        return set
    }()
}
