//
//  PlayerRankingView.swift
//  ChessKit
//
//  Created by Gerald Dawson on 29/3/2026.
//

import SwiftUI

struct PlayerRankingsView: View {
    let players: [Player]
    let byePlayerName: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Current Standings")
                .font(.title2)
                .padding(.bottom, 8)
            HStack {
                Text("Rank")
                    .frame(width: 50, alignment: .leading)
                    .font(.caption)
                Text("Name")
                    .frame(width: 120, alignment: .leading)
                    .font(.caption)
                Text("Score")
                    .frame(width: 50, alignment: .leading)
                    .font(.caption)
            }
            Divider()
            ForEach(players) { player in
                HStack(spacing: 0) {
                    Text("\(player.ranking)")
                        .frame(width: 50, alignment: .leading)
                    Text(player.name)
                        .frame(width: 120, alignment: .leading)
                    Text(String(format: "%.1f", player.score))
                        .frame(width: 50, alignment: .center)
                }
                .padding(.vertical, 2)
                .background(
                    player.name == byePlayerName ? AnyView(
                        ZStack {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(.regularMaterial)
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.blue.opacity(0.22))
                        }
                    ) : AnyView(Color.clear)
                )
            }
        }
        .padding()
        .background(.thinMaterial)
        .cornerRadius(18)
    }
}








