import Foundation

// MARK: - Team Match model for first-round Swiss pairings

struct TeamMatch: Identifiable {
    let id = UUID()
    let tableNumber: Int
    let higherRanked: Team
    let lowerRanked: Team
    // For first round, the higher-ranked team gets White on board 1; colours alternate by board.
    let higherIsWhiteOnBoard1: Bool = true

    struct BoardPairing: Identifiable {
        let id = UUID()
        let board: Int // 1-based
        let whiteName: String
        let blackName: String
    }

    func boardPairings(boards: Int = 4) -> [BoardPairing] {
        guard boards > 0 else { return [] }
        var result: [BoardPairing] = []
        for board in 1...boards {
            let idx = board - 1
            let higherWhite = (board % 2 == 1) == higherIsWhiteOnBoard1 // odd boards follow board 1 colour
            let white = higherWhite ? playerName(higherRanked, idx) : playerName(lowerRanked, idx)
            let black = higherWhite ? playerName(lowerRanked, idx) : playerName(higherRanked, idx)
            result.append(BoardPairing(board: board, whiteName: white, blackName: black))
        }
        return result
    }

    private func playerName(_ team: Team, _ index: Int) -> String {
        if index < team.players.count {
            let name = team.players[index]
            return name.isEmpty ? "—" : name
        }
        return "—"
    }
}

// MARK: - First round Swiss pairings by rank

/// Generates first round Swiss pairings based on team ranking.
/// - Parameter teams: All teams to be paired. Lower `ranking` value means higher seed.
/// - Returns: Matches (1 vs 2, 3 vs 4, ...) and an optional bye if the count is odd.
func generateFirstRoundSwissPairings(from teams: [Team]) -> (matches: [TeamMatch], bye: Team?) {
    // Sort ascending by ranking (1 is best)
    let sorted = teams.sorted { lhs, rhs in
        lhs.ranking < rhs.ranking
    }

    guard !sorted.isEmpty else { return ([], nil) }

    var working = sorted
    var byeTeam: Team? = nil

    if working.count % 2 == 1 {
        // Odd number of teams: the lowest-seeded team gets a bye in round 1.
        byeTeam = working.removeLast()
    }

    var matches: [TeamMatch] = []
    var table = 1
    var i = 0
    while i + 1 < working.count {
        let higher = working[i]
        let lower = working[i + 1]
        let match = TeamMatch(tableNumber: table, higherRanked: higher, lowerRanked: lower)
        matches.append(match)
        table += 1
        i += 2
    }

    return (matches, byeTeam)
}


