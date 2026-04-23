//
//  RoundDrawView.swift
//  ChessKit
//
//  Created by Gerald Dawson on 29/3/2026.
//

import SwiftUI

struct RoundDrawView: View {
    @Binding var pairings: [Pairing]

    @ViewBuilder
    private func swapBadge(_ show: Bool) -> some View {
        if show {
            HStack(spacing: 4) {
                Image(systemName: "arrow.left.arrow.right")
                    .font(.caption)
                    .foregroundColor(.orange)
                    .help("Colors swapped to avoid three consecutive Whites")
            }
        } else {
            EmptyView()
        }
    }
    
    @ViewBuilder
    private func blackSwapBadge(_ show: Bool) -> some View {
        if show {
            HStack(spacing: 4) {
                Image(systemName: "arrow.left.arrow.right")
                    .font(.caption)
                    .foregroundColor(.purple)
                    .help("Colors swapped to avoid three consecutive Blacks")
            }
        } else {
            EmptyView()
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 0) {
               Text("")
                   .frame(width: 90, alignment: .center)
                   .font(.title3.weight(.bold))
                    .foregroundColor(.primary)
                Text("WHITE")
                    .frame(width: 216, alignment: .leading)
                    .font(.system(size: 25, weight: .bold))
                    .foregroundColor(.primary)
                    .padding(.trailing, 8)
                    .shadow(color: .black.opacity(0.20), radius: 3, x: 0, y: 2)
                Text("BLACK")
                    .frame(width: 216, alignment: .leading)
                    .font(.system(size: 25, weight: .bold))
                    .foregroundColor(.primary)
                    .padding(.trailing, 18)
                    .shadow(color: .black.opacity(0.20), radius: 3, x: 0, y: 2)
                Text("")
                    .frame(width: 160, alignment: .leading)
                    .font(.title3.weight(.bold))
                    .foregroundColor(.primary)
            }
            .padding(.bottom, 2)
            ForEach($pairings) { $pairing in
                HStack(spacing: 0) {
                    Text(pairing.boardLabel)
                        .bold()
                        .frame(width: 90, height: 30, alignment: .center)
                        .padding(.trailing, 0)

                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Color.primary.opacity(0.5), lineWidth: 1)
                        .overlay(
                            HStack(spacing: 6) {
                                Text(pairing.whitePlayer)
                                    .font(.body)
                                    .lineLimit(1)
                                    .padding(.leading, 6)
                                Spacer(minLength: 4)
                                swapBadge(pairing.colorSwapApplied)
                                    .padding(.trailing, 6)
                            }
                            .frame(maxWidth: .infinity)
                        )
                        .frame(width: 216, height: 30)
                        .padding(.trailing, 8)

                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Color.primary.opacity(0.5), lineWidth: 1)
                        .overlay(
                            HStack(spacing: 6) {
                                Text(pairing.blackPlayer)
                                    .font(.body)
                                    .lineLimit(1)
                                    .padding(.leading, 6)
                                Spacer(minLength: 4)
                                blackSwapBadge(pairing.blackColorSwapApplied)
                                    .padding(.trailing, 6)
                            }
                            .frame(maxWidth: .infinity)
                        )
                        .frame(width: 216, height: 30)
                        .padding(.trailing, 18)

                    if pairing.boardLabel != "BYE" && pairing.whitePlayer != "BYE" && pairing.blackPlayer != "BYE" {
                        HStack(spacing: 10) {
                            ForEach(ResultOption.allCases.filter { $0 != .none }, id: \.self) { option in
                                Button(action: {
                                    pairing.result = option
                                }) {
                                    Text(option.rawValue)
                                        .frame(width: 48, height: 30)
                                        .background(
                                            RoundedRectangle(cornerRadius: 4)
                                                .stroke(pairing.result == option ? Color.blue : Color.primary.opacity(0.5),
                                                        lineWidth: pairing.result == option ? 2 : 1)
                                        )
                                }
                            }
                        }
                        .frame(width: 160)
                    }
                }
            }
        }
    }
}


