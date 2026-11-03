// MARK: - ANSI terminal output → styled text

// Turns raw pty output into AttributedString. Colour (SGR 30–37, 90–97, 39),
// bold and reset are applied; cursor movement, erase, title and other control
// sequences are dropped. An escape sequence split across two reads is held
// back until its end arrives.

import Foundation
import SwiftUI

public struct ANSIStream {
    private var pending = ""
    private var foreground: Color?
    private var bold = false

    public init() {}

    /// Appends a chunk of raw output and returns the styled text it produces.
    public mutating func append(_ chunk: String) -> AttributedString {
        let input = pending + chunk
        pending = ""

        var result = AttributedString()
        var run = ""
        var index = input.startIndex

        func flushRun() {
            guard !run.isEmpty else { return }
            var piece = AttributedString(run)
            piece.foregroundColor = foreground
            if bold {
                piece.font = .body.bold()
            }
            result += piece
            run = ""
        }

        while index < input.endIndex {
            let character = input[index]
            switch character {
            case "\u{1B}":
                guard let end = Self.escapeEnd(in: input, from: index) else {
                    // Incomplete sequence: keep it for the next chunk.
                    flushRun()
                    pending = String(input[index...])
                    return result
                }
                let sequence = input[index..<end]
                if sequence.hasPrefix("\u{1B}["), sequence.last == "m" {
                    flushRun()
                    applySGR(String(sequence.dropFirst(2).dropLast()))
                }
                index = end
            case "\r\n":
                // Swift reads CRLF as one character; keep only the line feed.
                run.append("\n")
                index = input.index(after: index)
            case "\r":
                // A bare carriage return only moves the cursor.
                index = input.index(after: index)
            default:
                run.append(character)
                index = input.index(after: index)
            }
        }
        flushRun()
        return result
    }

    /// Index just past the escape sequence that starts at `start`, or nil when
    /// the sequence is not complete yet.
    private static func escapeEnd(in input: String, from start: String.Index) -> String.Index? {
        let afterEscape = input.index(after: start)
        guard afterEscape < input.endIndex else { return nil }

        switch input[afterEscape] {
        case "[":
            // CSI: parameter and intermediate bytes, then one final byte 0x40–0x7E.
            var index = input.index(after: afterEscape)
            while index < input.endIndex {
                if let scalar = input[index].unicodeScalars.first,
                   (0x40...0x7E).contains(scalar.value) {
                    return input.index(after: index)
                }
                index = input.index(after: index)
            }
            return nil
        case "]":
            // OSC: ends with BEL or ESC \.
            var index = input.index(after: afterEscape)
            while index < input.endIndex {
                if input[index] == "\u{7}" {
                    return input.index(after: index)
                }
                if input[index] == "\u{1B}" {
                    let next = input.index(after: index)
                    guard next < input.endIndex else { return nil }
                    if input[next] == "\\" {
                        return input.index(after: next)
                    }
                }
                index = input.index(after: index)
            }
            return nil
        default:
            // Two-character escape such as ESC = or ESC 7.
            return input.index(after: afterEscape)
        }
    }

    private mutating func applySGR(_ parameters: String) {
        let codes = parameters.isEmpty
            ? [0]
            : parameters.split(separator: ";", omittingEmptySubsequences: false).map { Int($0) ?? 0 }
        for code in codes {
            switch code {
            case 0:
                foreground = nil
                bold = false
            case 1:
                bold = true
            case 22:
                bold = false
            case 30...37:
                foreground = Self.palette[code - 30]
            case 39:
                foreground = nil
            case 90...97:
                foreground = Self.palette[code - 90 + 8]
            default:
                break
            }
        }
    }

    /// Standard and bright ANSI colours, tuned to read on a light terminal background.
    static let palette: [Color] = [
        Color(red: 0.10, green: 0.10, blue: 0.10),  // black
        Color(red: 0.75, green: 0.15, blue: 0.15),  // red
        Color(red: 0.15, green: 0.50, blue: 0.20),  // green
        Color(red: 0.65, green: 0.45, blue: 0.00),  // yellow
        Color(red: 0.15, green: 0.35, blue: 0.75),  // blue
        Color(red: 0.55, green: 0.25, blue: 0.60),  // magenta
        Color(red: 0.05, green: 0.50, blue: 0.55),  // cyan
        Color(red: 0.45, green: 0.42, blue: 0.40),  // white (grey on light)
        Color(red: 0.35, green: 0.35, blue: 0.35),  // bright black
        Color(red: 0.90, green: 0.25, blue: 0.25),  // bright red
        Color(red: 0.25, green: 0.65, blue: 0.30),  // bright green
        Color(red: 0.80, green: 0.60, blue: 0.10),  // bright yellow
        Color(red: 0.25, green: 0.50, blue: 0.90),  // bright blue
        Color(red: 0.70, green: 0.40, blue: 0.75),  // bright magenta
        Color(red: 0.10, green: 0.65, blue: 0.70),  // bright cyan
        Color(red: 0.20, green: 0.16, blue: 0.12),  // bright white (text colour)
    ]
}
