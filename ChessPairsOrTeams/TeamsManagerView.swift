import SwiftUI

struct TeamsManagerView: View {
    @EnvironmentObject var teamsStore: TeamsStore
    @State private var newTeamName: String = ""
    @State private var rankInputs: [UUID: String] = [:]
    @FocusState private var focusTarget: FocusTarget?

    @State private var teamNameInputs: [UUID: String] = [:]
    @State private var playerNameInputs: [UUID: [Int: String]] = [:]

    @State private var reserveInput: String = ""
    @State private var activeAlert: AlertKind? = nil
    @State private var navigateToTeamDraw = false
    @State private var tournament: Tournament? = nil

    @State private var showTeamsValidationAlert: Bool = false
    @State private var teamsValidationMessage: String = ""

    private enum FocusTarget: Hashable {
        case teamName(UUID)
        case player(UUID, Int) // team id, board index 0...3
    }
    private enum AlertKind: Identifiable {
        case duplicateTeam(String)
        case duplicatePlayer(String)
        case duplicateReserve(String)

        var id: String {
            switch self {
            case .duplicateTeam(let name): return "duplicateTeam:\(name)"
            case .duplicatePlayer(let name): return "duplicatePlayer:\(name)"
            case .duplicateReserve(let name): return "duplicateReserve:\(name)"
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Add teams and set a rank for each. Enter four names per team. Any reserve players go into the store")
                    .font(.title2).bold()
                Spacer()
                Button("Clear All") {
                    teamsStore.clearAll()
                    rankInputs.removeAll()
                    reserveInput = ""
                    teamsStore.reserves.removeAll()
                }
                .disabled(teamsStore.teams.isEmpty)
            }

            HStack(spacing: 12) {
                TextField("Enter team name", text: $newTeamName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(width: 168)
                    .font(.title2)
                    .onChange(of: newTeamName) {
                        if newTeamName.count > 25 {
                            newTeamName = String(newTeamName.prefix(25))
                        }
                    }
                    .onSubmit { addTeam() }
                
                TextField("Enter reserve player name", text: $reserveInput)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(width: 168)
                    .font(.title2)
                    .onChange(of: reserveInput) {
                        if reserveInput.count > 25 {
                            reserveInput = String(reserveInput.prefix(25))
                        }
                    }
                    .onSubmit { addReserve() }
            }

            HStack(alignment: .top, spacing: 24) {
                // Left: Teams grid
                ScrollView(.horizontal) {
                    HStack(alignment: .top, spacing: 16) {
                        // Precompute columns to help the type-checker
                        let colData = columns(from: teamsStore.teams, rowsPerColumn: 4)
                        ForEach(colData.indices, id: \.self) { colIndex in
                            let colTeams = colData[colIndex]
                            VStack(alignment: .leading, spacing: 12) {
                                ForEach(colTeams) { team in
                                    teamCard(team)
                                }
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }

                // Right: Reserves list
                VStack(alignment: .leading, spacing: 8) {
                    Text("Reserve Players")
                        .font(.headline)
                    if teamsStore.reserves.isEmpty {
                        Text("No reserves added yet")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(teamsStore.reserves, id: \.self) { name in
                            HStack {
                                Text(name)
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                                    .frame(width: 200, alignment: .leading)
                                Spacer()
                                Button(role: .destructive) {
                                    teamsStore.removeReserve(named: name)
                                } label: {
                                    Image(systemName: "trash")
                                }
                                .buttonStyle(.borderless)
                            }
                        }
                    }
                }
                .frame(width: 280, alignment: .topLeading)
                .padding(.top, 4)
            }

            HStack {
                Spacer()
                Button("Start Tournament") {
                    if let error = validateTeamsInputs() {
                        teamsValidationMessage = error
                        showTeamsValidationAlert = true
                        return
                    }

                    // Apply rank inputs to the store before building the Tournament
                    let teams = teamsStore.teams
                    let count = teams.count
                    var idToRank: [UUID: Int] = [:]
                    for t in teams {
                        if let text = rankInputs[t.id], let val = Int(text), (1...count).contains(val) {
                            idToRank[t.id] = val
                        }
                    }
                    let sortedIDs = idToRank.sorted { $0.value < $1.value }.map { $0.key }
                    for (idx, id) in sortedIDs.enumerated() {
                        teamsStore.setRank(for: id, to: idx + 1)
                    }
                    // Sync inputs to the canonical ranks after reordering
                    rankInputs = Dictionary(uniqueKeysWithValues: teamsStore.teams.map { ($0.id, String($0.ranking)) })

                    let tTeams: [Tournament.Team] = teamsStore.teams.map {
                        Tournament.Team(id: $0.id, name: $0.name, ranking: $0.ranking, players: $0.players)
                    }
                    let t = Tournament(name: "Teams Tournament", teams: tTeams, boardsPerMatch: 4)
                    tournament = t
                    navigateToTeamDraw = true
                }
                .buttonStyle(LiquidGlassButtonStyle())
                .font(.title2)
            }
            .padding(.top, 8)
        }
        .padding()
        .tint(.primary)
        .alert(item: $activeAlert) { alert in
            switch alert {
            case .duplicateTeam(let name):
                return Alert(
                    title: Text("Duplicate Team Name"),
                    message: Text("A team named \"\(name)\" already exists. Team names must be unique."),
                    dismissButton: .default(Text("OK"))
                )
            case .duplicatePlayer(let name):
                return Alert(
                    title: Text("Duplicate Player Name"),
                    message: Text("The player name \"\(name)\" is already used in another team. Player names must be unique across all teams."),
                    dismissButton: .default(Text("OK"))
                )
            case .duplicateReserve(let name):
                return Alert(
                    title: Text("Duplicate Reserve Name"),
                    message: Text("The reserve name \"\(name)\" is already used in teams or in the reserve list. Please choose a unique name."),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
        .alert("Teams Incomplete", isPresented: $showTeamsValidationAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(teamsValidationMessage)
        }
        .navigationDestination(isPresented: $navigateToTeamDraw) {
            if let tournament {
                TeamsRoundScreen(round: 1, tournament: tournament)
            } else {
                EmptyView()
            }
        }
    }

    private func addTeam() {
        let trimmed = newTeamName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if !teamsStore.addTeam(name: trimmed) {
            // Duplicate team name
            activeAlert = .duplicateTeam(trimmed)
            return
        }
        newTeamName = ""
    }
    
    private func addReserve() {
        let trimmed = reserveInput.trimmingCharacters(in: .whitespacesAndNewlines)
        let limited = String(trimmed.prefix(25))
        guard !limited.isEmpty else { return }
        if teamsStore.isPlayerNameTaken(limited) || teamsStore.reserves.contains(where: { $0.caseInsensitiveCompare(limited) == .orderedSame }) {
            activeAlert = .duplicateReserve(limited)
            return
        }
        let ok = teamsStore.addReserve(name: limited)
        if !ok {
            activeAlert = .duplicateReserve(limited)
            return
        }
        reserveInput = ""
    }

    private func safePlayerName(_ players: [String], at index: Int) -> String {
        if index < players.count { return players[index] }
        return ""
    }

    @ViewBuilder
    private func teamCard(_ team: Team) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                TextField("Rank", text: Binding(
                    get: { rankInputs[team.id] ?? "" },
                    set: { newValue in
                        let filtered = newValue.filter { $0.isNumber }
                        rankInputs[team.id] = filtered
                    }
                ))
                .textFieldStyle(.plain)
                .frame(width: 50)
                .multilineTextAlignment(.center)
                .padding(.vertical, 4)
                .padding(.horizontal, 6)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.green.opacity(0.18))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(Color.primary.opacity(0.25), lineWidth: 1)
                )
                .onSubmit {
                    let text = rankInputs[team.id] ?? ""
                    if let val = Int(text) {
                        let clamped = max(1, min(val, teamsStore.teams.count))
                        teamsStore.setRank(for: team.id, to: clamped)
                        // Sync inputs to reflect current ranks after reordering
                        rankInputs = Dictionary(uniqueKeysWithValues: teamsStore.teams.map { ($0.id, String($0.ranking)) })
                    }
                }

                TextField("Team name", text: Binding(
                    get: { teamNameInputs[team.id] ?? team.name },
                    set: { newValue in
                        teamNameInputs[team.id] = String(newValue.prefix(25))
                    }
                ))
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .frame(width: 156)
                .font(.title3)
                .submitLabel(.next)
                .focused($focusTarget, equals: .teamName(team.id))
                .onSubmit {
                    let proposed = teamNameInputs[team.id]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    if !proposed.isEmpty {
                        let success = teamsStore.renameTeam(teamID: team.id, to: proposed)
                        if success {
                            teamNameInputs[team.id] = nil
                            focusTarget = .player(team.id, 0)
                        } else {
                            activeAlert = .duplicateTeam(proposed)
                            focusTarget = .teamName(team.id)
                        }
                    } else {
                        // Empty input: do not commit; just advance focus
                        focusTarget = .player(team.id, 0)
                    }
                }

                Button(role: .destructive) {
                    if let idx = teamsStore.teams.firstIndex(where: { $0.id == team.id }) {
                        teamsStore.remove(at: IndexSet(integer: idx))
                        teamNameInputs[team.id] = nil
                        playerNameInputs[team.id] = nil
                        rankInputs[team.id] = nil
                    }
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
            }

            // Four players inputs
            VStack(alignment: .leading, spacing: 6) {
                ForEach(0..<4, id: \.self) { board in
                    HStack(spacing: 8) {
                        Text("Board \(board + 1)")
                            .frame(width: 70, alignment: .leading)
                            .foregroundStyle(.secondary)
                        TextField("Player name", text: Binding(
                            get: { playerNameInputs[team.id]?[board] ?? safePlayerName(team.players, at: board) },
                            set: { newValue in
                                let limited = String(newValue.prefix(25))
                                var dict = playerNameInputs[team.id] ?? [:]
                                dict[board] = limited
                                playerNameInputs[team.id] = dict
                            }
                        ))
                        .textFieldStyle(.plain)
                        .frame(width: 156)
                        .padding(.vertical, 4)
                        .padding(.horizontal, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(Color.blue.opacity(0.14))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .stroke(Color.primary.opacity(0.25), lineWidth: 1)
                        )
                        .submitLabel(.next)
                        .focused($focusTarget, equals: .player(team.id, board))
                        .onSubmit {
                            let proposed = playerNameInputs[team.id]?[board]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                            let commitName = String(proposed.prefix(25))
                            if commitName.isEmpty {
                                _ = teamsStore.setPlayerName(teamID: team.id, board: board + 1, name: "")
                                var dict = playerNameInputs[team.id] ?? [:]
                                dict.removeValue(forKey: board)
                                playerNameInputs[team.id] = dict
                            } else {
                                let success = teamsStore.setPlayerName(teamID: team.id, board: board + 1, name: commitName)
                                if success {
                                    var dict = playerNameInputs[team.id] ?? [:]
                                    dict.removeValue(forKey: board)
                                    playerNameInputs[team.id] = dict
                                } else {
                                    activeAlert = .duplicatePlayer(commitName)
                                    focusTarget = .player(team.id, board)
                                    return
                                }
                            }
                            if board < 3 {
                                focusTarget = .player(team.id, board + 1)
                            } else {
                                focusTarget = nil
                            }
                        }
                    }
                }
            }
            .padding(.leading, 4)
        }
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func columns(from teams: [Team], rowsPerColumn: Int) -> [[Team]] {
        guard rowsPerColumn > 0 else { return [teams] }
        var result: [[Team]] = []
        var index = 0
        while index < teams.count {
            let end = min(index + rowsPerColumn, teams.count)
            result.append(Array(teams[index..<end]))
            index = end
        }
        return result
    }

    private func validateTeamsInputs() -> String? {
        // Require at least two teams
        let teams = teamsStore.teams
        if teams.count < 2 {
            return "Please add at least two teams before starting the tournament."
        }

        // Team names must be non-empty and unique (case-insensitive)
        let trimmedNames = teams.map { t in
            (teamNameInputs[t.id] ?? t.name).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        for (idx, name) in trimmedNames.enumerated() {
            if name.isEmpty {
                return "Team \(idx + 1) has an empty name. Please enter a team name."
            }
        }
        let lowercased = trimmedNames.map { $0.lowercased() }
        let uniqueCount = Set(lowercased).count
        if uniqueCount != lowercased.count {
            // Find one duplicate name to report
            var seen = Set<String>()
            var dup: String? = nil
            for n in lowercased {
                if seen.contains(n) { dup = n; break } else { seen.insert(n) }
            }
            if let dup = dup, let firstIdx = lowercased.firstIndex(of: dup), let secondIdx = lowercased.lastIndex(of: dup), firstIdx != secondIdx {
                let a = trimmedNames[firstIdx]
                let b = trimmedNames[secondIdx]
                return "Duplicate team name detected: ‘\(a)’ and ‘\(b)’. Team names must be unique."
            }
            return "Duplicate team names detected. Please ensure each team has a unique name."
        }

        // Player names must be non-empty and unique across all teams and reserves
        var seenPlayers = Set<String>()
        let reserveLower = Set(teamsStore.reserves.map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() })
        for t in teams {
            let teamDisplayName = (teamNameInputs[t.id] ?? t.name).trimmingCharacters(in: .whitespacesAndNewlines)
            for board in 0..<4 {
                let raw = playerNameInputs[t.id]?[board] ?? (board < t.players.count ? t.players[board] : "")
                let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.isEmpty {
                    return "Team \(teamDisplayName) has an empty player name on Board \(board + 1). Please fill all four player names."
                }
                let lower = trimmed.lowercased()
                if seenPlayers.contains(lower) {
                    return "Duplicate player name detected: '\(trimmed)'. Player names must be unique across all teams."
                }
                if reserveLower.contains(lower) {
                    return "Player name '\(trimmed)' is already listed as a reserve. Player names must be unique across teams and reserves."
                }
                seenPlayers.insert(lower)
            }
        }

        // Ranks must be complete (1..N) and unique
        let count = teams.count
        var idToRank: [UUID: Int] = [:]
        for t in teams {
            guard let text = rankInputs[t.id], let val = Int(text), (1...count).contains(val) else {
                return "Please enter a unique rank between 1 and \(count) for every team."
            }
            idToRank[t.id] = val
        }
        let ranks = Array(idToRank.values)
        if Set(ranks).count != ranks.count {
            // Find one duplicate rank and report conflicting teams
            var seen = Set<Int>()
            var dup: Int? = nil
            for r in ranks { if seen.contains(r) { dup = r; break } else { seen.insert(r) } }
            if let dup = dup {
                let names = teams.compactMap { t in (idToRank[t.id] == dup) ? t.name : nil }
                let joined = names.joined(separator: " and ")
                return "Rank \(dup) has been assigned to both \(joined). Please choose unique ranks."
            } else {
                return "Duplicate ranks detected. Please ensure each rank is unique."
            }
        }

        return nil // OK
    }
}

#Preview {
    TeamsManagerView()
        .environmentObject(TeamsStore())
}
