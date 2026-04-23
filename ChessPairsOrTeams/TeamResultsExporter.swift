import Foundation

@MainActor struct TeamResultsExporter {
    // MARK: - Internal helpers
    private static func formatScore(_ value: Double) -> String {
        if value.truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%.0f", value)
        } else {
            return String(format: "%.1f", value)
        }
    }

    private static func csvEscape(_ field: String) -> String {
        let needsQuotes = field.contains(",") || field.contains("\"") || field.contains("\n")
        let escaped = field.replacingOccurrences(of: "\"", with: "\"\"")
        return needsQuotes ? "\"\(escaped)\"" : escaped
    }

    private static func csvRow(_ fields: [String]) -> String {
        fields.map(csvEscape).joined(separator: ",")
    }

    // MARK: - Public CSV generators
    static func generateCSVTeamPlacings(tournament: Tournament, scores: [UUID: Double]) -> String {
        let orderedTeams: [Tournament.Team] = tournament.teams.sorted { lhs, rhs in
            let s0: Double = scores[lhs.id] ?? 0.0
            let s1: Double = scores[rhs.id] ?? 0.0
            if s0 != s1 { return s0 > s1 }
            return lhs.ranking < rhs.ranking
        }
        var lines: [String] = []
        lines.append(csvRow(["Rank", "Team", "Score"]))
        for (idx, team) in orderedTeams.enumerated() {
            let teamScore: Double = scores[team.id] ?? 0.0
            let scoreStr = formatScore(teamScore)
            lines.append(csvRow(["\(idx + 1)", team.name, scoreStr]))
        }
        return lines.joined(separator: "\n") + "\n"
    }

    static func generateCSVIndividualScores(rows: [(board: Int, name: String, teamName: String, score: Double)]) -> String {
        var lines: [String] = []
        lines.append(csvRow(["Board", "Name", "Team", "Score"]))
        for row in rows {
            let scoreStr = formatScore(row.score)
            lines.append(csvRow(["\(row.board)", row.name, row.teamName, scoreStr]))
        }
        return lines.joined(separator: "\n") + "\n"
    }

    static func generateCSVCrossTable(rounds: [[Tournament.TeamMatch]]) -> String {
        var lines: [String] = []
        lines.append(csvRow(["Round", "Table", "Home", "Away", "HomeSeed", "AwaySeed"]))
        for (roundIndex, roundMatches) in rounds.enumerated() {
            let sorted = roundMatches.sorted { lhs, rhs in
                if lhs.tableNumber != rhs.tableNumber { return lhs.tableNumber < rhs.tableNumber }
                return lhs.home.ranking < rhs.home.ranking
            }
            for m in sorted {
                lines.append(csvRow([
                    "\(roundIndex + 1)",
                    "\(m.tableNumber)",
                    m.home.name,
                    m.away.name,
                    "\(m.home.ranking)",
                    "\(m.away.ranking)"
                ]))
            }
        }
        return lines.joined(separator: "\n") + "\n"
    }

    static func generateCSVCrossTableGrid(rounds: [[Tournament.TeamMatch]], tournament: Tournament) -> String {
        let roundCount = rounds.count
        var maxPairs = 0
        var hasAnyBye = false
        if roundCount > 0 {
            for idx in 0..<roundCount {
                let pairs = pairingsBySeed(forRoundIndex: idx, rounds: rounds)
                maxPairs = max(maxPairs, pairs.count)
                if byeSeed(forRoundIndex: idx, rounds: rounds, tournament: tournament) != nil { hasAnyBye = true }
            }
        }
        var lines: [String] = []
        // Header row
        var header: [String] = ["Table"]
        for idx in 0..<roundCount { header.append("Round \(idx + 1)") }
        lines.append(csvRow(header))
        // Rows for each table (pair index)
        if maxPairs > 0 {
            for table in 1...maxPairs {
                var row: [String] = ["\(table)"]
                for idx in 0..<roundCount {
                    let pairs = pairingsBySeed(forRoundIndex: idx, rounds: rounds)
                    if table - 1 < pairs.count {
                        let p = pairs[table - 1]
                        row.append("\(p.left)v\(p.right)")
                    } else {
                        row.append("—")
                    }
                }
                lines.append(csvRow(row))
            }
        }
        // Optional Bye row if any round has a bye
        if hasAnyBye {
            var row: [String] = ["Bye"]
            for idx in 0..<roundCount {
                if let bye = byeSeed(forRoundIndex: idx, rounds: rounds, tournament: tournament) {
                    row.append("Bye\(bye)")
                } else {
                    row.append("—")
                }
            }
            lines.append(csvRow(row))
        }
        return lines.joined(separator: "\n") + "\n"
    }

    static func generateCSVTeamPlacingsAndGrid(tournament: Tournament, rounds: [[Tournament.TeamMatch]], scores: [UUID: Double]) -> String {
        let placings = generateCSVTeamPlacings(tournament: tournament, scores: scores)
        let grid = generateCSVCrossTableGrid(rounds: rounds, tournament: tournament)
        return placings + "\n" + grid
    }

    // MARK: - Private helpers for grid
    private struct SeedPair { let left: Int; let right: Int }

    private static func pairingsBySeed(forRoundIndex r: Int, rounds: [[Tournament.TeamMatch]]) -> [SeedPair] {
        guard rounds.indices.contains(r) else { return [] }
        let roundMatches = rounds[r]
        let sorted = roundMatches.sorted { lhs, rhs in
            if lhs.tableNumber != rhs.tableNumber {
                return lhs.tableNumber < rhs.tableNumber
            } else {
                return lhs.home.ranking < rhs.home.ranking
            }
        }
        return sorted.map { SeedPair(left: $0.home.ranking, right: $0.away.ranking) }
    }

    private static func byeSeed(forRoundIndex r: Int, rounds: [[Tournament.TeamMatch]], tournament: Tournament) -> Int? {
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

