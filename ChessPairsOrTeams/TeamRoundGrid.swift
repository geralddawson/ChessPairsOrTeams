import Foundation

enum TeamRoundGrid {
    /// Returns seed pairs for a given round index, sorted by table number then by home seed.
    /// Each element is a tuple (left, right) where `left` is the home team's seed (ranking) and `right` is the away team's seed.
    static func seedPairs(forRoundIndex r: Int, rounds: [[Tournament.TeamMatch]]) -> [(left: Int, right: Int)] {
        guard rounds.indices.contains(r) else { return [] }
        let roundMatches = rounds[r]
        let sorted = roundMatches.sorted { lhs, rhs in
            if lhs.tableNumber != rhs.tableNumber {
                return lhs.tableNumber < rhs.tableNumber
            } else {
                return lhs.home.ranking < rhs.home.ranking
            }
        }
        return sorted.map { (left: $0.home.ranking, right: $0.away.ranking) }
    }

    /// Returns the seed (ranking) of the bye team for a given round index if present.
    static func byeSeed(forRoundIndex r: Int, rounds: [[Tournament.TeamMatch]], tournament: Tournament) -> Int? {
        guard rounds.indices.contains(r) else { return nil }
        let roundMatches = rounds[r]
        var inMatches = Set<UUID>()
        for m in roundMatches { inMatches.insert(m.home.id); inMatches.insert(m.away.id) }
        if inMatches.count < tournament.teams.count {
            if let byeTeam = tournament.teams.first(where: { !inMatches.contains($0.id) }) {
                return byeTeam.ranking
            }
        }
        return nil
    }
}
