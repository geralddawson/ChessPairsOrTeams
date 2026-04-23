//

//

#if canImport(Testing)
import Testing

@Suite("Pairing engine basic tests")
struct PairingEngineBasicTests {

    @Test("Perfect matching returns pairs for even player count")
    func perfectMatchingEven() async throws {
        let p1 = Player(name: "A", ranking: 1)
        let p2 = Player(name: "B", ranking: 2)
        let p3 = Player(name: "C", ranking: 3)
        let p4 = Player(name: "D", ranking: 4)
        let players = [p1, p2, p3, p4]
        let result = PairingEngine.findPerfectMatchingForAll(players: players, pastPairings: [])
        let unwrapped = try #require(result)
        #expect(unwrapped.count == 2)
        let flatNames = Set(unwrapped.flatMap { [$0.0.name, $0.1.name] })
        #expect(flatNames == Set(["A","B","C","D"]))
    }

    @Test("Perfect matching respects past pairings (no repeats)")
    func perfectMatchingRespectsPast() async throws {
        let p1 = Player(name: "A", ranking: 1)
        let p2 = Player(name: "B", ranking: 2)
        let p3 = Player(name: "C", ranking: 3)
        let p4 = Player(name: "D", ranking: 4)
        let players = [p1, p2, p3, p4]
        // Block A-B and C-D
        let past: Set<String> = ["A|B", "C|D"]
        let result = PairingEngine.findPerfectMatchingForAll(players: players, pastPairings: past)
        let unwrapped = try #require(result)
        // The only valid is A-C/B-D or A-D/B-C
        for (a,b) in unwrapped {
            let key = a.name < b.name ? "\(a.name)|\(b.name)" : "\(b.name)|\(a.name)"
            #expect(!past.contains(key))
        }
    }

    @Test("Perfect matching returns nil for odd player count")
    func perfectMatchingOdd() async throws {
        let p1 = Player(name: "A", ranking: 1)
        let p2 = Player(name: "B", ranking: 2)
        let p3 = Player(name: "C", ranking: 3)
        let players = [p1, p2, p3]
        let result = PairingEngine.findPerfectMatchingForAll(players: players, pastPairings: [])
        #expect(result == nil)
    }

    @Test("Subset perfect pairing produces expected number of pairs")
    func subsetPerfectPairing() async throws {
        let p1 = Player(name: "A", ranking: 1)
        let p2 = Player(name: "B", ranking: 2)
        let p3 = Player(name: "C", ranking: 3)
        let p4 = Player(name: "D", ranking: 4)
        let subset = [p1, p2, p3, p4]
        let result = PairingEngine.findPerfectPairing(players: subset, pastPairings: [])
        let unwrapped = try #require(result)
        #expect(unwrapped.count == 2)
    }
}
#endif




