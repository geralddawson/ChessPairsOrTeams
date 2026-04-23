//
//  ChessKitnApp.swift
//  ChessKitn
//
//  Created by Gerald Dawson on 3/4/2026.
//



import SwiftUI

struct RootView: View {
    @State private var showingPlayersManager = false
    @State private var showingTeamsManager = false

    var body: some View {
        if showingPlayersManager {
            NavigationStack {
                PlayersManagerView()
            }
        } else if showingTeamsManager {
            NavigationStack {
                TeamsManagerView()
            }
        } else {
            OnboardingView(onFinish: {
                showingPlayersManager = true
            }, onStartTeams: {
                showingTeamsManager = true
            })
        }
    }
}


@main
struct ChessPairsOrTeams: App {
    @StateObject private var store = PlayersStore()
    @StateObject private var teamsStore = TeamsStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .environmentObject(teamsStore)
        }
    }
}


