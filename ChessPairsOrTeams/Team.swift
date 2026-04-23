import Foundation

public struct Team: Identifiable, Codable, Equatable {
    public let id: UUID
    public var name: String
    public var ranking: Int
    public var players: [String] // Always 4 entries

    public init(id: UUID = UUID(), name: String, ranking: Int, players: [String] = Array(repeating: "", count: 4)) {
        self.id = id
        self.name = name
        self.ranking = ranking
        // Normalize to exactly 4 players
        if players.count >= 4 {
            self.players = Array(players.prefix(4))
        } else {
            self.players = players + Array(repeating: "", count: 4 - players.count)
        }
    }
}


