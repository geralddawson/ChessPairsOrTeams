//
//  FirstRoundDrawView.swift
//  ChessKit
//
//  Created by Gerald Dawson on 29/3/2026.
//

import SwiftUI

struct FirstRoundDrawView: View {
    @EnvironmentObject private var store: PlayersStore
    @State private var players: [Player] = []
    @State private var rounds: [[Pairing]] = []
    @State private var currentRoundIndex: Int = 0
    @State private var showFinalStandings = false
    // Tracking player rankings
    @State private var playersWithBye: Set<Int> = []
    @State private var showMissingResultsAlert = false
    @State private var showEndTournamentConfirmation = false
    @State private var showTournamentStopAlert = false
    @State private var tournamentStopMessage = ""

    private var sortedPlayers: [Player] {
        players.sorted {
            if $0.score != $1.score {
                return $0.score > $1.score
            } else {
                return $0.ranking < $1.ranking
            }
        }
    }

    private var currentByePlayerName: String? {
        if rounds.indices.contains(currentRoundIndex) {
            // Look for a pairing where boardLabel == "BYE" and the player is not "BYE"
            if let byePairing = rounds[currentRoundIndex].first(where: { $0.boardLabel == "BYE" }) {
                if byePairing.whitePlayer != "BYE" {
                    return byePairing.whitePlayer
                } else if byePairing.blackPlayer != "BYE" {
                    return byePairing.blackPlayer
                }
            }
        }
        return nil
    }

    /// see PairingEngine.findPerfectMatchingForAll(players:pastPairings:)

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                RoundedRectangle(cornerRadius: 48)
                    .fill(.ultraThinMaterial)
                    //.edgesIgnoringSafeArea(.all)
                    .shadow(color: Color.white.opacity(0.4), radius: 16, x: 0, y: 8)

