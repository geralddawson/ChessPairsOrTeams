//

//

import Foundation

public struct Player: Identifiable, Codable, Equatable {
    public let id: UUID
    public let name: String
    public let ranking: Int
    public var score: Double

    enum CodingKeys: String, CodingKey {
        case id, name, ranking, score
    }

    public init(id: UUID = UUID(), name: String, ranking: Int, score: Double = 0.0) {
        self.id = id
        self.name = name
        self.ranking = ranking
        self.score = score
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        self.name = try container.decode(String.self, forKey: .name)
        self.ranking = try container.decode(Int.self, forKey: .ranking)
        self.score = try container.decodeIfPresent(Double.self, forKey: .score) ?? 0.0
    }
}




