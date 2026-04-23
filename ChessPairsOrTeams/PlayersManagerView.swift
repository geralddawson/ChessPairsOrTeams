//
//  PlayersManagerView.swift
//  ChessKit
//
//  Created by G Dawson on 29/3/2026.
//

import SwiftUI

struct PlayersManagerView: View {
    @EnvironmentObject var store: PlayersStore
#if !os(macOS)
    @Environment(\.editMode) private var editMode
#endif
    @State private var newName: String = ""
    enum Field: Hashable { case name }
    @FocusState private var focusedField: Field?
    @State private var editingPlayerID: UUID? = nil
    @State private var editingName: String = ""
    private let maxNameLength: Int = 25
    @State private var showDuplicateAlert: Bool = false
    @State private var duplicateNameForAlert: String = ""
    @State private var showDuplicateRankAlert: Bool = false
    @State private var duplicateRankValue: Int = 0
    @State private var duplicateRankConflictName: String = ""
    @State private var showRankValidationAlert: Bool = false
    @State private var rankValidationMessage: String = ""
    @State private var rankInputs: [UUID: String] = [:]
    @State private var navigateToDraw: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Add players and assign a rank to each before starting the tournament")
                    .font(.title).bold()
                Spacer()
                Button("Clear All") {
                    store.clearAll()
                    // Reset all ranking-related UI state and inputs
                    rankInputs.removeAll()
                    showDuplicateRankAlert = false
                    duplicateRankValue = 0
                    duplicateRankConflictName = ""
                }
                .disabled(store.players.isEmpty)
            }

            HStack(spacing: 12) {
                TextField("Enter player name", text: Binding(
                    get: { newName },
                    set: { newValue in newName = String(newValue.prefix(maxNameLength)) }
                ))
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(width: 250)
                    .font(.title2)
                    .focused($focusedField, equals: .name)
                    .onSubmit { addPlayer() }
            }

            List {
                ForEach(Array(store.players.enumerated()), id: \.element.id) { index, player in
                    HStack {
                        TextField("Rank", text: Binding(
                            get: { rankInputs[player.id] ?? "" },
                            set: { newValue in
                                let filtered = newValue.filter { $0.isNumber }
                                rankInputs[player.id] = filtered
                            }
                        ))
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(width: 50)
                        .multilineTextAlignment(.center)

                        if editingPlayerID == player.id {
                            TextField("", text: Binding(
                                get: { editingName },
                                set: { newValue in editingName = String(newValue.prefix(maxNameLength)) }
                            ), onCommit: {
                                let trimmed = editingName.trimmingCharacters(in: .whitespacesAndNewlines)
                                let limited = String(trimmed.prefix(maxNameLength))
                                if limited.isEmpty {
                                    editingPlayerID = nil
                                    editingName = ""
                                    return
                                }
                                if store.players.contains(where: { $0.name.caseInsensitiveCompare(limited) == .orderedSame && $0.id != player.id }) {
                                    duplicateNameForAlert = limited
                                    showDuplicateAlert = true
                                    return
                                }
                                store.rename(playerID: player.id, to: limited)
                                editingPlayerID = nil
                                editingName = ""
                            })
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .frame(width: 250)
                            .font(.title2)
                        } else {
                            Text(player.name)
                                .lineLimit(1)
                                .truncationMode(.tail)
                                .frame(width: 250, alignment: .leading)
                                .font(.title2)
                        }

                        if editingPlayerID != player.id {
                            HStack(spacing: 8) {
                                Button {
                                    editingPlayerID = player.id
                                    editingName = player.name
                                } label: {
                                    Image(systemName: "pencil")
                                }
                                Button {
                                    store.remove(at: IndexSet(integer: index))
                                } label: {
                                    Image(systemName: "trash")
                                }
                            }
                            .buttonStyle(.borderless)
                        }

                        // Mask the trailing area to hide the selection highlight to the right of the buttons
                        Rectangle()
                            .fill(.background)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .allowsHitTesting(false)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button {
                            store.remove(at: IndexSet(integer: index))
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                        .tint(.primary)
                        Button {
                            editingPlayerID = player.id
                            editingName = player.name
                        } label: {
                            Label("Edit", systemImage: "pencil")
                        }
                        .tint(.primary)
                    }
                    .contextMenu {
                        Button("Edit Name") {
                            editingPlayerID = player.id
                            editingName = player.name
                        }
                        Button {
                            store.remove(at: IndexSet(integer: index))
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
                .onMove(perform: store.move(from:to:))
            }
            .listStyle(.plain)
            .listRowSeparator(.hidden)
            .toolbar {
#if !os(macOS)
                Button(action: {
                    if editMode?.wrappedValue == .active {
                        editMode?.wrappedValue = .inactive
                    } else {
                        editMode?.wrappedValue = .active
                    }
                }) {
                    Text(editMode?.wrappedValue == .active ? "Done" : "Edit")
                }
                .tint(.primary)
#endif
            }
            
            HStack {
                Spacer()
                Button("Start Tournament") {
                    applyRanks()
                }
                .buttonStyle(LiquidGlassButtonStyle())
                .font(.title2)
                .padding(.top, 8)
                Spacer()
            }

            Spacer()
        }
        .navigationDestination(isPresented: $navigateToDraw) {
            FirstRoundDrawView()
        }
        .padding()
        .tint(.primary)
        .onAppear {
            DispatchQueue.main.async {
                focusedField = .name
            }
        }
        .alert("Duplicate Name", isPresented: $showDuplicateAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("A player named \"\(duplicateNameForAlert)\" already exists.")
        }
        .alert("Duplicate Rank", isPresented: $showDuplicateRankAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Rank \(duplicateRankValue) has already been assigned to \(duplicateRankConflictName). Please choose a unique rank.")
        }
        .alert("Ranking Incomplete", isPresented: $showRankValidationAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(rankValidationMessage)
        }
    }

    private func addPlayer() {
        let trimmedName = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        let limitedName = String(trimmedName.prefix(maxNameLength))
        guard !limitedName.isEmpty else { return }
        if store.players.contains(where: { $0.name.caseInsensitiveCompare(limitedName) == .orderedSame }) {
            duplicateNameForAlert = limitedName
            showDuplicateAlert = true
            return
        }
        store.add(name: limitedName)
        newName = ""
        focusedField = .name
    }
    
    private func applyRanks() {
        let players = store.players
        let count = players.count
        // Build mapping from player id to entered rank
        var idToRank: [UUID: Int] = [:]
        for p in players {
            if let text = rankInputs[p.id], let val = Int(text), (1...count).contains(val) {
                idToRank[p.id] = val
            }
        }
        // Ensure every player has a rank
        if idToRank.count != count {
            let missing = count - idToRank.count
            rankValidationMessage = "Please enter a unique rank between 1 and \(count) for every player. Missing \(missing) rank\(missing == 1 ? "" : "s")."
            showRankValidationAlert = true
            return
        }
        // Ensure uniqueness
        let ranks = Array(idToRank.values)
        if Set(ranks).count != ranks.count {
            // Find one duplicate and report involved names
            var seen = Set<Int>()
            var dup: Int? = nil
            for r in ranks {
                if seen.contains(r) { dup = r; break } else { seen.insert(r) }
            }
            if let dup = dup {
                duplicateRankValue = dup
                let names = players.compactMap { p in idToRank[p.id] == dup ? p.name : nil }
                duplicateRankConflictName = names.joined(separator: " and ")
                showDuplicateRankAlert = true
            } else {
                rankValidationMessage = "Duplicate ranks detected. Please ensure each rank is unique."
                showRankValidationAlert = true
            }
            return
        }
        // Commit in ascending rank order
        let sortedIDs = idToRank.sorted { $0.value < $1.value }.map { $0.key }
        for (idx, id) in sortedIDs.enumerated() {
            store.setRank(for: id, to: idx + 1)
        }
        // Keep applied ranks visible in the text fields
        rankInputs = Dictionary(uniqueKeysWithValues: store.players.map { ($0.id, String($0.ranking)) })
        navigateToDraw = true
    }
}

struct LiquidGlassButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                .ultraThinMaterial,
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.primary.opacity(configuration.isPressed ? 0.35 : 0.25), lineWidth: 1.25)
            )
            .shadow(color: .black.opacity(0.12), radius: 10, x: 0, y: 6)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
    }
}

#Preview {
    PlayersManagerView()
        .environmentObject(PlayersStore())
}





