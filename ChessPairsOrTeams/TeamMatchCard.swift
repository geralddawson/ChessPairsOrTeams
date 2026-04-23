import SwiftUI

struct TeamMatchCard: View {
    let match: Tournament.TeamMatch
    let pairings: [Tournament.TeamMatch.BoardPairing]
    let reserves: [String]
    @Binding var boardResults: [Int: ResultOption]
    let onReplace: (_ board: Int, _ isWhite: Bool, _ newName: String?) -> Void
    let showScoringControls: Bool

    init(
        match: Tournament.TeamMatch,
        pairings: [Tournament.TeamMatch.BoardPairing],
        reserves: [String],
        boardResults: Binding<[Int: ResultOption]>,
        onReplace: @escaping (_ board: Int, _ isWhite: Bool, _ newName: String?) -> Void,
        showScoringControls: Bool = true
    ) {
        self.match = match
        self.pairings = pairings
        self.reserves = reserves
        self._boardResults = boardResults
        self.onReplace = onReplace
        self.showScoringControls = showScoringControls
    }

    private func setResult(_ board: Int, _ result: ResultOption) {
        var copy = boardResults
        copy[board] = result
        boardResults = copy
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(match.higherRanked.name)
                Text("vs").foregroundStyle(.secondary)
                Text(match.lowerRanked.name)
            }
            .font(.headline)
            .frame(maxWidth: .infinity, alignment: .leading)

            let totals = teamTotals()
            HStack(spacing: 4) {
                Text(match.higherRanked.name)
                Text(formatScore(totals.higher))
                Text("–")
                Text(formatScore(totals.lower))
                Text(match.lowerRanked.name)
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .center)

            Grid(alignment: .leading, horizontalSpacing: 8, verticalSpacing: 6) {
                ForEach(pairings) { bp in
                    GridRow {
                        Text("Board \(bp.board)")
                            .frame(width: 80, alignment: .leading)
                            .foregroundStyle(.secondary)

                        if showScoringControls {
                            Text(bp.whiteName)
                                .lineLimit(1)
                                .truncationMode(.tail)
                                .frame(minWidth: 180, alignment: .leading)
                                .contextMenu {
                                    if !reserves.isEmpty {
                                        Menu("Replace with Reserve") {
                                            ForEach(reserves, id: \.self) { name in
                                                Button(name) { onReplace(bp.board, true, name) }
                                            }
                                        }
                                    }
                                    Button("Clear Replacement") { onReplace(bp.board, true, nil) }
                                }
                        } else {
                            Text(bp.whiteName)
                                .lineLimit(1)
                                .truncationMode(.tail)
                                .frame(minWidth: 180, alignment: .leading)
                        }

                        HStack(spacing: 4) {
                            Image(systemName: "circle.fill").foregroundStyle(.white).imageScale(.small)
                            Image(systemName: "circle.fill").foregroundStyle(.black).imageScale(.small)
                        }
                        .frame(width: 26, alignment: .center)

                        if showScoringControls {
                            Text(bp.blackName)
                                .lineLimit(1)
                                .truncationMode(.tail)
                                .frame(minWidth: 180, alignment: .leading)
                                .contextMenu {
                                    if !reserves.isEmpty {
                                        Menu("Replace with Reserve") {
                                            ForEach(reserves, id: \.self) { name in
                                                Button(name) { onReplace(bp.board, false, name) }
                                            }
                                        }
                                    }
                                    Button("Clear Replacement") { onReplace(bp.board, false, nil) }
                                }
                        } else {
                            Text(bp.blackName)
                                .lineLimit(1)
                                .truncationMode(.tail)
                                .frame(minWidth: 180, alignment: .leading)
                        }

                        if showScoringControls {
                            HStack(spacing: 4) {
                                Button(action: { setResult(bp.board, .whiteWin) }) {
                                    Text("1–0")
                                        .frame(width: 30, height: 22)
                                        .background(
                                            RoundedRectangle(cornerRadius: 4)
                                                .stroke(boardResults[bp.board] == .whiteWin ? Color.blue : Color.primary.opacity(0.4),
                                                        lineWidth: boardResults[bp.board] == .whiteWin ? 2 : 1)
                                        )
                                }
                                Button(action: { setResult(bp.board, .draw) }) {
                                    Text("½")
                                        .frame(width: 24, height: 22)
                                        .background(
                                            RoundedRectangle(cornerRadius: 4)
                                                .stroke(boardResults[bp.board] == .draw ? Color.blue : Color.primary.opacity(0.4),
                                                        lineWidth: boardResults[bp.board] == .draw ? 2 : 1)
                                        )
                                }
                                Button(action: { setResult(bp.board, .blackWin) }) {
                                    Text("0–1")
                                        .frame(width: 30, height: 22)
                                        .background(
                                            RoundedRectangle(cornerRadius: 4)
                                                .stroke(boardResults[bp.board] == .blackWin ? Color.blue : Color.primary.opacity(0.4),
                                                        lineWidth: boardResults[bp.board] == .blackWin ? 2 : 1)
                                        )
                                }
                            }
                            .font(.caption2.monospaced())
                            .disabled(bp.whiteName == "—" || bp.blackName == "—")
                        }
                    }
                }
            }
            .font(.body.monospaced())
        }
        .padding(10)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private func teamTotals() -> (higher: Double, lower: Double) {
        var higher: Double = 0
        var lower: Double = 0
        for bp in pairings {
            guard let result = boardResults[bp.board] else { continue }
            let homeIsWhite = (bp.board % 2 == 1)
            let higherIsHome = match.higherRanked.id == match.home.id
            switch result {
            case .whiteWin:
                let winnerIsHome = homeIsWhite
                if (winnerIsHome && higherIsHome) || (!winnerIsHome && !higherIsHome) { higher += 1 } else { lower += 1 }
            case .blackWin:
                let winnerIsHome = !homeIsWhite
                if (winnerIsHome && higherIsHome) || (!winnerIsHome && !higherIsHome) { higher += 1 } else { lower += 1 }
            case .draw:
                if bp.whiteName != "—" && bp.blackName != "—" { higher += 0.5; lower += 0.5 }
            case .none:
                break
            }
        }
        return (higher, lower)
    }

    private func formatScore(_ value: Double) -> String {
        if value.truncatingRemainder(dividingBy: 1) == 0 { return String(format: "%.0f", value) } else { return String(format: "%.1f", value) }
    }
}

