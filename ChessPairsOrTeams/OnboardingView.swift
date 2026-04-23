//
//  OnboardingView.swift
//  ChessKit
//
//  Created by G Dawson on 01/04/2026.
//

import SwiftUI

struct OnboardingView: View {
    let onFinish: (() -> Void)?
    let onStartTeams: (() -> Void)?
    init(onFinish: (() -> Void)? = nil, onStartTeams: (() -> Void)? = nil) {
        self.onFinish = onFinish
        self.onStartTeams = onStartTeams
    }
    @State private var selection: Int = 0

    var body: some View {
        ZStack {
            OnboardingBackground()

            VStack(spacing: 24) {
                Spacer(minLength: 0)

                TabView(selection: $selection) {
                    OnboardingPage(
                        title: "Welcome to ChessKit",
                        subtitle: "Use this application to run a SWISS style chess tournament",
                        description: "for individual or teams of four",
                        symbol: "checkerboard.rectangle"
                    )
                    .tag(0)

                    OnboardingPage(
                        title: "Manage Players",
                        subtitle: "Add or edit players. Built‑in checks prevent any conflicts",
                        description: "Start the tournament",
                        symbol: "person.3.sequence"
                        
                    )
                    .tag(1)

                    OnboardingPage(
                        title: "Score the Matches",
                        subtitle: "Follow the progressive scores",
                        description: "Finalise and view the placings by ending the tournament.\nSave and Export results - spreadsheet compliant.\nClose Tournament",
                        symbol: "list.number"
                    )
                    .tag(2)
                }
                .frame(maxWidth: 820, maxHeight: 500)
#if !os(macOS)
                .tabViewStyle(.page)
                .indexViewStyle(.page(backgroundDisplayMode: .always))
#endif

                HStack(spacing: 12) {
                    if selection > 0 {
                        Button("Back") {
                            withAnimation { selection = max(0, selection - 1) }
                        }
                        .buttonStyle(LiquidGlassButtonStyle())
                    }

                    Spacer()

                    if selection == 2 {
                        VStack(alignment: .trailing, spacing: 8) {
                            Button("Get Started - Individual") {
                                onFinish?()
                            }
                            .buttonStyle(LiquidGlassButtonStyle())
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(Color.blue, lineWidth: 1.5)
                            )

                            Button("Get Started - Teams") {
                                onStartTeams?()
                            }
                            .buttonStyle(LiquidGlassButtonStyle())
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(Color.purple, lineWidth: 1.5)
                            )
                        }
                    } else {
                        Button("Next") {
                            withAnimation { selection = min(2, selection + 1) }
                        }
                        .buttonStyle(LiquidGlassButtonStyle())
                    }
                }
                .frame(maxWidth: 820)

                Spacer(minLength: 12)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 32)
        }
        .overlay(alignment: .topTrailing) {
            if selection == 0 {
                if let onFinish = onFinish {
                    VStack(alignment: .trailing, spacing: 8) {
                        Button("Skip to Start - Individual") {
                            onFinish()
                        }
                        .buttonStyle(LiquidGlassButtonStyle())
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color.blue, lineWidth: 1.5)
                        )

                        Button("Skip to Start - Teams") {
                            onStartTeams?()
                        }
                        .buttonStyle(LiquidGlassButtonStyle())
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color.purple, lineWidth: 1.5)
                        )
                    }
                    .padding(.top, 16)
                    .padding(.trailing, 16)
                }
            }
        }
    }
}

private struct OnboardingPage: View {
    let title: String
    let subtitle: String
    let description: String
    let symbol: String

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: symbol)
                .symbolRenderingMode(.hierarchical)
                .font(.system(size: 64, weight: .semibold))
                .foregroundStyle(.primary)
                .padding(16)
                .background(
                    .ultraThinMaterial,
                    in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.primary.opacity(0.25), lineWidth: 1.0)
                )
                .shadow(color: .black.opacity(0.12), radius: 16, x: 0, y: 10)

            Text(title)
                .font(.system(size: 40, weight: .bold))
                .multilineTextAlignment(.center)

            Text(subtitle)
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Text(description)
                .font(.system(size: 20))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 600)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            .ultraThinMaterial,
            in: RoundedRectangle(cornerRadius: 24, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.primary.opacity(0.25), lineWidth: 1.25)
        )
        .shadow(color: .black.opacity(0.18), radius: 20, x: 0, y: 12)
        .padding()
    }
}

private struct OnboardingBackground: View {
    var body: some View {
        Rectangle()
            .fill(.ultraThinMaterial)
            .ignoresSafeArea()
    }
}

#Preview {
    OnboardingView()
}

