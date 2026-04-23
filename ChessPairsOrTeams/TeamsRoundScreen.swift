import SwiftUI

#if os(macOS)
import AppKit
import UniformTypeIdentifiers
#endif

struct TeamsRoundScreen: View {
    let round: Int
    let tournament: Tournament
    @EnvironmentObject var teamsStore: TeamsStore
    @Environment(\.dismiss) private var dismiss
    @State private var matchResults: [UUID: [Int: ResultOption]] = [:]
    @State private var matches: [Tournament.TeamMatch] = []
    @State private var rounds: [[Tournament.TeamMatch]] = []
    @State private var currentRoundIndex: Int = 0
    @State private var byeTeamIDs: Set<UUID> = []
    @State private var showIncompleteAlert: Bool = false
    @State private var showPairingFailureAlert: Bool = false
    @State private var pairingFailureMessage: String = ""
    @State private var nameOverridesByMatch: [UUID: [Int: (white: String?, black: String?)]] = [:]
    @State private var lineupOverridesByTeam: [UUID: [Int: String]] = [:]
    @State private var benchReserves: [String] = []
    @State private var showEndTournamentConfirm: Bool = false
    @State private var showResultsSheet: Bool = false

    struct IndividualScore: Identifiable {
        let id: String
        let board: Int
        let name: String
        let teamName: String
        let score: Double
    }

    // MARK: - Extracted Panels to simplify the main body
    private struct StandingsPanel: View {
        let tournament: Tournament
        let rounds: [[Tournament.TeamMatch]]
        let reserves: [String]
        let scores: [UUID: Double]

