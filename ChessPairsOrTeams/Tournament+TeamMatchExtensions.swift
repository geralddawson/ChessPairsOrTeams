import Foundation

// Shared helpers for Tournament.TeamMatch accessible across the module
extension Tournament.TeamMatch {
    /// Derive a table number from rankings (pairs 1-2 -> table 1, 3-4 -> table 2, etc.)
    var tableNumber: Int {
        let minRank = min(home.ranking, away.ranking)
        return (minRank + 1) / 2
    }

    struct BoardPairing: Identifiable {
        let id = UUID()
        let board: Int
        let whiteName: String
        let blackName: String
    }

    /// Returns the board pairings (names) for this match. Home team is White on odd boards.
    func boardPairings(boardsPerMatch: Int = 4) -> [BoardPairing] {
        let limit = boardsPerMatch
        var result: [BoardPairing] = []
        for i in 0..<limit {
            let boardNum = i + 1
            // Home team is White on odd boards (1, 3, ...), Black on even boards (2, 4, ...)
            let homeIsWhite = (boardNum % 2 == 1)
            let whiteName: String
            let blackName: String
            if homeIsWhite {
                let w = i < home.players.count ? home.players[i] : ""
                let b = i < away.players.count ? away.players[i] : ""
                whiteName = w.isEmpty ? "—" : w
                blackName = b.isEmpty ? "—" : b
            } else {
                let w = i < away.players.count ? away.players[i] : ""
                let b = i < home.players.count ? home.players[i] : ""
                whiteName = w.isEmpty ? "—" : w
                blackName = b.isEmpty ? "—" : b
            }
            result.append(BoardPairing(board: boardNum, whiteName: whiteName, blackName: blackName))
        }
        return result
    }
}
