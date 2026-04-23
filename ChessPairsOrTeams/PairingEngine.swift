//


import Foundation

enum PairingEngine {
    /// Backtracking perfect matching avoiding past pairings. Returns nil if not possible.
    static func findPerfectMatchingForAll(players: [Player], pastPairings: Set<String>) -> [(Player, Player)]? {
        if players.count % 2 != 0 { return nil }
        if players.isEmpty { return [] }
        var used = Set<Int>()
        func recur(_ soFar: [(Player, Player)]) -> [(Player, Player)]? {
            if soFar.count == players.count / 2 {
                return soFar
            }
            guard let i = (0..<players.count).first(where: { !used.contains($0) }) else { return nil }
            used.insert(i)
            let p1 = players[i]
            for j in (i+1)..<players.count where !used.contains(j) {
                let p2 = players[j]
                let pairKey = p1.name < p2.name ? "\(p1.name)|\(p2.name)" : "\(p2.name)|\(p1.name)"
                if pastPairings.contains(pairKey) { continue }
                used.insert(j)
                if let result = recur(soFar + [(p1, p2)]) {
                    return result
                }
                used.remove(j)
            }
            used.remove(i)
            return nil
        }
        return recur([])
    }

    /// Backtracking pairing for any even-sized subset, avoiding past pairings. Returns nil if not possible.
    static func findPerfectPairing(players: [Player], pastPairings: Set<String>) -> [(Player, Player)]? {
        if players.isEmpty { return [] }
        if players.count % 2 != 0 { return nil }
        var used = Set<Int>()
        func recur(_ soFar: [(Player, Player)]) -> [(Player, Player)]? {
            if soFar.count == players.count / 2 { return soFar }
            guard let i = (0..<players.count).first(where: { !used.contains($0) }) else { return nil }
            used.insert(i)
            let p1 = players[i]
            for j in (i+1)..<players.count where !used.contains(j) {
                let p2 = players[j]
                let pairKey = p1.name < p2.name ? "\(p1.name)|\(p2.name)" : "\(p2.name)|\(p1.name)"
                if pastPairings.contains(pairKey) { continue }
                used.insert(j)
                if let result = recur(soFar + [(p1, p2)]) { return result }
                used.remove(j)
            }
            used.remove(i)
            return nil
        }
        return recur([])
    }
}




