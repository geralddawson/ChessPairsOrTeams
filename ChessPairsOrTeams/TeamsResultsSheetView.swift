import SwiftUI
#if os(macOS)
import AppKit
import UniformTypeIdentifiers
#endif

struct TeamsResultsSheetView: View {
    let tournament: Tournament
    let rounds: [[Tournament.TeamMatch]]
    let scores: [UUID: Double]
    let individualRows: [TeamsRoundScreen.IndividualScore]
    let onCloseTournament: () -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var showSaveSheet: Bool = false
    @State private var eventName: String = ""
    @State private var eventVenue: String = ""
    @State private var showSaveErrorAlert: Bool = false
    @State private var saveErrorMessage: String = ""
    @State private var showSaveSuccessAlert: Bool = false
    @State private var saveSuccessURL: URL? = nil
    @State private var showCloseConfirm: Bool = false

    // MARK: - Tie-break (Buchholz Cut-1) helper for teams
    private var tieBreakWinnerTeamName: String? {
        let teamScores: [UUID: Double] = scores
        let allScores = tournament.teams.map { teamScores[$0.id] ?? 0.0 }
        guard let maxScore = allScores.max() else { return nil }
        let topTeams = tournament.teams.filter { (teamScores[$0.id] ?? 0.0) == maxScore }
        guard topTeams.count > 1 else { return nil }
        let cut1 = teamBuchholzCut1Scores()
        let sorted = topTeams.sorted { (cut1[$0.id] ?? 0.0) > (cut1[$1.id] ?? 0.0) }
        guard sorted.count >= 2 else { return nil }
        let s0 = cut1[sorted[0].id] ?? 0.0
        let s1 = cut1[sorted[1].id] ?? 0.0
        return s0 > s1 ? sorted[0].name : nil
    }

    private var isTiedOnBuchholzCut1: Bool {
        let teamScores: [UUID: Double] = scores
        let allScores = tournament.teams.map { teamScores[$0.id] ?? 0.0 }
        guard let maxScore = allScores.max() else { return false }
        let topTeams = tournament.teams.filter { (teamScores[$0.id] ?? 0.0) == maxScore }
        guard topTeams.count > 1 else { return false }
        let cut1 = teamBuchholzCut1Scores()
        let topCutValues = topTeams.map { cut1[$0.id] ?? 0.0 }
        guard let maxCut = topCutValues.max() else { return false }
        let countMax = topCutValues.filter { $0 == maxCut }.count
        return countMax > 1
    }

    private func teamBuchholzCut1Scores() -> [UUID: Double] {
        var opponents: [UUID: [UUID]] = [:]
        for roundMatches in rounds {
            for m in roundMatches {
                opponents[m.home.id, default: []].append(m.away.id)
                opponents[m.away.id, default: []].append(m.home.id)
            }
        }
        var map: [UUID: Double] = [:]
        for team in tournament.teams {
            let opps = opponents[team.id] ?? []
            let oppScores = opps.map { scores[$0] ?? 0.0 }
            if oppScores.count <= 1 {
                map[team.id] = oppScores.reduce(0, +)
            } else {
                let total = oppScores.reduce(0, +)
                if let minVal = oppScores.min() {
                    map[team.id] = total - minVal
                } else {
                    map[team.id] = total
                }
            }
        }
        return map
    }

