//
//  PlayersStore.swift
//  ChessKit
//
//  Created by G Dawson on 29/3/2026.
//

import Foundation
import SwiftUI
import Combine

@MainActor
final class PlayersStore: ObservableObject {
    @Published var players: [Player] = [] {
        didSet { save() }
    }

    init() {
        load()
    }

    // MARK: - Paths
    private func appSupportDirectory() throws -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = base.appendingPathComponent("ChessKit", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func playersURL() throws -> URL {
        try appSupportDirectory().appendingPathComponent("players.json")
    }

    // MARK: - CRUD
    func add(name: String, ranking: Int? = nil) {
        let nextRank = ranking ?? ((players.map { $0.ranking }.max() ?? 0) + 1)
        players.append(Player(name: name, ranking: nextRank))
        players.sort { $0.ranking < $1.ranking }
    }

    func rename(playerID: UUID, to newName: String) {
        guard let idx = players.firstIndex(where: { $0.id == playerID }) else { return }
        let p = players[idx]
        players[idx] = Player(id: p.id, name: newName, ranking: p.ranking, score: p.score)
    }

    func insert(name: String, atRank rank: Int) {
        // Insert a new player at the requested rank and renumber everyone sequentially to keep ranks unique
        var ordered = players.sorted { $0.ranking < $1.ranking }
        let clamped = max(1, min(rank, ordered.count + 1))
        let newPlayer = Player(name: name, ranking: clamped)
        ordered.insert(newPlayer, at: clamped - 1)
        // Renumber sequentially to avoid duplicate rankings and keep order stable
        players = ordered.enumerated().map { index, p in
            Player(id: p.id, name: p.name, ranking: index + 1, score: p.score)
        }
    }
    
    func setRank(for playerID: UUID, to newRank: Int) {
        // Reorder the player to the desired rank and renumber sequentially
        var ordered = players.sorted { $0.ranking < $1.ranking }
        guard let currentIndex = ordered.firstIndex(where: { $0.id == playerID }) else { return }
        let clamped = max(1, min(newRank, ordered.count))
        let p = ordered.remove(at: currentIndex)
        // Insert at desired position (rank is 1-based)
        ordered.insert(p, at: clamped - 1)
        // Renumber to keep unique, sequential rankings
        players = ordered.enumerated().map { index, player in
            Player(id: player.id, name: player.name, ranking: index + 1, score: player.score)
        }
    }

    func remove(at offsets: IndexSet) {
        players.remove(atOffsets: offsets)
        renumberSequentially()
    }

    func move(from source: IndexSet, to destination: Int) {
        players.move(fromOffsets: source, toOffset: destination)
        renumberSequentially()
    }

    func clearAll() {
        players.removeAll()
    }

    func renumberSequentially() {
        players = players.enumerated().map { index, p in
            Player(id: p.id, name: p.name, ranking: index + 1, score: p.score)
        }
    }

    // MARK: - Persistence
    private func load() {
        do {
            let url = try playersURL()
            let data = try Data(contentsOf: url)
            let decoded = try JSONDecoder().decode([Player].self, from: data)
            self.players = decoded.sorted { $0.ranking < $1.ranking }
        } catch {
            // No persisted players yet; start empty
            self.players = []
        }
    }

    private func save() {
        do {
            let url = try playersURL()
            let data = try JSONEncoder().encode(players)
            try data.write(to: url, options: [.atomic])
        } catch {
            #if DEBUG
            print("[PlayersStore] Save failed:", error)
            #endif
        }
    }
}








