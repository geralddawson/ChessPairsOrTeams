import Foundation
import SwiftUI
import Combine

@MainActor
final class TeamsStore: ObservableObject {
    @Published var teams: [Team] = [] {
        didSet { save() }
    }
    
    @Published var reserves: [String] = [] {
        didSet { saveReserves() }
    }

    init() {
        load()
        loadReserves()
    }

    // MARK: - Paths
    private func appSupportDirectory() throws -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = base.appendingPathComponent("ChessKit", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func teamsURL() throws -> URL {
        try appSupportDirectory().appendingPathComponent("teams.json")
    }
    
    private func reservesURL() throws -> URL {
        try appSupportDirectory().appendingPathComponent("reserves.json")
    }

    // MARK: - CRUD
    func addTeam(name: String) -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        // Prevent duplicate team names (case-insensitive)
        if isTeamNameTaken(trimmed) { return false }
        let nextRank = ((teams.map { $0.ranking }.max() ?? 0) + 1)
        var newTeam = Team(name: trimmed, ranking: nextRank)
        newTeam.players = Array(repeating: "", count: 4)
        teams.append(newTeam)
        teams.sort { $0.ranking < $1.ranking }
        return true
    }

    /// Returns true if another team already uses this name (case-insensitive). Optionally exclude a specific team id.
    func isTeamNameTaken(_ name: String, excluding teamID: UUID? = nil) -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        return teams.contains { t in
            let same = t.name.caseInsensitiveCompare(trimmed) == .orderedSame
            if let excluding = teamID { return same && t.id != excluding }
            return same
        }
    }

    /// Returns true if any (non-empty) player across all teams already has this name (case-insensitive).
    /// Optionally exclude a specific (teamID, boardIndex) slot from the check.
    func isPlayerNameTaken(_ name: String, excludingTeamID: UUID? = nil, excludingBoardIndex: Int? = nil) -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        for team in teams {
            for (idx, player) in team.players.enumerated() {
                guard !player.isEmpty else { continue }
                if let exTeam = excludingTeamID, let exBoard = excludingBoardIndex, team.id == exTeam && idx == exBoard {
                    continue
                }
                if player.caseInsensitiveCompare(trimmed) == .orderedSame { return true }
            }
        }
        // Also treat reserves as taken names
        if reserves.contains(where: { $0.caseInsensitiveCompare(trimmed) == .orderedSame }) {
            return true
        }
        return false
    }

    func renameTeam(teamID: UUID, to newName: String) -> Bool {
        guard let idx = teams.firstIndex(where: { $0.id == teamID }) else { return false }
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        let limited = String(trimmed.prefix(25))
        guard !limited.isEmpty else { return false }
        // Prevent duplicate names (case-insensitive), excluding this team id
        if isTeamNameTaken(limited, excluding: teamID) { return false }
        var t = teams[idx]
        t.name = limited
        teams[idx] = t
        return true
    }

    func setPlayerName(teamID: UUID, board: Int, name: String) -> Bool {
        guard let idx = teams.firstIndex(where: { $0.id == teamID }), (1...4).contains(board) else { return false }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let limited = String(trimmed.prefix(25))
        // Allow empty to clear a slot
        if limited.isEmpty {
            var t = teams[idx]
            t.players[board - 1] = ""
            teams[idx] = t
            return true
        }
        // Prevent duplicate player names anywhere (case-insensitive)
        if isPlayerNameTaken(limited, excludingTeamID: teamID, excludingBoardIndex: board - 1) {
            return false
        }
        var t = teams[idx]
        t.players[board - 1] = limited
        teams[idx] = t
        return true
    }

    func setRank(for teamID: UUID, to newRank: Int) {
        var ordered = teams.sorted { $0.ranking < $1.ranking }
        guard let currentIndex = ordered.firstIndex(where: { $0.id == teamID }) else { return }
        let clamped = max(1, min(newRank, ordered.count))
        let t = ordered.remove(at: currentIndex)
        ordered.insert(t, at: clamped - 1)
        // Renumber sequentially
        teams = ordered.enumerated().map { index, team in
            var updated = team
            updated.ranking = index + 1
            return updated
        }
    }

    func remove(at offsets: IndexSet) {
        teams.remove(atOffsets: offsets)
        renumberSequentially()
    }

    func move(from source: IndexSet, to destination: Int) {
        teams.move(fromOffsets: source, toOffset: destination)
        renumberSequentially()
    }

    func renumberSequentially() {
        teams = teams.enumerated().map { index, t in
            var updated = t
            updated.ranking = index + 1
            return updated
        }
    }

    func clearAll() {
        teams.removeAll()
        reserves.removeAll()
    }

    // MARK: - Reserves CRUD
    func addReserve(name: String) -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        // Prevent duplicates across team players and existing reserves (case-insensitive)
        if isPlayerNameTaken(trimmed) { return false }
        if reserves.contains(where: { $0.caseInsensitiveCompare(trimmed) == .orderedSame }) { return false }
        reserves.append(String(trimmed.prefix(25)))
        return true
    }

    func removeReserve(named name: String) {
        if let idx = reserves.firstIndex(where: { $0.caseInsensitiveCompare(name) == .orderedSame }) {
            reserves.remove(at: idx)
        }
    }

    // MARK: - Persistence
    private func load() {
        do {
            let url = try teamsURL()
            let data = try Data(contentsOf: url)
            let decoded = try JSONDecoder().decode([Team].self, from: data)
            self.teams = decoded.sorted { $0.ranking < $1.ranking }
        } catch {
            self.teams = []
        }
    }

    private func save() {
        do {
            let url = try teamsURL()
            let data = try JSONEncoder().encode(teams)
            try data.write(to: url, options: [.atomic])
        } catch {
            #if DEBUG
            print("[TeamsStore] Save failed:", error)
            #endif
        }
    }
    
    private func loadReserves() {
        do {
            let url = try reservesURL()
            let data = try Data(contentsOf: url)
            let decoded = try JSONDecoder().decode([String].self, from: data)
            self.reserves = decoded
        } catch {
            self.reserves = []
        }
    }

    private func saveReserves() {
        do {
            let url = try reservesURL()
            let data = try JSONEncoder().encode(reserves)
            try data.write(to: url, options: [.atomic])
        } catch {
            #if DEBUG
            print("[TeamsStore] Save reserves failed:", error)
            #endif
        }
    }
}