    var body: some View {
        NavigationStack {
            HStack(alignment: .top, spacing: 16) {
                // Left column: Cross Table above Team Placings
                VStack(alignment: .leading, spacing: 16) {
                    if let tbTeam = tieBreakWinnerTeamName {
                        Text("Winner by tie-break (Buchholz Cut-1): \(tbTeam)")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else if isTiedOnBuchholzCut1 {
                        Text("Tied on Buchholz Cut-1")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    // Cross Table
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Cross Table")
                            .font(.title2).bold()

                        let enumeratedRounds = Array(rounds.enumerated())
                        ScrollView([.horizontal, .vertical]) {
                            HStack(alignment: .top, spacing: 12) {
                                ForEach(enumeratedRounds, id: \.offset) { (index, _) in
                                    VStack(alignment: .center, spacing: 6) {
                                        Text("Round \(index + 1)")
                                            .font(.system(.headline, weight: .regular))
                                        VStack(alignment: .center, spacing: 6) {
                                            ForEach(TeamRoundGrid.seedPairs(forRoundIndex: index, rounds: rounds), id: \.left) { pair in
                                                Text("\(pair.left)v\(pair.right)")
                                                    .font(.body.monospaced())
                                                    .padding(8)
                                                    .frame(maxWidth: .infinity, alignment: .center)
                                                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                                            }
                                            if let bye = TeamRoundGrid.byeSeed(forRoundIndex: index, rounds: rounds, tournament: tournament) {
                                                Text("Bye\(bye)")
                                                    .font(.body.monospaced())
                                                    .foregroundStyle(.secondary)
                                                    .padding(8)
                                                    .frame(maxWidth: .infinity, alignment: .leading)
                                                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                                            }
                                        }
                                    }
                                    .frame(width: 80, alignment: .top)
                                }
                            }
                        }
                        .frame(height: 240)
                    }

                    Divider()

                    // Team Placings
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Team Placings")
                            .font(.title2).bold()
                        HStack {
                            Text("Final").font(.headline).frame(width: 60, alignment: .leading)
                            Text("Team").font(.headline).frame(maxWidth: .infinity, alignment: .leading)
                            Text("Score").font(.headline).frame(width: 60, alignment: .trailing)
                        }
                        .padding(.vertical, 4)

                        let orderedTeams: [Tournament.Team] = tournament.teams.sorted { lhs, rhs in
                            let s0: Double = scores[lhs.id] ?? 0.0
                            let s1: Double = scores[rhs.id] ?? 0.0
                            if s0 != s1 { return s0 > s1 }
                            return lhs.ranking < rhs.ranking
                        }

                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 8) {
                                ForEach(Array(orderedTeams.enumerated()), id: \.offset) { idx, team in
                                    let teamScore: Double = scores[team.id] ?? 0.0
                                    let formattedScore: String = String(format: "%.1f", teamScore)
                                    HStack {
                                        Text(String(idx + 1)).frame(width: 60, alignment: .leading)
                                        Text(team.name).lineLimit(1).frame(maxWidth: .infinity, alignment: .leading)
                                        Text(formattedScore).frame(width: 60, alignment: .trailing)
                                    }
                                    .font(.body.monospaced())
                                    .padding(8)
                                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                                }
                            }
                        }
                    }
                }
                .frame(minWidth: 680, maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(.leading, 56)

                Divider()

                // Right column: Individual Scores
                VStack(alignment: .leading, spacing: 8) {
                    let sortedRows = individualRows.sorted { a, b in
                        if a.board != b.board { return a.board < b.board }
                        if a.score != b.score { return a.score > b.score }
                        return a.name < b.name
                    }
                    TeamsRoundScreen.IndividualScoresPanel(rows: sortedRows)
                }
                .frame(minWidth: 420, maxWidth: 520, maxHeight: .infinity, alignment: .topLeading)
            }
            .padding()
            .frame(minWidth: 1200, minHeight: 700)
            .navigationTitle("Tournament Results")
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
                        Button("Team Placings + Cross Table (Grid)…") {
                            let csv = TeamResultsExporter.generateCSVTeamPlacingsAndGrid(tournament: tournament, rounds: rounds, scores: scores)
                            presentSavePanel(suggestedName: "Placings-and-Cross-Table-Grid.csv", content: csv)
                        }
                        Button("Individual Scores…") {
                            let rows = individualRows.map { (board: $0.board, name: $0.name, teamName: $0.teamName, score: $0.score) }
                            let csv = TeamResultsExporter.generateCSVIndividualScores(rows: rows)
                            presentSavePanel(suggestedName: "Individual-Scores.csv", content: csv)
                        }
                        Button("Cross Table…") {
                            let csv = TeamResultsExporter.generateCSVCrossTable(rounds: rounds)
                            presentSavePanel(suggestedName: "Cross-Table.csv", content: csv)
                        }
                    }
                }
            }
            .sheet(isPresented: $showSaveSheet) {
                SaveResultsSheet(eventName: $eventName, eventVenue: $eventVenue, onCancel: {
                    showSaveSheet = false
                }, onSave: { name, venue in
                    let content = generateMarkdown(eventName: name, eventVenue: venue)
                    let suggested = suggestedFileName(from: name)
                    presentSavePanel(suggestedName: suggested, content: content)
                    showSaveSheet = false
                })
            }
            .alert("Failed to Save", isPresented: $showSaveErrorAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(saveErrorMessage)
            }
            .alert("Successfully Saved", isPresented: $showSaveSuccessAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(saveSuccessURL?.path ?? "Saved.")
            }
            .alert("Close Tournament?", isPresented: $showCloseConfirm) {
                Button("Cancel", role: .cancel) { }
                Button("Close Tournament", role: .destructive) {
                    dismiss()
                    onCloseTournament()
                }
            } message: {
                Text("WARNING: This will end the tournament. Your results will be lost if not saved.")
            }
        }
    }

    // MARK: - Markdown and save helpers (copied behavior)
    private func generateMarkdown(eventName: String, eventVenue: String) -> String {
        var md = "# \(eventName)\n"
        if !eventVenue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            md += "Venue: \(eventVenue)\n"
        }
        md += "\n## Cross Table\n\n"

        let enumeratedRounds = Array(rounds.enumerated())
        for (index, _) in enumeratedRounds {
            md += "### Round \(index + 1)\n"
            let pairs = TeamRoundGrid.seedPairs(forRoundIndex: index, rounds: rounds)
            for p in pairs { md += "- \(p.left) v \(p.right)\n" }
            if let bye = TeamRoundGrid.byeSeed(forRoundIndex: index, rounds: rounds, tournament: tournament) { md += "- Bye \(bye)\n" }
            md += "\n"
        }

        md += "\n## Team Placings\n\n"
        let orderedTeams: [Tournament.Team] = tournament.teams.sorted { lhs, rhs in
            let s0: Double = scores[lhs.id] ?? 0.0
            let s1: Double = scores[rhs.id] ?? 0.0
            if s0 != s1 { return s0 > s1 }
            return lhs.ranking < rhs.ranking
        }
        for (idx, team) in orderedTeams.enumerated() {
            let teamScore: Double = scores[team.id] ?? 0.0
            md += "\(idx + 1). \(team.name) — \(formatScore(teamScore))\n"
        }

        md += "\n## Individual Scores\n\n"
        let sortedRows = individualRows.sorted { a, b in
            if a.board != b.board { return a.board < b.board }
            if a.score != b.score { return a.score > b.score }
            return a.name < b.name
        }
        md += "Board | Name | Team | Score\n"
        md += "---|---|---|---\n"
        for row in sortedRows {
            md += "\(row.board) | \(row.name) | \(row.teamName) | \(formatScore(row.score))\n"
        }
        return md
    }

    private func formatScore(_ value: Double) -> String {
        if value.truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%.0f", value)
        } else {
            return String(format: "%.1f", value)
        }
    }

    private func suggestedFileName(from eventName: String) -> String {
        let trimmed = eventName.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "Tournament-Results.md" }
        let invalid = CharacterSet(charactersIn: "/\\:?%*|\"<>")
        let safe = trimmed.components(separatedBy: invalid).joined(separator: "").replacingOccurrences(of: " ", with: "-")
        return safe + ".md"
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
