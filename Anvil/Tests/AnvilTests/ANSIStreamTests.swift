// MARK: - Tests: ANSI terminal output parsing

import XCTest
import SwiftUI
@testable import AnvilKit

final class ANSIStreamTests: XCTestCase {
    func testPlainTextPassesThrough() {
        var stream = ANSIStream()
        XCTAssertEqual(String(stream.append("hello\nworld").characters), "hello\nworld")
    }

    func testCursorAndEraseSequencesAreDropped() {
        var stream = ANSIStream()
        let output = stream.append("\u{1B}[2K\u{1B}[1Ahi\u{1B}[0K")
        XCTAssertEqual(String(output.characters), "hi")
    }

    func testCarriageReturnIsDropped() {
        var stream = ANSIStream()
        XCTAssertEqual(String(stream.append("line\r\n").characters), "line\n")
    }

    func testColourAppliesToItsRunAndResetRestoresDefault() {
        var stream = ANSIStream()
        let output = stream.append("\u{1B}[31mred\u{1B}[0m plain")

        XCTAssertEqual(String(output.characters), "red plain")
        let redRun = output.runs.first
        XCTAssertNotNil(redRun?.foregroundColor)
        let plainRun = output.runs.last
        XCTAssertNil(plainRun?.foregroundColor)
    }

    func testSequenceSplitAcrossChunksIsHeldUntilComplete() {
        var stream = ANSIStream()
        let first = stream.append("\u{1B}[3")
        XCTAssertTrue(first.characters.isEmpty)

        let second = stream.append("1mX")
        XCTAssertEqual(String(second.characters), "X")
        XCTAssertNotNil(second.runs.first?.foregroundColor)
    }

    func testOSCTitleIsDroppedWhenTerminatedByBEL() {
        var stream = ANSIStream()
        let output = stream.append("\u{1B}]0;title\u{7}prompt$ ")
        XCTAssertEqual(String(output.characters), "prompt$ ")
    }
}