        var body: some View {
            VStack(alignment: .leading, spacing: 8) {
                Text("Current Standings")
                    .font(.title2).bold()
                // Subheadings
                HStack {
                    Text("Rank")
                        .font(.headline)
                        .frame(width: 60, alignment: .leading)
                    Text("Team")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("Score")
                        .font(.headline)
                        .frame(width: 60, alignment: .trailing)
                }
                .padding(.vertical, 4)

                let orderedTeams: [Tournament.Team] = tournament.teams.sorted { lhs, rhs in
                    let s0: Double = scores[lhs.id] ?? 0.0
                    let s1: Double = scores[rhs.id] ?? 0.0
                    if s0 != s1 { return s0 > s1 }
                    return lhs.ranking < rhs.ranking
                }

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(orderedTeams, id: \.id) { team in
                            let teamScore: Double = scores[team.id] ?? 0.0
                            let formattedScore: String = String(format: "%.1f", teamScore)
                            HStack {
                                Text(String(team.ranking))
                                    .frame(width: 60, alignment: .leading)
                                Text(team.name)
                                    .lineLimit(1)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                Text(formattedScore)
                                    .frame(width: 60, alignment: .trailing)
                            }
                            .font(.body.monospaced())
                            .padding(8)
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }
                .frame(maxHeight: .infinity)
                .layoutPriority(1)

                if !reserves.isEmpty {
                    Text("Reserve Players")
                        .font(.headline)
                    LazyVStack(alignment: .leading, spacing: 6) {
                        ForEach(reserves, id: \.self) { name in
                            Text(name)
                                .lineLimit(1)
                                .truncationMode(.tail)
                                .padding(8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }

                Divider().padding(.vertical, 4)

                let enumeratedRounds = Array(rounds.enumerated())
                ScrollView([.horizontal, .vertical]) {
                    HStack(alignment: .top, spacing: 12) {
                        ForEach(enumeratedRounds, id: \.offset) { (index, _) in
                            VStack(alignment: .center, spacing: 6) {
                                Text("Round \(index + 1)")
                                    .font(.system(.headline, weight: .regular))
                                VStack(alignment: .center, spacing: 6) {
                                    ForEach(TeamRoundGrid.seedPairs(forRoundIndex: index, rounds: rounds), id: \.left) { pair in
                                        Text("\(pair.left)v\(pair.right)")
                                            .font(.body.monospaced())
                                            .padding(8)
                                            .frame(maxWidth: .infinity, alignment: .center)
                                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                                    }
                                    if let bye = TeamRoundGrid.byeSeed(forRoundIndex: index, rounds: rounds, tournament: tournament) {
                                        Text("Bye\(bye)")
                                            .font(.body.monospaced())
                                            .foregroundStyle(.secondary)
                                            .padding(8)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                                    }
                                }
                            }
                            .frame(width: 60, alignment: .top)
                        }
                    }
                }
                .frame(height: 200)
            }
        }
    }

    struct IndividualScoresPanel: View {
        let rows: [TeamsRoundScreen.IndividualScore]

        var body: some View {
            VStack(alignment: .leading, spacing: 8) {
                Text("Individual Scores")
                    .font(.title2).bold()

                HStack(spacing: 2) {
                    Text("Board")
                        .font(.headline)
                        .frame(width: 56, alignment: .center)
                    Text("Name")
                        .font(.headline)
                        .frame(width: 120, alignment: .leading)
                    Text("Team")
                        .font(.headline)
                        .frame(width: 140, alignment: .leading)
                    Text("Scores")
                        .font(.headline)
                        .frame(width: 50, alignment: .leading)
                }
                .padding(.vertical, 4)
                .padding(.leading, 8)

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(rows) { row in
                            HStack(spacing: 2) {
                                Text(String(row.board))
                                    .frame(width: 56, alignment: .center)
                                Text(row.name)
                                    .lineLimit(1)
                                    .frame(width: 120, alignment: .leading)
                                Text(row.teamName)
                                    .lineLimit(1)
                                    .frame(width: 140, alignment: .leading)
                                Text(String(format: "%.1f", row.score))
                                    .frame(width: 50, alignment: .leading)
                            }
                            .font(.body.monospaced())
                            .padding(8)
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }
            }
        }
    }

    var body: some View {
        HSplitView {
            // Left pane: Standings and Individual Scores side-by-side
            HStack(alignment: .top, spacing: 16) {
                // Current Standings (left column)
                StandingsPanel(
                    tournament: tournament,
                    rounds: rounds,
                    reserves: benchReserves,
                    scores: currentScores()
                )
                .padding(.leading, 12)
                .frame(width: 300, alignment: .topLeading)

                Divider()

                // Individual Scores (right column)
                IndividualScoresPanel(rows: currentIndividualScores())
                    .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .frame(minWidth: 320, maxWidth: .infinity, alignment: .topLeading)

            // Right: Matches with scoring controls
            ScrollView([.horizontal, .vertical]) {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(matches, id: \.id) { match in
                        TeamMatchCard(
                            match: match,
                            pairings: adjustedBoardPairings(for: match),
                            reserves: benchReserves,
                            boardResults: bindingForMatch(match.id),
                            onReplace: { board, isWhite, newName in
                                replacePlayer(matchID: match.id, board: board, isWhite: isWhite, newName: newName)
                            },
                            showScoringControls: true
                        )
                    }
                }
                .frame(minWidth: 700, maxWidth: .infinity, alignment: .topLeading)
                .padding([.trailing, .bottom])
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .navigationTitle("Round \(currentRoundIndex + 1)")
        .onAppear {
            let r1 = tournament.matches(forRound: 1)
            rounds = [r1]
            matches = r1
            currentRoundIndex = 0
            benchReserves = teamsStore.reserves
        }
        .onChange(of: currentRoundIndex) { _, _ in
            if rounds.indices.contains(currentRoundIndex) {
                matches = rounds[currentRoundIndex]
            }
        }
        .toolbar {
            ToolbarItem {
                Button("Previous Round") {
                    if currentRoundIndex > 0 { currentRoundIndex -= 1 }
                }
                .disabled(currentRoundIndex == 0)
            }
            ToolbarItem {
                Button("Next Round") {
                    if !isCurrentRoundComplete() {
                        showIncompleteAlert = true
                    } else {
                        generateNextRound()
                    }
                }
            }
            ToolbarItem {
                Button("End Tournament") {
                    showEndTournamentConfirm = true
                }
            }
        }
        .alert("Incomplete Results", isPresented: $showIncompleteAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Please enter results for all boards with two players before proceeding to the next round.")
        }
        .alert("Unable to Generate Next Round", isPresented: $showPairingFailureAlert) {
            Button("Show Results", role: .destructive) {
                showResultsSheet = true
            }
        } message: {
            Text(pairingFailureMessage)
        }
        .alert("End Tournament?", isPresented: $showEndTournamentConfirm) {
            Button("Cancel", role: .cancel) { }
            Button("Show Results", role: .destructive) {
                showResultsSheet = true
            }
        } message: {
            Text("Are you sure you want to end the tournament? You'll be shown the final results.")
        }
        .sheet(isPresented: $showResultsSheet) {
            TeamsResultsSheetView(
                tournament: tournament,
                rounds: rounds,
                scores: currentScores(),
                individualRows: currentIndividualScores(),
                onCloseTournament: { dismiss() }
            )
        }
    }

    // Helper to create a stable Binding for a match's board results
    private func bindingForMatch(_ id: UUID) -> Binding<[Int: ResultOption]> {
        Binding(
            get: { matchResults[id] ?? [:] },
            set: { matchResults[id] = $0 }
        )
    }

    // Create adjusted board pairings for a match, with control over whether to apply persistent lineup overrides
    private func adjustedBoardPairings(for match: Tournament.TeamMatch, includePersistentOverrides: Bool = true) -> [Tournament.TeamMatch.BoardPairing] {
        let base = match.boardPairings(boardsPerMatch: tournament.boardsPerMatch)
        let perMatchOverrides = nameOverridesByMatch[match.id] ?? [:]
        return base.map { bp in
            let homeIsWhite = (bp.board % 2 == 1)
            var whiteName = bp.whiteName
            var blackName = bp.blackName

            // Apply persistent lineup overrides by team/board only if requested (used for current/future rounds)
            if includePersistentOverrides {
                if let homeOverride = lineupOverridesByTeam[match.home.id]?[bp.board] {
                    if homeIsWhite { whiteName = homeOverride } else { blackName = homeOverride }
                }
                if let awayOverride = lineupOverridesByTeam[match.away.id]?[bp.board] {
                    if homeIsWhite { blackName = awayOverride } else { whiteName = awayOverride }
                }
            }

            // Then apply any per-match side overrides (specific to that match)
            if let ov = perMatchOverrides[bp.board] {
                if let w = ov.white { whiteName = w }
                if let b = ov.black { blackName = b }
            }

            return Tournament.TeamMatch.BoardPairing(
                board: bp.board,
                whiteName: whiteName,
                blackName: blackName
            )
        }
    }

    // Apply/clear a replacement for a given board and side
    private func replacePlayer(matchID: UUID, board: Int, isWhite: Bool, newName: String?) {
        // Find the match for this replacement
        var targetMatch: Tournament.TeamMatch?
        if let m = matches.first(where: { $0.id == matchID }) {
            targetMatch = m
        } else {
            for roundMatches in rounds {
                if let m = roundMatches.first(where: { $0.id == matchID }) {
                    targetMatch = m
                    break
                }
            }
        }

        // Helper functions to mutate the bench safely
        func addToBench(_ name: String?) {
            guard let n = name, !n.isEmpty, n != "—" else { return }
            if !benchReserves.contains(n) {
                benchReserves.append(n)
            }
        }
        func removeFromBench(_ name: String?) {
            guard let n = name, !n.isEmpty, n != "—" else { return }
            if let idx = benchReserves.firstIndex(of: n) {
                benchReserves.remove(at: idx)
            }
        }

        // Prepare overrides map
        var matchOverrides = nameOverridesByMatch[matchID] ?? [:]
        var entry = matchOverrides[board] ?? (white: nil, black: nil)

        // If we can find the match, derive the base player name and the team for this board/side
        var baseNameForSide: String = "—"
        var affectedTeamID: UUID?
        if let match = targetMatch {
            let basePairings = match.boardPairings(boardsPerMatch: tournament.boardsPerMatch)
            if let baseBP = basePairings.first(where: { $0.board == board }) {
                let homeIsWhite = (board % 2 == 1)
                baseNameForSide = isWhite ? baseBP.whiteName : baseBP.blackName
                if isWhite {
                    affectedTeamID = homeIsWhite ? match.home.id : match.away.id
                } else {
                    affectedTeamID = homeIsWhite ? match.away.id : match.home.id
                }
            }
        }

        // Determine the current occupant on this side (could be base or a previously seated reserve)
        var currentOccupant: String = "—"
        if let match = targetMatch {
            let adjusted = adjustedBoardPairings(for: match)
            if let bp = adjusted.first(where: { $0.board == board }) {
                currentOccupant = isWhite ? bp.whiteName : bp.blackName
            }
        }

        // If selecting the same player that's already seated, do nothing
        if let new = newName, !new.isEmpty, new == currentOccupant {
            return
        }

        // Apply bench logic and update overrides
        if let new = newName, !new.isEmpty {
            // Replacing with a reserve
            // Remove incoming reserve from bench
            removeFromBench(new)

            // Return the currently seated player (base or reserve) to the bench
            if currentOccupant != "—" && currentOccupant != new {
                addToBench(currentOccupant)
            }

            // Update per-match override
            if isWhite { entry.white = new } else { entry.black = new }

            // Update persistent lineup override for the team/board
            if let tid = affectedTeamID {
                var teamMap = lineupOverridesByTeam[tid] ?? [:]
                teamMap[board] = new
                lineupOverridesByTeam[tid] = teamMap
            }
        } else {
            // Clearing any replacement: base returns to board
            // Return whoever is currently seated to the bench
            if currentOccupant != "—" {
                addToBench(currentOccupant)
            }
            // Remove the base player from the bench, since they're back on the board
            removeFromBench(baseNameForSide)

            // Clear per-match override
            if isWhite { entry.white = nil } else { entry.black = nil }

            // Remove persistent lineup override for the team/board
            if let tid = affectedTeamID {
                var teamMap = lineupOverridesByTeam[tid] ?? [:]
                teamMap.removeValue(forKey: board)
                if teamMap.isEmpty {
                    lineupOverridesByTeam.removeValue(forKey: tid)
                } else {
                    lineupOverridesByTeam[tid] = teamMap
                }
            }
        }

        // Clean up overrides dictionary
        if entry.white == nil && entry.black == nil {
            matchOverrides.removeValue(forKey: board)
        } else {
            matchOverrides[board] = entry
        }
        if matchOverrides.isEmpty {
            nameOverridesByMatch.removeValue(forKey: matchID)
        } else {
            nameOverridesByMatch[matchID] = matchOverrides
        }
    }

    private func isCurrentRoundComplete() -> Bool {
        guard rounds.indices.contains(currentRoundIndex) else { return false }
        let roundMatches = rounds[currentRoundIndex]
        for match in roundMatches {
            let results = matchResults[match.id] ?? [:]
            for bp in adjustedBoardPairings(for: match) {
                // Only require a result if both players are present
                if bp.whiteName != "—" && bp.blackName != "—" {
                    guard let res = results[bp.board], res != ResultOption.none else {
                        return false
                    }
                }
            }
        }
        return true
    }

    private func generateNextRound() {
        // Compute cumulative board scores up to and including the current round
        let scores = cumulativeBoardScores()
        // Use prior rounds (all rounds so far) to avoid rematches and alternate home/away
        let prior = rounds
        let award = Double(tournament.boardsPerMatch)
        let result = tournament.swissPairNextRound(priorRounds: prior, boardScores: scores, byeTeamIDs: byeTeamIDs, byeAward: award)
        let newMatches = result.matches
        if let bye = result.bye {
            byeTeamIDs.insert(bye.id)
        }

        // Verify we have a complete set of pairings; if not, warn and end tournament
        let totalTeams = tournament.teams.count
        let expectedPairs = (totalTeams - (result.bye == nil ? 0 : 1)) / 2
        if newMatches.count < expectedPairs {
            pairingFailureMessage = "Unable to generate valid team pairings for the next round without repeating previous matchups. The tournament must end."
            showPairingFailureAlert = true
            return
        }

        // Append and advance
        rounds.append(newMatches)
        currentRoundIndex = rounds.count - 1
        matches = newMatches
    }

    private func cumulativeBoardScores() -> [UUID: Double] {
        var totals: [UUID: Double] = [:]
        // Iterate all rounds generated so far (up to currentRoundIndex)
        for roundMatches in rounds.prefix(currentRoundIndex + 1) {
            var teamIDsInMatches = Set<UUID>()
            for match in roundMatches {
                teamIDsInMatches.insert(match.home.id)
                teamIDsInMatches.insert(match.away.id)
                let results = matchResults[match.id] ?? [:]
                for bp in adjustedBoardPairings(for: match, includePersistentOverrides: false) {
                    guard let res = results[bp.board] else { continue }
                    let white = bp.whiteName
                    let black = bp.blackName
                    if white == "—" || black == "—" { continue }
                    let homeIsWhite = (bp.board % 2 == 1)
                    switch res {
                    case .whiteWin:
                        let winnerID = homeIsWhite ? match.home.id : match.away.id
                        totals[winnerID, default: 0] += 1
                    case .blackWin:
                        let winnerID = homeIsWhite ? match.away.id : match.home.id
                        totals[winnerID, default: 0] += 1
                    case .draw:
                        totals[match.home.id, default: 0] += 0.5
                        totals[match.away.id, default: 0] += 0.5
                    case .none:
                        break
                    }
                }
            }
            // Award bye points for this round to any team not appearing in matches
            if teamIDsInMatches.count < tournament.teams.count {
                let award = Double(tournament.boardsPerMatch)
                for t in tournament.teams where !teamIDsInMatches.contains(t.id) {
                    totals[t.id, default: 0] += award
                }
            }
        }
        return totals
    }

    private func currentIndividualScores() -> [IndividualScore] {
        // Accumulate individual scores across all rounds up to the current round
        struct Accum { var board: Int; var name: String; var teamName: String; var score: Double }
        var map: [String: Accum] = [:] // key: teamID|playerName

        // Seed with all roster players so they remain listed even if benched (retain prior scores)
        for team in tournament.teams {
            for (idx, player) in team.players.enumerated() {
                let name = player
                if name.isEmpty { continue }
                let key = "\(team.id.uuidString)|\(name)"
                if map[key] == nil {
                    map[key] = Accum(board: idx + 1, name: name, teamName: team.name, score: 0)
                }
            }
        }

        let roundsUpToNow = rounds.prefix(currentRoundIndex + 1)
        for roundMatches in roundsUpToNow {
            for match in roundMatches {
                for bp in adjustedBoardPairings(for: match, includePersistentOverrides: false) {
                    let board = bp.board
                    let white = bp.whiteName
                    let black = bp.blackName
                    // Only consider boards with two real players
                    if white != "—" && black != "—" {
                        let res = (matchResults[match.id] ?? [:])[board] ?? .none
                        // Determine teams by board parity (odd: home is white)
                        let homeIsWhite = (board % 2 == 1)
                        let whiteTeam = homeIsWhite ? match.home : match.away
                        let blackTeam = homeIsWhite ? match.away : match.home

                        let whiteKey = "\(whiteTeam.id.uuidString)|\(white)"
                        var whiteAccum = map[whiteKey] ?? Accum(board: board, name: white, teamName: whiteTeam.name, score: 0)
                        switch res {
                        case .whiteWin: whiteAccum.score += 1
                        case .draw: whiteAccum.score += 0.5
                        default: break
                        }
                        whiteAccum.board = board
                        whiteAccum.teamName = whiteTeam.name
                        map[whiteKey] = whiteAccum

                        let blackKey = "\(blackTeam.id.uuidString)|\(black)"
                        var blackAccum = map[blackKey] ?? Accum(board: board, name: black, teamName: blackTeam.name, score: 0)
                        switch res {
                        case .blackWin: blackAccum.score += 1
                        case .draw: blackAccum.score += 0.5
                        default: break
                        }
                        blackAccum.board = board
                        blackAccum.teamName = blackTeam.name
                        map[blackKey] = blackAccum
                    }
                }
            }
        }

        var rows: [IndividualScore] = map.map { key, acc in
            IndividualScore(id: key, board: acc.board, name: acc.name, teamName: acc.teamName, score: acc.score)
        }
        rows.sort { a, b in
            if a.score != b.score { return a.score > b.score }
            if a.board != b.board { return a.board < b.board }
            return a.name < b.name
        }
        return rows
    }

    private func currentScores() -> [UUID: Double] { cumulativeBoardScores() }

}

extension Tournament.TeamMatch {
    var higherRanked: Tournament.Team {
        return home.ranking <= away.ranking ? home : away
    }

    var lowerRanked: Tournament.Team {
        return home.ranking <= away.ranking ? away : home
    }
}

#Preview {
    TeamsRoundScreen(round: 1, tournament: Tournament.sample)
        .environmentObject(TeamsStore())
}
