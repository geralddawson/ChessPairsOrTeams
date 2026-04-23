import Foundation

struct Tournament: Identifiable, Codable {
    struct Team: Identifiable, Equatable, Codable {
        let id: UUID
        let name: String
        let ranking: Int
        var players: [String]

        init(id: UUID = UUID(), name: String, ranking: Int, players: [String]) {
            self.id = id
            self.name = name
            self.ranking = ranking
            self.players = players
        }
    }

    struct TeamMatch: Identifiable, Equatable, Codable {
        let id: UUID
        let home: Team
        let away: Team

        init(id: UUID = UUID(), home: Team, away: Team) {
            self.id = id
            self.home = home
            self.away = away
        }
    }

    struct RoundPairings {
        let round: Int
        let matches: [TeamMatch]
    }

    let id: UUID
    var name: String
    var teams: [Team]
    var boardsPerMatch: Int

    init(id: UUID = UUID(), name: String, teams: [Team], boardsPerMatch: Int = 4) {
        self.id = id
        self.name = name
        self.teams = teams
        self.boardsPerMatch = boardsPerMatch
    }

    private static func generateFirstRoundSwissPairings(from teams: [Team]) -> RoundPairings {
        var matches: [TeamMatch] = []
        // Sort ascending by seed (1 is strongest)
        let sorted = teams.sorted { $0.ranking < $1.ranking }
        // If odd, remove the lowest seed as implicit bye for round 1
        let working: [Team]
        if sorted.count % 2 == 1 {
            working = Array(sorted.dropLast())
        } else {
            working = sorted
        }
        let half = working.count / 2
        // Pair top half vs bottom half: 1 vs half+1, 2 vs half+2, ...
        for i in 0..<half {
            let home = working[i]            // higher-ranked team (gets board 1 White)
            let away = working[half + i]
            matches.append(TeamMatch(home: home, away: away))
        }
        return RoundPairings(round: 1, matches: matches)
    }

    /// Returns team matches for a given round. For round 1, generate Swiss by rank using existing helper.
    func matches(forRound round: Int) -> [TeamMatch] {
        // For now, only implement round 1 using generateFirstRoundSwissPairings(from:)
        if round == 1 {
            return Self.generateFirstRoundSwissPairings(from: teams).matches
        } else {
            // Simple fallback: return first-round pairings for any round to keep UI functioning
            return Self.generateFirstRoundSwissPairings(from: teams).matches
        }
    }
}

extension Tournament {
    static let sample: Tournament = {
        let teamA = Tournament.Team(name: "Knights A", ranking: 1, players: ["Alice", "Bob", "Carol", "Dave"])
        let teamB = Tournament.Team(name: "Bishops B", ranking: 2, players: ["Eve", "Frank", "Grace", "Heidi"])
        let teamC = Tournament.Team(name: "Rooks C", ranking: 3, players: ["Ivan", "Judy", "Mallory", "Niaj"])
        let teamD = Tournament.Team(name: "Queens D", ranking: 4, players: ["Olivia", "Peggy", "Sybil", "Trent"])
        let teams = [teamA, teamB, teamC, teamD]
        return Tournament(name: "Sample Teams", teams: teams, boardsPerMatch: 4)
    }()
}
extension Tournament {
    /// Compute next-round Swiss pairings for teams using total board points and constraints.
    /// - Parameters:
    ///   - priorRounds: Matches from previous rounds in order (round 1 first).
    ///   - boardScores: Map of team id -> total board points so far.
    ///   - byeTeamIDs: Teams that have already received a bye (to avoid a second bye).
    ///   - byeAward: Board points awarded for a bye. Defaults to full boards per match.
    /// - Returns: Pairings (home vs away) for this round and an optional bye team.
    func swissPairNextRound(
        priorRounds: [[TeamMatch]],
        boardScores: [UUID: Double],
        byeTeamIDs: Set<UUID> = [],
        byeAward: Double? = nil
    ) -> (matches: [TeamMatch], bye: Team?) {
        let award = byeAward ?? Double(self.boardsPerMatch)
        return TeamSwissPairer.pairNextRound(
            teams: self.teams,
            priorRounds: priorRounds,
            boardsPerMatch: self.boardsPerMatch,
            boardScores: boardScores,
            byeAward: award,
            byeTeamIDs: byeTeamIDs
        )
    }
}



