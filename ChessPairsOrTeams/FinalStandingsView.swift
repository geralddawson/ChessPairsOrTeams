//
//  FinalStandingsView.swift
//  ChessKit
//
//  Created by Gerald Dawson on 29/3/2026.

import SwiftUI
#if os(macOS)
import AppKit
import UniformTypeIdentifiers
#endif

struct FinalStandingsView: View {
    let players: [Player]
    let rounds: [[Pairing]]

    @Environment(\.dismiss) private var dismiss
    @State private var showSaveSheet: Bool = false
    @State private var eventName: String = ""
    @State private var eventVenue: String = ""
    @State private var showSaveErrorAlert: Bool = false
    @State private var saveErrorMessage: String = ""
    @State private var showCloseConfirm: Bool = false
    @State private var exportAll: Bool = false

    private struct RankedPlayer {
        let player: Player
        let rank: Int
    }

    private var rankedPlayers: [RankedPlayer] {
        // Sort players by descending score
        let sorted = players.sorted { $0.score > $1.score }
        var result: [RankedPlayer] = []

        var currentRank = 1
        var lastScore: Double? = nil
        var sameRankCount = 0

        for (_, player) in sorted.enumerated() {
            if let lastScore = lastScore {
                if player.score == lastScore {
                    // Same rank as previous
                    sameRankCount += 1
                } else {
                    currentRank += sameRankCount + 1
                    sameRankCount = 0
                }
            }
            else {
                sameRankCount = 0
            }
            lastScore = player.score
            result.append(RankedPlayer(player: player, rank: currentRank))
        }
        return result
    }

    private func backgroundColor(for rank: Int) -> Color? {
        switch rank {
        case 1:
            return Color(red: 1.0, green: 215/255, blue: 0)      // #FFD700 Gold
        case 2:
            return Color(red: 192/255, green: 192/255, blue: 192/255)  // #C0C0C0 Silver
        case 3:
            return Color(red: 205/255, green: 127/255, blue: 50/255)   // #CD7F32 Bronze
        default:
            return nil
        }
    }

    // MARK: - Tie-break (Buchholz Cut-1) helper
    private var tieBreakWinnerName: String? {
        // Determine if the top score is shared; if so, pick the Buchholz Cut-1 leader.
        guard let maxScore = players.map({ $0.score }).max() else { return nil }
        let topScorers = players.filter { $0.score == maxScore }
        guard topScorers.count > 1 else { return nil }
        let cut1 = buchholzCut1Scores()
        // Pick unique maximum; if a tie remains, don't tag any.
        let sorted = topScorers.sorted { (cut1[$0.name] ?? 0) > (cut1[$1.name] ?? 0) }
        guard sorted.count >= 2 else { return nil }
        let first = sorted[0]
        let second = sorted[1]
        let s0 = cut1[first.name] ?? 0
        let s1 = cut1[second.name] ?? 0
        return s0 > s1 ? first.name : nil
    }

    private func buchholzCut1Scores() -> [String: Double] {
        // Build final score lookup
        let scoreByName = Dictionary(uniqueKeysWithValues: players.map { ($0.name, $0.score) })
        // Collect opponents per player (ignore BYE pairings)
        var opponents: [String: [String]] = [:]
        for round in rounds {
            for p in round {
                guard p.whitePlayer != "BYE", p.blackPlayer != "BYE", p.boardLabel != "BYE" else { continue }
                opponents[p.whitePlayer, default: []].append(p.blackPlayer)
                opponents[p.blackPlayer, default: []].append(p.whitePlayer)
            }
        }
        var map: [String: Double] = [:]
        for player in players {
            let opps = opponents[player.name] ?? []
            let oppScores = opps.compactMap { scoreByName[$0] }
            if oppScores.count <= 1 {
                map[player.name] = oppScores.reduce(0, +)
            } else {
                let total = oppScores.reduce(0, +)
                if let minVal = oppScores.min() {
                    map[player.name] = total - minVal
                } else {
                    map[player.name] = total
                }
            }
        }
        return map
    }

