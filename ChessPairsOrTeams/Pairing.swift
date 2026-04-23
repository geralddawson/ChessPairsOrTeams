

import Foundation

public enum ResultOption: String, CaseIterable, Codable {
    case none = ""
    case whiteWin = "1-0"
    case draw = "1/2 1/2"
    case blackWin = "0-1"
}

public struct Pairing: Identifiable, Equatable, Codable {
    public let id: UUID
    public let boardLabel: String
    public let whitePlayer: String
    public let blackPlayer: String
    public var result: ResultOption
    public var colorSwapApplied: Bool
    public var blackColorSwapApplied: Bool

    public init(id: UUID = UUID(), boardLabel: String, whitePlayer: String, blackPlayer: String, result: ResultOption, colorSwapApplied: Bool = false, blackColorSwapApplied: Bool = false) {
        self.id = id
        self.boardLabel = boardLabel
        self.whitePlayer = whitePlayer
        self.blackPlayer = blackPlayer
        self.result = result
        self.colorSwapApplied = colorSwapApplied
        self.blackColorSwapApplied = blackColorSwapApplied
    }
}