                VStack {
                    // Wrap HStack with VStack and apply fixed maxWidth and center alignment
                    VStack {
                        HStack(alignment: .top, spacing: 40) {
                            PlayerRankingsView(players: sortedPlayers, byePlayerName: currentByePlayerName)
                                .frame(width: 250)

                            // Insert header text above the ScrollView wrapping RoundDrawView
                            VStack(alignment: .leading) {
                                Text("Draw for round \(currentRoundIndex + 1)")
                                    .font(.system(size: 40, weight: .bold))
                                    .shadow(color: .black.opacity(0.18), radius: 3, x: 0, y: 2)
                                    .padding(.bottom, 4)
                                
                                    ScrollView(.vertical) {
                                    VStack(spacing: 12) {
                                        if rounds.indices.contains(currentRoundIndex) {
                                            // Sort pairings so "BYE" boardLabel is always last before display
                                            // This ensures the BYE pairing always appears as bottom row
                                            let sortedPairings = rounds[currentRoundIndex].sorted { a, b in
                                                if a.boardLabel == "BYE" { return false }
                                                if b.boardLabel == "BYE" { return true }
                                                let extractNumber: (String) -> Int = { label in
                                                    Int(label.replacingOccurrences(of: "Board ", with: "")) ?? 0
                                                }
                                                return extractNumber(a.boardLabel) < extractNumber(b.boardLabel)
                                            }
                                            
                                            RoundDrawView(pairings: Binding(
                                                get: { sortedPairings },
                                                set: { newValue in
                                                    
                                                    var updatedRound = rounds[currentRoundIndex]

                                                    for newPair in newValue {
                                                        if let idx = updatedRound.firstIndex(where: { $0.id == newPair.id }) {
                                                            updatedRound[idx] = newPair
                                                        }
                                                    }
                                                    rounds[currentRoundIndex] = updatedRound
                                                }
                                            ))
                                                .padding(.top, 20)
                                                .padding(.trailing, 56)
                                                .padding(.leading, geometry.size.width * 0.07)
                                                // Apply glass effect background here
                                                .background(.ultraThinMaterial)
                                                .shadow(color: Color.white.opacity(0.4), radius: 16, x: 0, y: 8)
                                                .blur(radius: 0.3)
                                                // On change of pairings, update scores and regenerate rounds
                                                .onChange(of: rounds[currentRoundIndex]) { _, _ in
                                                    updatePlayerScoresAndRegenerateRounds(fromRound: currentRoundIndex)
                                                }
                                        }
                                    }
                                }
                                .frame(maxHeight: geometry.size.height * 0.85)
                            }

                        }
                        .frame(maxWidth: 1200, alignment: .center) // Fixed width and centered
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                }
                .frame(maxWidth: .infinity, alignment: .center)
             }
            .toolbar {
                ToolbarItem {
                    Button(action: {
                        if currentRoundIndex > 0 {
                            currentRoundIndex -= 1
                        }
                    }) {
                        Text("Previous Round")
                    }
                    .disabled(currentRoundIndex == 0)
                }
                ToolbarItem(placement: .principal) {
                    Button(action: {
                        showEndTournamentConfirmation = true
                    }) {
                        Text("End Tournament")
                            .font(.headline)
                            .foregroundColor(.red)
                    }
                }
                ToolbarItem {
                    Button(action: {
                        let incomplete = rounds.indices.contains(currentRoundIndex) && rounds[currentRoundIndex].contains { $0.result == .none && $0.boardLabel != "BYE" }
                        if incomplete {
                            showMissingResultsAlert = true
                            return
                        }
                        if currentRoundIndex == rounds.count - 1 {
                            generateNextRound()
                        } else {
                            currentRoundIndex += 1
                        }
                    }) {
                        Text("Next Round")
                    }
                    // No disabling on next since rounds can be generated on demand
                }
            }
        }
        .onAppear {
            loadPlayers()
            generateRounds()
            // Immediately assign 1 point for BYE players after rounds generated
            assignPointsForByes()
        }
        .sheet(isPresented: $showFinalStandings) {
            FinalStandingsView(players: sortedPlayers, rounds: rounds)
        }
       .alert("Are you sure you want to end the tournament?", isPresented: $showEndTournamentConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("End Tournament", role: .destructive) {
               showFinalStandings = true
            }
        } message: {
            Text("Ending the tournament will finalise the results. This action cannot be undone.")
        }
        .alert("Incomplete Results", isPresented: $showMissingResultsAlert) {
            Button("OK", role: .cancel) {}
        } message: {
           Text("Please enter results for all matches before proceeding to the next round.")
        }
        .alert("Unable to Generate Next Round", isPresented: $showTournamentStopAlert) {
            Button("End Tournament", role: .destructive) {
                showFinalStandings = true
            }
        } message: {
            Text(tournamentStopMessage)
        }
        .onReceive(store.$players) { _ in
            loadPlayers()
            generateRounds()
            assignPointsForByes()
        }
    }

    private func loadPlayers() {
        players = store.players.sorted { $0.ranking < $1.ranking }
    }

    private func generateRounds() {
        // Clear previous rounds
        rounds = []
        currentRoundIndex = 0
        // Reset BYE tracking at the start of a fresh tournament
        playersWithBye.removeAll()

        var playerList = sortedPlayers

        var pairings: [Pairing] = []

        var pastPairings = Set<String>()

        func canPair(_ p1: String, _ p2: String) -> Bool {
            let pairKey = p1 < p2 ? "\(p1)|\(p2)" : "\(p2)|\(p1)"
            return !pastPairings.contains(pairKey)
        }

        func addPairing(_ p1: String, _ p2: String) {
            let pairKey = p1 < p2 ? "\(p1)|\(p2)" : "\(p2)|\(p1)"
            pastPairings.insert(pairKey)
        }

        
        if playerList.count % 2 != 0 {
            // Select BYE for lowest score, highest ranking, HAS NOT already received a bye
            let eligibleForBye = playerList.filter { $0.name != "Spare Player" && !playersWithBye.contains($0.ranking) }
            if eligibleForBye.isEmpty {
                
                tournamentStopMessage = "No eligible players are available to receive a BYE for the first round. Every player has already had a BYE. The tournament cannot continue."
                showTournamentStopAlert = true
                return
            }
            let byePlayer = eligibleForBye.min {
                if $0.score != $1.score {
                    return $0.score < $1.score
                } else {
                    return $0.ranking > $1.ranking
                }
            }
            if let byePlayer = byePlayer {
                if let idx = playerList.firstIndex(where: { $0.id == byePlayer.id }) {
                    playerList.remove(at: idx)
                }
                // Assign exactly one BYE per round here
                pairings.append(Pairing(boardLabel: "BYE", whitePlayer: byePlayer.name, blackPlayer: "BYE", result: .none))
                playersWithBye.insert(byePlayer.ranking)
            }
        }

        let sortedByRanking = playerList.sorted { $0.ranking < $1.ranking }
        let half = sortedByRanking.count / 2
        for i in 0..<half {
            let top = sortedByRanking[i]
            let bottom = sortedByRanking[half + i]
            let blackPlayer: Player
            let whitePlayer: Player
            if top.ranking % 2 == 1 {
                blackPlayer = top
                whitePlayer = bottom
            } else {
                blackPlayer = bottom
                whitePlayer = top
            }
            // Replace random color assignment with helper function enforcing third consecutive white rule
            let assigned = assignColorsBetween(whitePlayer.name, blackPlayer.name, historyRounds: rounds)
            let (whiteAssigned, blackAssigned, whiteSwap, blackSwap) = assigned
            pairings.append(Pairing(boardLabel: "Board \(i + 1)", whitePlayer: whiteAssigned, blackPlayer: blackAssigned, result: .none, colorSwapApplied: whiteSwap, blackColorSwapApplied: blackSwap))
            addPairing(whitePlayer.name, blackPlayer.name)
        }
        rounds.append(pairings)
    }

    /// see PairingEngine.findPerfectPairing(players:pastPairings:)

    private func generateNextRound() {
        let playerList = players

        // Build pastPairings set from all previous rounds
        var pastPairings = Set<String>()
        func addPairing(_ p1: String, _ p2: String) {
            let pairKey = p1 < p2 ? "\(p1)|\(p2)" : "\(p2)|\(p1)"
            pastPairings.insert(pairKey)
        }
        for round in rounds {
            for pairing in round {
                if pairing.blackPlayer != "BYE" {
                    addPairing(pairing.whitePlayer, pairing.blackPlayer)
                }
            }
        }

        var playerListMutable = playerList

        // Array to hold pairings for this round
        var pairings: [Pairing] = []

        // When odd number of players, assign BYE player first (exactly one)
        if playerListMutable.count % 2 != 0 {
            let eligibleForBye = playerListMutable.filter { $0.name != "Spare Player" && !playersWithBye.contains($0.ranking) }
            if eligibleForBye.isEmpty {
                tournamentStopMessage = "No eligible players are available to receive a BYE. Every player has already had a BYE. The tournament cannot continue."
                showTournamentStopAlert = true
                return
            }
            if let byePlayer = eligibleForBye.min(by: {
                if $0.score != $1.score {
                    return $0.score < $1.score
                } else {
                    return $0.ranking > $1.ranking
                }
            }) {
                if let idx = playerListMutable.firstIndex(where: { $0.id == byePlayer.id }) {
                    playerListMutable.remove(at: idx)
                }
                // Assign exactly one BYE here
                pairings.append(Pairing(boardLabel: "BYE", whitePlayer: byePlayer.name, blackPlayer: "BYE", result: .none))
                playersWithBye.insert(byePlayer.ranking)
            }
        }

        // -- START Swiss-style score-grouped pairing logic (primary method) --

        var boardNumber = 1

        // Group players by score (descending)
        let groupedByScore = Dictionary(grouping: playerListMutable) { $0.score }
        let sortedScores = groupedByScore.keys.sorted(by: >)

        // Store float-down players to add to next group
        var floatDowns: [Player] = []

        // Helper to find if two players have played before
        func havePlayed(_ p1: Player, _ p2: Player) -> Bool {
            let pairKey = p1.name < p2.name ? "\(p1.name)|\(p2.name)" : "\(p2.name)|\(p1.name)"
            return pastPairings.contains(pairKey)
        }

        // Start pairing by score groups
        var index = 0
        while index < sortedScores.count {
            let score = sortedScores[index]
            var groupPlayers = groupedByScore[score] ?? []
            // Add floatDowns from previous group
            groupPlayers.append(contentsOf: floatDowns)
            floatDowns = []

            // Sort group players by ranking ascending
            groupPlayers.sort { $0.ranking < $1.ranking }

            // Split into top half and bottom half for pairing
            let halfCount = groupPlayers.count / 2
            let topHalf = Array(groupPlayers.prefix(halfCount))
            var bottomHalf = Array(groupPlayers.suffix(from: halfCount))

            // If odd number, bottom half gets the extra player as floatDown candidate
            if groupPlayers.count % 2 != 0 {
                // Float the last bottomHalf player down to next group
                if let floatedPlayer = bottomHalf.last {
                    floatDowns.append(floatedPlayer)
                    bottomHalf.removeLast()
                }
            }

            // Attempt to pair topHalf[i] with bottomHalf[i], skip if pairing exists
            // If pairing exists, try to find an alternative in bottomHalf for that top player,
            // if none found, float that top player down to next group.
            var usedBottomIndices = Set<Int>()
            var unpairedTopPlayers: [Player] = []

            for topPlayer in topHalf {
                var paired = false
                for (bottomIndex, bottomPlayer) in bottomHalf.enumerated() where !usedBottomIndices.contains(bottomIndex) {
                    if !havePlayed(topPlayer, bottomPlayer) {
                        let assigned = assignColorsBetween(topPlayer.name, bottomPlayer.name, historyRounds: rounds)
                        let (whiteAssigned, blackAssigned, whiteSwap, blackSwap) = assigned
                        pairings.append(Pairing(boardLabel: "Board \(boardNumber)", whitePlayer: whiteAssigned, blackPlayer: blackAssigned, result: .none, colorSwapApplied: whiteSwap, blackColorSwapApplied: blackSwap))
                        boardNumber += 1
                        usedBottomIndices.insert(bottomIndex)
                        paired = true
                        break
                    }
                }
                if !paired {
                    // Could not find a suitable bottom half player to pair with topPlayer, float down topPlayer
                    unpairedTopPlayers.append(topPlayer)
                }
            }

            // Add unpaired top players to floatDowns to be included in the next lower score group
            floatDowns.append(contentsOf: unpairedTopPlayers)

            // Add all unused bottom half players to floatDowns as well (since they remain unpaired in this group)
            for (bottomIndex, bottomPlayer) in bottomHalf.enumerated() {
                if !usedBottomIndices.contains(bottomIndex) {
                    floatDowns.append(bottomPlayer)
                }
            }

            index += 1
        }

        // After Swiss attempt, check if any players remain unpaired
        // Total players that should be paired (excluding BYE) is playerListMutable.count
        let expectedPairingsCount = playerListMutable.count / 2
        let swissPairingsCount = pairings.filter { $0.boardLabel != "BYE" }.count

        if !floatDowns.isEmpty || swissPairingsCount < expectedPairingsCount {
            
            if let perfect = PairingEngine.findPerfectMatchingForAll(players: playerListMutable, pastPairings: pastPairings) {
                // Clear existing Swiss pairings (except BYE)
                pairings.removeAll(where: { $0.boardLabel != "BYE" })

                var boardNumberGlobal = 1
                for (p1, p2) in perfect {
                    let assigned = assignColorsBetween(p1.name, p2.name, historyRounds: rounds)
                    let (whiteAssigned, blackAssigned, whiteSwap, blackSwap) = assigned
                    pairings.append(Pairing(boardLabel: "Board \(boardNumberGlobal)", whitePlayer: whiteAssigned, blackPlayer: blackAssigned, result: .none, colorSwapApplied: whiteSwap, blackColorSwapApplied: blackSwap))
                    boardNumberGlobal += 1
                    addPairing(p1.name, p2.name)
                }
            } else {
                
                // Remove any non-BYE pairings as they are partial or invalid
                pairings.removeAll(where: { $0.boardLabel != "BYE" })

                // Use floatDowns collected so far plus all playerListMutable (all non-BYE players) since Swiss partially failed
                let floatDownPlayers = playerListMutable

                // Try pairing floatDown players themselves with no repeats
                if !floatDownPlayers.isEmpty {
                    tournamentStopMessage = "Unable to generate valid pairings for the next round without repeating previous matchups. The tournament must end."
                    showTournamentStopAlert = true
                    return
                }
            }
        }
        // -- END pairing logic --

        let nonByeCount = pairings.filter { $0.boardLabel != "BYE" }.count
        if nonByeCount < expectedPairingsCount {
            tournamentStopMessage = "Unable to generate a complete set of pairings for the next round without repeats. The tournament must end."
            showTournamentStopAlert = true
            return
        } else {
            rounds.append(pairings)
            currentRoundIndex = rounds.count - 1
            // After generating the new round, immediately assign 1 point for any BYE players in that round
            assignPointsForByes()
        }
    }

    private func updatePlayerScoresAndRegenerateRounds(fromRound changedRound: Int) {
        // 1. Aggregate results from all rounds up to changedRound to update player scores
        var updatedPlayers = players

        // Reset all scores
        for i in updatedPlayers.indices {
            updatedPlayers[i].score = 0.0
        }

        // Helper dictionary for quick name -> index lookup
        let nameToIndex = Dictionary(uniqueKeysWithValues: updatedPlayers.enumerated().map { ($1.name, $0) })

        // Accumulate scores from rounds up to and including changedRound
        for roundIndex in 0...changedRound {
            guard rounds.indices.contains(roundIndex) else { continue }
            for pairing in rounds[roundIndex] {
                // Automatically award 1 point to player receiving a BYE (no user interaction needed)
                // This ensures BYE points are considered immediately regardless of result changes
                // NOTE: playersWithBye is NOT updated here to prevent multiple BYEs assigned to same player
                if pairing.whitePlayer == "BYE" && pairing.blackPlayer != "BYE" {
                    if let blackIdx = nameToIndex[pairing.blackPlayer] {
                        updatedPlayers[blackIdx].score += 1.0
                    }
                } else if pairing.blackPlayer == "BYE" && pairing.whitePlayer != "BYE" {
                    if let whiteIdx = nameToIndex[pairing.whitePlayer] {
                        updatedPlayers[whiteIdx].score += 1.0
                    }
                } else {
                    guard
                        let whiteIdx = nameToIndex[pairing.whitePlayer],
                        let blackIdx = nameToIndex[pairing.blackPlayer]
                    else {
                        continue
                    }

                    switch pairing.result {
                    case .whiteWin:
                        updatedPlayers[whiteIdx].score += 1.0
                    case .blackWin:
                        updatedPlayers[blackIdx].score += 1.0
                    case .draw:
                        updatedPlayers[whiteIdx].score += 0.5
                        updatedPlayers[blackIdx].score += 0.5
                    case .none:
                        break
                    }
                }
            }
        }

        // Update the players with recalculated scores
        players = updatedPlayers.sorted {
            if $0.score != $1.score {
                return $0.score > $1.score
            } else {
                return $0.ranking < $1.ranking
            }
        }

        // 2. Regenerate rounds AFTER changedRound, preserving results of previous rounds
        guard rounds.count > changedRound + 1 else {
            // No subsequent rounds to regenerate
            return
        }

        // We'll generate new rounds from the updated players for rounds after changedRound
        // Keep rounds up to changedRound
        var newRounds: [[Pairing]] = Array(rounds.prefix(changedRound + 1))

        let playerList = players

        // Rebuild pastPairings set from all previous rounds (up to changedRound)
        var pastPairings = Set<String>()

        func addPairing(_ p1: String, _ p2: String) {
            let pairKey = p1 < p2 ? "\(p1)|\(p2)" : "\(p2)|\(p1)"
            pastPairings.insert(pairKey)
        }

        // Collect past pairings from all rounds up to changedRound
        for roundIndex in 0...changedRound {
            guard rounds.indices.contains(roundIndex) else { continue }
            for pairing in rounds[roundIndex] {
                if pairing.blackPlayer != "BYE" {
                    addPairing(pairing.whitePlayer, pairing.blackPlayer)
                }
            }
        }

        for roundIndex in (changedRound + 1)..<rounds.count {
            var pairings: [Pairing] = []
            let boardCount = 1

            var playerListMutable = playerList

            if roundIndex == 0 {
                // When odd number of players, assign BYE to player with lowest score, and if tie, highest ranking integer
                if playerListMutable.count % 2 != 0 {
                    let eligibleForBye = playerListMutable.filter { $0.name != "Spare Player" && !playersWithBye.contains($0.ranking) }
                    if eligibleForBye.isEmpty {
                        #if DEBUG
                        print("ERROR: No eligible players for BYE in regenerated round \(roundIndex). All players have already had a bye. Round cannot be generated.")
                        // Diagnostic debug prints:
                        print("[DEBUG] All player rankings:", players.map { $0.ranking })
                        print("[DEBUG] playersWithBye:", playersWithBye.sorted())
                        print("[DEBUG] playerList rankings:", playerListMutable.map { $0.ranking })
                        let unpairedRealPlayers = playerListMutable.filter { $0.name != "Spare Player" }
                        print("[DEBUG] unpaired real players:", unpairedRealPlayers.map { $0.ranking })
                        print("[DEBUG] eligibleForBye:", eligibleForBye.map { $0.ranking })
                        #endif
                        return
                    }
                    if let byePlayer = eligibleForBye.min(by: {
                        if $0.score != $1.score {
                            return $0.score < $1.score
                        } else {
                            return $0.ranking > $1.ranking
                        }
                    }) {
                        if let idx = playerListMutable.firstIndex(where: { $0.id == byePlayer.id }) {
                            playerListMutable.remove(at: idx)
                        }
                        // Assign exactly one BYE here
                        pairings.append(Pairing(boardLabel: "BYE", whitePlayer: byePlayer.name, blackPlayer: "BYE", result: .none))
                        playersWithBye.insert(byePlayer.ranking)
                    }
                }

                let expectedPairingsCount = playerListMutable.count / 2

                // -- START Swiss-style score-grouped pairing logic for regenerated round zero

                var boardNumberSwiss = 1

                let groupedByScore = Dictionary(grouping: playerListMutable) { $0.score }
                let sortedScores = groupedByScore.keys.sorted(by: >)

                var floatDowns: [Player] = []

                func havePlayed(_ p1: Player, _ p2: Player) -> Bool {
                    let pairKey = p1.name < p2.name ? "\(p1.name)|\(p2.name)" : "\(p2.name)|\(p1.name)"
                    return pastPairings.contains(pairKey)
                }

                var indexSwiss = 0
                var tempPairings: [Pairing] = []

                while indexSwiss < sortedScores.count {
                    let score = sortedScores[indexSwiss]
                    var groupPlayers = groupedByScore[score] ?? []
                    groupPlayers.append(contentsOf: floatDowns)
                    floatDowns = []

                    groupPlayers.sort { $0.ranking < $1.ranking }

                    let halfCount = groupPlayers.count / 2
                    let topHalf = Array(groupPlayers.prefix(halfCount))
                    var bottomHalf = Array(groupPlayers.suffix(from: halfCount))

                    if groupPlayers.count % 2 != 0 {
                        if let floatedPlayer = bottomHalf.last {
                            floatDowns.append(floatedPlayer)
                            bottomHalf.removeLast()
                        }
                    }

                    var usedBottomIndices = Set<Int>()
                    var unpairedTopPlayers: [Player] = []

                    for topPlayer in topHalf {
                        var paired = false
                        for (bottomIndex, bottomPlayer) in bottomHalf.enumerated() where !usedBottomIndices.contains(bottomIndex) {
                            if !havePlayed(topPlayer, bottomPlayer) {
                                let assigned = assignColorsBetween(topPlayer.name, bottomPlayer.name, historyRounds: newRounds)
                                let (whiteAssigned, blackAssigned, whiteSwap, blackSwap) = assigned
                                tempPairings.append(Pairing(boardLabel: "Board \(boardNumberSwiss)", whitePlayer: whiteAssigned, blackPlayer: blackAssigned, result: .none, colorSwapApplied: whiteSwap, blackColorSwapApplied: blackSwap))
                                boardNumberSwiss += 1
                                usedBottomIndices.insert(bottomIndex)
                                paired = true
                                break
                            }
                        }
                        if !paired {
                            unpairedTopPlayers.append(topPlayer)
                        }
                    }

                    floatDowns.append(contentsOf: unpairedTopPlayers)

                    for (bottomIndex, bottomPlayer) in bottomHalf.enumerated() {
                        if !usedBottomIndices.contains(bottomIndex) {
                            floatDowns.append(bottomPlayer)
                        }
                    }

                    indexSwiss += 1
                }

                let swissPairingsCount = tempPairings.count

                // Decide if fallback to global perfect matching needed
                if !floatDowns.isEmpty || swissPairingsCount < expectedPairingsCount {
                    
                    // Try global perfect matching for all non-BYE players
                    if let perfect = PairingEngine.findPerfectMatchingForAll(players: playerListMutable, pastPairings: pastPairings) {
                        var boardNumGlobal = 1
                        for (p1, p2) in perfect {
                            let assigned = assignColorsBetween(p1.name, p2.name, historyRounds: newRounds)
                            let (whiteAssigned, blackAssigned, whiteSwap, blackSwap) = assigned
                            pairings.append(Pairing(boardLabel: "Board \(boardNumGlobal)", whitePlayer: whiteAssigned, blackPlayer: blackAssigned, result: .none, colorSwapApplied: whiteSwap, blackColorSwapApplied: blackSwap))
                            addPairing(p1.name, p2.name)
                            boardNumGlobal += 1
                        }
                    } else {
                        // Fallback to floatDowns pairing logic as last resort
                        if !playerListMutable.isEmpty {
                            if let perfect = PairingEngine.findPerfectPairing(players: playerListMutable, pastPairings: pastPairings) {
                                var boardNumFloat = 1
                                for (p1, p2) in perfect {
                                    let assigned = assignColorsBetween(p1.name, p2.name, historyRounds: newRounds)
                                    let (whiteAssigned, blackAssigned, whiteSwap, blackSwap) = assigned
                                    pairings.append(Pairing(boardLabel: "Board \(boardNumFloat)", whitePlayer: whiteAssigned, blackPlayer: blackAssigned, result: .none, colorSwapApplied: whiteSwap, blackColorSwapApplied: blackSwap))
                                    boardNumFloat += 1
                                }
                            } else {
                                #if DEBUG
                                print("[ERROR] Could not pair all floatDowns without repeats in regenerated round zero (\(playerListMutable.count) left)")
                                #endif
                            }
                        }
                    }
                } else {
                    
                    // Swiss pairing succeeded fully, use Swiss pairings
                    pairings.append(contentsOf: tempPairings)
                }

                // -- END regenerated round zero pairing logic --

               } else {
                   
                // Subsequent rounds: use updated Swiss pairing with score groups and float down logic
                   // When odd number of players, assign BYE player first (exactly one)
                   
                if playerListMutable.count % 2 != 0 {
                    let eligibleForBye = playerListMutable.filter { $0.name != "Spare Player" && !playersWithBye.contains($0.ranking) }
                    if eligibleForBye.isEmpty {
                        #if DEBUG
                        print("ERROR: No eligible players for BYE in regenerated round \(roundIndex). All players have already had a bye. Round cannot be generated.")
                        // Diagnostic debug prints:
                        print("[DEBUG] All player rankings:", players.map { $0.ranking })
                        print("[DEBUG] playersWithBye:", playersWithBye.sorted())
                        print("[DEBUG] realPlayers:", playerListMutable.filter { $0.name != "Spare Player" }.map { $0.ranking })
                        print("[DEBUG] eligibleForBye:", eligibleForBye.map { $0.ranking })
                        #endif
                        return
                    }
                    if let byePlayer = eligibleForBye.min(by: {
                        if $0.score != $1.score {
                            return $0.score < $1.score
                        } else {
                            return $0.ranking > $1.ranking
                        }
                    }) {
                        if let idx = playerListMutable.firstIndex(where: { $0.id == byePlayer.id }) {
                            playerListMutable.remove(at: idx)
                        }
                        // Assign exactly one BYE here
                        pairings.append(Pairing(boardLabel: "BYE", whitePlayer: byePlayer.name, blackPlayer: "BYE", result: .none))
                        playersWithBye.insert(byePlayer.ranking)
                    }
                }

                let expectedPairingsCount = playerListMutable.count / 2

                // -- START Swiss-style score-grouped pairing logic for regenerated subsequent rounds (primary method) --

                let groupedByScore = Dictionary(grouping: playerListMutable) { $0.score }
                let sortedScores = groupedByScore.keys.sorted(by: >)

                var floatDowns: [Player] = []
                var boardNum = boardCount

                func havePlayed(_ p1: Player, _ p2: Player) -> Bool {
                    let pairKey = p1.name < p2.name ? "\(p1.name)|\(p2.name)" : "\(p2.name)|\(p1.name)"
                    return pastPairings.contains(pairKey)
                }

                var idx = 0
                var tempPairings: [Pairing] = []

                while idx < sortedScores.count {
                    let score = sortedScores[idx]
                    var groupPlayers = groupedByScore[score] ?? []
                    groupPlayers.append(contentsOf: floatDowns)
                    floatDowns = []

                    groupPlayers.sort { $0.ranking < $1.ranking }

                    let halfCount = groupPlayers.count / 2
                    let topHalf = Array(groupPlayers.prefix(halfCount))
                    var bottomHalf = Array(groupPlayers.suffix(from: halfCount))

                    if groupPlayers.count % 2 != 0 {
                        if let floatedPlayer = bottomHalf.last {
                            floatDowns.append(floatedPlayer)
                            bottomHalf.removeLast()
                        }
                    }

                    var usedBottomIndices = Set<Int>()
                    var unpairedTopPlayers: [Player] = []

                    for topPlayer in topHalf {
                        var paired = false
                        for (bottomIndex, bottomPlayer) in bottomHalf.enumerated() where !usedBottomIndices.contains(bottomIndex) {
                            if !havePlayed(topPlayer, bottomPlayer) {
                                let assigned = assignColorsBetween(topPlayer.name, bottomPlayer.name, historyRounds: newRounds)
                                let (whiteAssigned, blackAssigned, whiteSwap, blackSwap) = assigned
                                tempPairings.append(Pairing(boardLabel: "Board \(boardNum)", whitePlayer: whiteAssigned, blackPlayer: blackAssigned, result: .none, colorSwapApplied: whiteSwap, blackColorSwapApplied: blackSwap))
                                boardNum += 1
                                usedBottomIndices.insert(bottomIndex)
                                paired = true
                                break
                            }
                        }
                        if !paired {
                            unpairedTopPlayers.append(topPlayer)
                        }
                    }

                    floatDowns.append(contentsOf: unpairedTopPlayers)

                    for (bottomIndex, bottomPlayer) in bottomHalf.enumerated() {
                        if !usedBottomIndices.contains(bottomIndex) {
                            floatDowns.append(bottomPlayer)
                        }
                    }

                    idx += 1
                }

                let swissPairingsCount = tempPairings.count

                if !floatDowns.isEmpty || swissPairingsCount < expectedPairingsCount {
                    // Attempt perfect matching for all non-BYE players
                    if let perfect = PairingEngine.findPerfectMatchingForAll(players: playerListMutable, pastPairings: pastPairings) {
                        // Clear existing Swiss pairings (except BYE)
                        pairings.removeAll(where: { $0.boardLabel != "BYE" })

                        var boardNumberGlobal = 1
                        for (p1, p2) in perfect {
                            let assigned = assignColorsBetween(p1.name, p2.name, historyRounds: newRounds)
                            let (whiteAssigned, blackAssigned, whiteSwap, blackSwap) = assigned
                            pairings.append(Pairing(boardLabel: "Board \(boardNumberGlobal)", whitePlayer: whiteAssigned, blackPlayer: blackAssigned, result: .none, colorSwapApplied: whiteSwap, blackColorSwapApplied: blackSwap))
                            boardNumberGlobal += 1
                            addPairing(p1.name, p2.name)
                        }
                    } else {
                        // Fallback to floatDowns pairing logic as last resort
                        pairings.removeAll(where: { $0.boardLabel != "BYE" })
                        if !playerListMutable.isEmpty {
                            tournamentStopMessage = "Unable to generate valid pairings for the next round without repeating previous matchups. The tournament must end."
                            showTournamentStopAlert = true
                            return
                        }
                    }
                } else {
                    // Swiss pairing succeeded fully, use Swiss pairings
                    pairings.append(contentsOf: tempPairings)
                }

                }

            newRounds.append(pairings)
        }

        // Replace rounds from changedRound+1 onward with regenerated rounds
        rounds = Array(rounds.prefix(changedRound + 1)) + newRounds.dropFirst(changedRound + 1)

        // Immediately assign 1 point for any BYE players in regenerated rounds as well
        assignPointsForByes()
    }

    private func assignPointsForByes() {
        var updatedPlayers = players
        let nameToIndex = Dictionary(uniqueKeysWithValues: updatedPlayers.enumerated().map { ($1.name, $0) })
        var changed = false

        for round in rounds {
            for pairing in round {
                if pairing.whitePlayer == "BYE" && pairing.blackPlayer != "BYE" {
                    if let blackIdx = nameToIndex[pairing.blackPlayer], updatedPlayers[blackIdx].score < 1.0 {
                        updatedPlayers[blackIdx].score = max(updatedPlayers[blackIdx].score, 1.0)
                        // Removed playersWithBye.insert here to avoid double BYE assignment
                        changed = true
                    }
                } else if pairing.blackPlayer == "BYE" && pairing.whitePlayer != "BYE" {
                    if let whiteIdx = nameToIndex[pairing.whitePlayer], updatedPlayers[whiteIdx].score < 1.0 {
                        updatedPlayers[whiteIdx].score = max(updatedPlayers[whiteIdx].score, 1.0)
                        changed = true
                    }
                }
            }
        }

        if changed {
            players = updatedPlayers.sorted {
                if $0.score != $1.score {
                    return $0.score > $1.score
                } else {
                    return $0.ranking < $1.ranking
                }
            }
        }
    }


    // MARK: - Color assignment helpers
    private enum PlayerColor { case white, black }

    // Returns the most recent color assignments (most recent first) for a player across the given rounds history.
    // BYE pairings are ignored (count as no color).
    private func recentColors(for playerName: String, in roundsHistory: [[Pairing]], limit: Int = 2) -> [PlayerColor] {
        var colors: [PlayerColor] = []
        guard limit > 0, !roundsHistory.isEmpty else { return colors }
        for round in roundsHistory.reversed() {
            if let pairing = round.first(where: { $0.whitePlayer == playerName || $0.blackPlayer == playerName }) {
                // Ignore BYE pairings for color history
                if pairing.whitePlayer == "BYE" || pairing.blackPlayer == "BYE" {
                    continue
                }
                if pairing.whitePlayer == playerName {
                    colors.append(.white)
                } else if pairing.blackPlayer == playerName {
                    colors.append(.black)
                }
                if colors.count >= limit { break }
            }
        }
        return colors
    }

    // Determines if assigning White again would make it the third consecutive White for the player.
    private func willBeThirdWhiteInRow(playerName: String, in roundsHistory: [[Pairing]]) -> Bool {
        let lastTwo = recentColors(for: playerName, in: roundsHistory, limit: 2)
        return lastTwo.count == 2 && lastTwo[0] == .white && lastTwo[1] == .white
    }

    // Determines if assigning Black again would make it the third consecutive Black for the player.
    private func willBeThirdBlackInRow(playerName: String, in roundsHistory: [[Pairing]]) -> Bool {
        let lastTwo = recentColors(for: playerName, in: roundsHistory, limit: 2)
        return lastTwo.count == 2 && lastTwo[0] == .black && lastTwo[1] == .black
    }

    // Chooses colors for a pair (randomly), then enforces the third consecutive White/Black swap rule.
    // If both players would violate (one has two Whites, the other two Blacks), tie-breaker:
    // the lower-ranked player (higher ranking number) is assigned White.
    private func assignColorsBetween(_ p1: String, _ p2: String, historyRounds: [[Pairing]]) -> (String, String, Bool, Bool) {
        let randomWhiteIsP1 = Bool.random()
        var white = randomWhiteIsP1 ? p1 : p2
        var black = randomWhiteIsP1 ? p2 : p1

        // Evaluate potential violations for the current tentative assignment
        let whiteWouldBeThirdWhite = willBeThirdWhiteInRow(playerName: white, in: historyRounds)
        let blackWouldBeThirdBlack = willBeThirdBlackInRow(playerName: black, in: historyRounds)

        if whiteWouldBeThirdWhite && blackWouldBeThirdBlack {
            // Both want to swap: choose White for the lower-ranked (higher number) player
            let rankWhite = players.first(where: { $0.name == white })?.ranking ?? Int.max
            let rankBlack = players.first(where: { $0.name == black })?.ranking ?? Int.max
            // Assign White to the higher ranking number (lower rank)
            if rankBlack > rankWhite {
                // black is lower-ranked; make them White
                swap(&white, &black)
            }
            // If ranks are equal or white is already lower-ranked, keep as is
        } else if whiteWouldBeThirdWhite {
            swap(&white, &black)
        } else if blackWouldBeThirdBlack {
            swap(&white, &black)
        }

        return (white, black, whiteWouldBeThirdWhite, blackWouldBeThirdBlack)
    }

}