    var body: some View {
        NavigationStack {
            HStack(alignment: .top, spacing: 32) {
                VStack(spacing: 24) {
                    Text("🏆 Final Standings 🏆")
                        .font(.title)
                        .bold()
                        .padding(.top, 32)

                    if let tbWinner = tieBreakWinnerName {
                        Text("Winner by tie-break (Buchholz Cut-1): \(tbWinner)")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    ScrollView {
                        VStack(spacing: 0) {
                            // Header
                            HStack {
                                Text("  Rank")
                                    .bold()
                                    .frame(width: 50, alignment: .leading)
                                Text("Name")
                                    .bold()
                                    .frame(width: 180, alignment: .leading)
                                Text("Score ")
                                    .bold()
                                    .frame(width: 60, alignment: .trailing)
                            }
                            .padding(.vertical, 8)
                            .background(Color.gray.opacity(0.25))

                            // Rows
                            ForEach(rankedPlayers.indices, id: \.self) { index in
                                let rankedPlayer = rankedPlayers[index]
                                let bgColor = backgroundColor(for: rankedPlayer.rank)

                                HStack(spacing: 0) {
                                    Text("\(rankedPlayer.rank)")
                                        .frame(width: 50, alignment: .leading)
                                    Text(rankedPlayer.player.name)
                                        .frame(width: 180, alignment: .leading)
                                    Text(rankedPlayer.player.score.truncatingRemainder(dividingBy: 1) == 0 ?
                                        String(format: "%.0f", rankedPlayer.player.score) :
                                        String(format: "%.1f", rankedPlayer.player.score))
                                        .frame(width: 60, alignment: .trailing)
                                }
                                .padding(.vertical, 6)
                                .padding(.horizontal, 8)
                                .background(
                                    bgColor?.opacity(0.5)
                                )
                                .cornerRadius(bgColor != nil ? 6 : 0)
                                .foregroundColor(bgColor != nil ? Color.black : Color.primary)
                            }
                        }
                        .padding()
                        .background(Color(NSColor.textBackgroundColor))
                        .cornerRadius(10)
                    }

                    Spacer()
                }
                .padding()

                VStack(alignment: .leading, spacing: 12) {
                    Text("🎉 Congratulations!")
                        .font(.system(size: 30, weight: .semibold))

                    Text("to the prize winners and")
                        .font(.system(size: 28))
                        .foregroundStyle(.secondary)

                    Text("thank you all for playing.")
                        .font(.system(size: 28))
                        .foregroundStyle(.secondary)

                    Text("We hope you continue")
                        .font(.system(size: 28))
                        .foregroundStyle(.secondary)

                    Text("to compete in chess.")
                        .font(.system(size: 28))
                        .foregroundStyle(.secondary)
                }
                .frame(maxHeight: .infinity, alignment: .center)
                .padding()
                .frame(maxWidth: 470)
                .background(Color.gray.opacity(0.08))
                .cornerRadius(16)
                .padding(.top, 76)
            }
            .frame(width: 1300, height: 1000)
            .background(.ultraThinMaterial)
            .padding()
            .edgesIgnoringSafeArea(.bottom)
            .navigationTitle("Final Standings")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Close Tournament", role: .destructive) {
                        showCloseConfirm = true
                    }
                }
                ToolbarItem(placement: .automatic) {
                    Button("Save Results") {
                        showSaveSheet = true
                    }
                }
                ToolbarItem(placement: .automatic) {
                    Menu("Export CSV") {
                        Button("Final Standings…") {
                            let csv = generateCSVFinalStandings()
                            presentSavePanel(suggestedName: "Final-Standings.csv", content: csv)
                        }
                        Button("All (Standings + Rounds)…") {
                            let csv = generateCSVAll()
                            presentSavePanel(suggestedName: "Standings-and-Rounds.csv", content: csv)
                        }
                    }
                }
                ToolbarItem(placement: .automatic) {
                    Button("Export All") {
                        exportAll = true
                        showSaveSheet = true
                    }
                }
            }
        }
        .sheet(isPresented: $showSaveSheet) {
            SaveResultsSheet(eventName: $eventName, eventVenue: $eventVenue, onCancel: {
                showSaveSheet = false
            }, onSave: { name, venue in
                let content = exportAll ? generateMarkdownAll(eventName: name, eventVenue: venue) : generateMarkdown(eventName: name, eventVenue: venue)
                let suggested = exportAll ? suggestedAllFileName(from: name) : suggestedFileName(from: name)
                presentSavePanel(suggestedName: suggested, content: content)
                showSaveSheet = false
                exportAll = false
            })
        }
        .alert("Failed to Save", isPresented: $showSaveErrorAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(saveErrorMessage)
        }
        .alert("Close Tournament?", isPresented: $showCloseConfirm) {
            Button("Cancel", role: .cancel) { }
            Button("Close Tournament", role: .destructive) {
                dismiss()
            }
        } message: {
            Text("WARNING: Be sure to Save and Export results before closing.")
        }
    }

    private func formatScore(_ value: Double) -> String {
        if value.truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%.0f", value)
        } else {
            return String(format: "%.1f", value)
        }
    }

    private func generateMarkdown(eventName: String, eventVenue: String) -> String {
        var md = "# \(eventName)\n"
        if !eventVenue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            md += "Venue: \(eventVenue)\n"
        }
        md += "\n## Final Standings\n\n"
        md += "Rank | Name | Score\n"
        md += "---|---|---\n"
        for rp in rankedPlayers {
            md += "\(rp.rank) | \(rp.player.name) | \(formatScore(rp.player.score))\n"
        }
        return md
    }

    private func generateMarkdownAll(eventName: String, eventVenue: String) -> String {
        var md = "# \(eventName)\n"
        if !eventVenue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            md += "Venue: \(eventVenue)\n"
        }
        md += "\n## Final Standings\n\n"
        md += "Rank | Name | Score\n"
        md += "---|---|---\n"
        for rp in rankedPlayers {
            md += "\(rp.rank) | \(rp.player.name) | \(formatScore(rp.player.score))\n"
        }

        md += "\n## Round Summary\n\n"
        if rounds.isEmpty {
            md += "No round data available.\n"
        } else {
            for (idx, round) in rounds.enumerated() {
                md += "### Round \(idx + 1)\n"
                for p in round {
                    if p.boardLabel == "BYE" || p.whitePlayer == "BYE" || p.blackPlayer == "BYE" {
                        let name: String
                        if p.whitePlayer == "BYE" && p.blackPlayer != "BYE" { name = p.blackPlayer }
                        else if p.blackPlayer == "BYE" && p.whitePlayer != "BYE" { name = p.whitePlayer }
                        else { name = "BYE" }
                        md += "- BYE — \(name)\n"
                    } else {
                        let resultStr: String
                        switch p.result {
                        case .whiteWin: resultStr = "1–0"
                        case .blackWin: resultStr = "0–1"
                        case .draw: resultStr = "½–½"
                        case .none: resultStr = "—"
                        }
                        md += "- \(p.boardLabel): \(p.whitePlayer) vs \(p.blackPlayer) — \(resultStr)\n"
                    }
                }
                md += "\n"
            }
        }
        return md
    }

    private func csvEscape(_ field: String) -> String {
        let needsQuotes = field.contains(",") || field.contains("\"") || field.contains("\n")
        let escaped = field.replacingOccurrences(of: "\"", with: "\"\"")
        return needsQuotes ? "\"\(escaped)\"" : escaped
    }

    private func csvRow(_ fields: [String]) -> String {
        fields.map(csvEscape).joined(separator: ",")
    }

    private func generateCSVFinalStandings() -> String {
        var lines: [String] = []
        lines.append(csvRow(["Rank", "Name", "Score"]))
        for rp in rankedPlayers {
            let scoreStr = formatScore(rp.player.score)
            lines.append(csvRow(["\(rp.rank)", rp.player.name, scoreStr]))
        }
        return lines.joined(separator: "\n") + "\n"
    }

    private func generateCSVAll() -> String {
        var lines: [String] = []

        // Section 1: Final Standings
        lines.append(csvRow(["Final Standings"]))
        lines.append(csvRow(["Rank", "Name", "Score"]))
        for rp in rankedPlayers {
            let scoreStr = formatScore(rp.player.score)
            lines.append(csvRow(["\(rp.rank)", rp.player.name, scoreStr]))
        }

        // Blank line between sections
        lines.append("")

        // Section 2: Round-by-round results in a tidy grid
        lines.append(csvRow(["Round Results"]))
        lines.append(csvRow(["Round", "Board", "White", "Black", "Result", "WhitePts", "BlackPts"]))

        if !rounds.isEmpty {
            for (roundIndex, round) in rounds.enumerated() {
                // Sort pairings: numeric boards first, BYE last
                let sortedPairings = round.sorted { a, b in
                    if a.boardLabel == "BYE" { return false }
                    if b.boardLabel == "BYE" { return true }
                    let nA = Int(a.boardLabel.replacingOccurrences(of: "Board ", with: "")) ?? 0
                    let nB = Int(b.boardLabel.replacingOccurrences(of: "Board ", with: "")) ?? 0
                    return nA < nB
                }
                for p in sortedPairings {
                    if p.boardLabel == "BYE" || p.whitePlayer == "BYE" || p.blackPlayer == "BYE" {
                        // Represent BYE: show the real player's name on the appropriate side, award 1 point
                        let whiteName = (p.whitePlayer == "BYE") ? "" : p.whitePlayer
                        let blackName = (p.blackPlayer == "BYE") ? "" : p.blackPlayer
                        var whitePts = ""
                        var blackPts = ""
                        if p.whitePlayer != "BYE" && p.blackPlayer == "BYE" { whitePts = "1" }
                        if p.blackPlayer != "BYE" && p.whitePlayer == "BYE" { blackPts = "1" }
                        lines.append(csvRow([
                            "\(roundIndex + 1)",
                            p.boardLabel,
                            whiteName,
                            blackName,
                            "BYE",
                            whitePts,
                            blackPts
                        ]))
                    } else {
                        let resultStr: String
                        var whitePts = ""
                        var blackPts = ""
                        switch p.result {
                        case .whiteWin:
                            resultStr = "1–0"
                            whitePts = "1"
                            blackPts = "0"
                        case .blackWin:
                            resultStr = "0–1"
                            whitePts = "0"
                            blackPts = "1"
                        case .draw:
                            resultStr = "½–½"
                            whitePts = "0.5"
                            blackPts = "0.5"
                        case .none:
                            resultStr = "—"
                        }
                        lines.append(csvRow([
                            "\(roundIndex + 1)",
                            p.boardLabel,
                            p.whitePlayer,
                            p.blackPlayer,
                            resultStr,
                            whitePts,
                            blackPts
                        ]))
                    }
                }
            }
        }

        return lines.joined(separator: "\n") + "\n"
    }

    private func suggestedFileName(from eventName: String) -> String {
        let trimmed = eventName.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "Final-Standings.md" }
        let invalid = CharacterSet(charactersIn: "/\\:?%*|\"<>")
        let safe = trimmed.components(separatedBy: invalid).joined(separator: "").replacingOccurrences(of: " ", with: "-")
        return safe + ".md"
    }

    private func suggestedAllFileName(from eventName: String) -> String {
        let trimmed = eventName.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "Final-Standings-and-Rounds.md" }
        let invalid = CharacterSet(charactersIn: "/\\:?%*|\"<>")
        let safe = trimmed.components(separatedBy: invalid).joined(separator: "").replacingOccurrences(of: " ", with: "-")
        return safe + "-All.md"
    }

    private func presentSavePanel(suggestedName: String, content: String) {
        #if os(macOS)
        let panel = NSSavePanel()
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = suggestedName
        if #available(macOS 11.0, *) {
            let ext = URL(fileURLWithPath: suggestedName).pathExtension.lowercased()
            let type = UTType(filenameExtension: ext) ?? .text
            panel.allowedContentTypes = [type]
        }
        panel.begin { response in
            if response == .OK, let url = panel.url {
                do {
                    try content.write(to: url, atomically: true, encoding: .utf8)
                } catch {
                    saveErrorMessage = error.localizedDescription
                    showSaveErrorAlert = true
                }
            }
        }
        #endif
    }

    private struct SaveResultsSheet: View {
        @Binding var eventName: String
        @Binding var eventVenue: String
        let onCancel: () -> Void
        let onSave: (_ name: String, _ venue: String) -> Void
        @Environment(\.dismiss) private var dismiss

        var body: some View {
            VStack(alignment: .leading, spacing: 12) {
                Text("Save Results").font(.title2).bold()
                Text("Provide an event name and venue to include at the top of the Markdown file.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                TextField("Event Name", text: $eventName)
                    .textFieldStyle(.roundedBorder)
                TextField("Venue", text: $eventVenue)
                    .textFieldStyle(.roundedBorder)
                HStack {
                    Spacer()
                    Button("Cancel", role: .cancel) {
                        dismiss()
                        onCancel()
                    }
                    Button("Save") {
                        let name = eventName.trimmingCharacters(in: .whitespacesAndNewlines)
                        let venue = eventVenue.trimmingCharacters(in: .whitespacesAndNewlines)
                        onSave(name, venue)
                        dismiss()
                    }
                    .keyboardShortcut(.defaultAction)
                    .disabled(eventName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .padding()
            .frame(width: 420)
        }
    }
}
