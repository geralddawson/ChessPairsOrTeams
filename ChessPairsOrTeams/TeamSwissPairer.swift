import Foundation

/// Swiss pairing engine for team tournaments.
///
/// Rules implemented:
/// - Round 1: handled externally (seeded by rank 1–2, 3–4, ...).
/// - Rounds 2+: Pair by total board points (descending), with Swiss-style score groups and float-downs.
/// - Avoid rematches (teams must not meet more than once). If pairing becomes impossible without a repeat, the function will return as many pairs as possible and leave the rest unpaired.
/// - Bye: If odd number of teams, choose the team with the lowest total board points; on ties, the worse seed (higher ranking number). Never assign a second bye to the same team. Award `byeAward` board points to the bye team (the caller is responsible for recording that score externally).
/// - Colors: Home/away (board-1 color) alternates from the previous round where possible; if both teams were home or both away last round (or no history), the higher-ranked team (lower ranking number) gets the home draw.
struct TeamSwissPairer {
    /// Compute next-round pairings for teams using Swiss logic and constraints.
    /// - Parameters:
    ///   - teams: All teams eligible to be paired this round.
    ///   - priorRounds: Matches from previous rounds, in order (round 1 first).
    ///   - boardsPerMatch: Number of boards per match (used only to interpret results if needed by callers).
    ///   - resultsByMatchID: Accumulated board results for all prior matches (match id -> [boardIndex: ResultOption]). Used by callers to compute board scores; we don’t read it here to keep the engine pure.
    ///   - boardScores: A precomputed map of team id -> total board points so far. This is the primary basis for grouping.
    ///   - byeAward: Board points awarded for a bye in this round.
    ///   - byeTeamIDs: Teams that have already received a bye (to avoid a second bye).
    /// - Returns: Pairings (home vs away) for this round and an optional bye team.
    static func pairNextRound(
        teams: [Tournament.Team],
        priorRounds: [[Tournament.TeamMatch]],
        boardsPerMatch: Int,
        boardScores: [UUID: Double],
        byeAward: Double = 4.0,
        byeTeamIDs: Set<UUID> = []
    ) -> (matches: [Tournament.TeamMatch], bye: Tournament.Team?) {
        guard !teams.isEmpty else { return ([], nil) }

        // Derive past opponents set from all prior rounds
        var pastOpponents = Set<String>()
        for round in priorRounds {
            for m in round {
                let key = pairKey(m.home.id, m.away.id)
                pastOpponents.insert(key)
            }
        }

        // Determine last-round home teams for home/away alternation
        var wasHomeLastRound: Set<UUID> = []
        if let last = priorRounds.last {
            for m in last { wasHomeLastRound.insert(m.home.id) }
        }

        // Sort teams by score desc, then by seed (ranking asc)
        func score(_ t: Tournament.Team) -> Double { boardScores[t.id] ?? 0 }

        // Bye selection if odd count
        var pool = teams
        var bye: Tournament.Team? = nil
        if pool.count % 2 == 1 {
            let eligible = pool.filter { !byeTeamIDs.contains($0.id) }
            if let byeTeam = eligible.min(by: { lhs, rhs in
                let sL = score(lhs), sR = score(rhs)
                if sL != sR { return sL < sR } // lowest score first
                return lhs.ranking > rhs.ranking // worse seed (higher ranking number)
            }) {
                bye = byeTeam
                // Remove bye from pool
                if let idx = pool.firstIndex(where: { $0.id == byeTeam.id }) { pool.remove(at: idx) }
            }
        }

        // Group by score (descending)
        let grouped = Dictionary(grouping: pool, by: { score($0) })
        let sortedScores = grouped.keys.sorted(by: >)

        var floatDowns: [Tournament.Team] = []
        var pairs: [(Tournament.Team, Tournament.Team)] = []

        func havePlayed(_ a: Tournament.Team, _ b: Tournament.Team) -> Bool {
            pastOpponents.contains(pairKey(a.id, b.id))
        }

        var idx = 0
        while idx < sortedScores.count {
            let s = sortedScores[idx]
            var group = grouped[s] ?? []
            // Append float-downs from previous group
            group.append(contentsOf: floatDowns)
            floatDowns.removeAll()

            // Sort by seed (ranking asc)
            group.sort { $0.ranking < $1.ranking }

            // Split into top/bottom halves
            let half = group.count / 2
            let top = Array(group.prefix(half))
            var bottom = Array(group.suffix(from: half))

            // If odd count, float one from bottom to next group
            if group.count % 2 == 1, let floated = bottom.popLast() { floatDowns.append(floated) }

            // Greedy pairing within the group avoiding rematches
            var usedBottom = Set<Int>()
            var unpairedTop: [Tournament.Team] = []

            for t in top {
                var paired = false
                for (i, b) in bottom.enumerated() where !usedBottom.contains(i) {
                    if !havePlayed(t, b) {
                        pairs.append((t, b))
                        usedBottom.insert(i)
                        paired = true
                        break
                    }
                }
                if !paired {
                    unpairedTop.append(t)
                }
            }

            // Unused bottom half players also float down
            for (i, b) in bottom.enumerated() where !usedBottom.contains(i) { floatDowns.append(b) }
            // Unpaired top float down
            floatDowns.append(contentsOf: unpairedTop)

            idx += 1
        }

        // Attempt a global perfect matching fallback if we couldn't complete all pairs
        let expectedPairs = pool.count / 2
        var finalPairs = pairs
        if finalPairs.count < expectedPairs {
            if let perfect = findPerfectMatchingForAll(pool, avoiding: pastOpponents) {
                finalPairs = perfect
            } else {
                // No perfect matching without rematches exists; return partial pairs as-is
            }
        }

        // Convert pairs into TeamMatch with home/away assignment
        let lastHome = wasHomeLastRound
        let counts = homeAwayCounts(from: priorRounds)
        let applyLateBalancing = (priorRounds.count == 3 || priorRounds.count == 4) // entering Round 4 or 5 only
        let matches: [Tournament.TeamMatch] = finalPairs.map { (a, b) in
            // Prefer alternating home/away from last round
            let aWasHome = lastHome.contains(a.id)
            let bWasHome = lastHome.contains(b.id)
            var home: Tournament.Team
            var away: Tournament.Team
            if aWasHome != bWasHome {
                // The one who wasn’t home last round gets home now
                if aWasHome { home = b; away = a } else { home = a; away = b }
            } else {
                // Both same (or no history): higher-ranked (lower ranking number) gets home
                if a.ranking <= b.ranking { home = a; away = b } else { home = b; away = a }
            }

            // Late, minimal balancing: on entering Round 4 or 5, avoid a 4th same-side assignment
            if applyLateBalancing {
                let homeHomeCount = counts[home.id]?.home ?? 0
                let awayAwayCount = counts[away.id]?.away ?? 0
                if homeHomeCount >= 3 || awayAwayCount >= 3 {
                    swap(&home, &away)
                }
            }

            return Tournament.TeamMatch(home: home, away: away)
        }

        return (matches, bye)
    }

    /// Backtracking perfect matching across the entire pool avoiding past opponents. Returns nil if not possible.
    private static func findPerfectMatchingForAll(
        _ teams: [Tournament.Team],
        avoiding pastOpponents: Set<String>
    ) -> [(Tournament.Team, Tournament.Team)]? {
        if teams.count % 2 != 0 { return nil }
        if teams.isEmpty { return [] }
        var used = Set<Int>()
        func recur(_ soFar: [(Tournament.Team, Tournament.Team)]) -> [(Tournament.Team, Tournament.Team)]? {
            if soFar.count == teams.count / 2 { return soFar }
            guard let i = (0..<teams.count).first(where: { !used.contains($0) }) else { return nil }
            used.insert(i)
            let a = teams[i]
            for j in (i+1)..<teams.count where !used.contains(j) {
                let b = teams[j]
                if pastOpponents.contains(pairKey(a.id, b.id)) { continue }
                used.insert(j)
                if let result = recur(soFar + [(a, b)]) { return result }
                used.remove(j)
            }
            used.remove(i)
            return nil
        }
        return recur([])
    }

    private static func pairKey(_ a: UUID, _ b: UUID) -> String {
        a.uuidString < b.uuidString ? "\(a.uuidString)|\(b.uuidString)" : "\(b.uuidString)|\(a.uuidString)"
    }

    private static func homeAwayCounts(from rounds: [[Tournament.TeamMatch]]) -> [UUID: (home: Int, away: Int)] {
        var dict: [UUID: (home: Int, away: Int)] = [:]
        for round in rounds {
            for m in round {
                let h = dict[m.home.id]?.home ?? 0
                let a = dict[m.home.id]?.away ?? 0
                dict[m.home.id] = (home: h + 1, away: a)

                let h2 = dict[m.away.id]?.home ?? 0
                let a2 = dict[m.away.id]?.away ?? 0
                dict[m.away.id] = (home: h2, away: a2 + 1)
            }
        }
        return dict
    }
}

