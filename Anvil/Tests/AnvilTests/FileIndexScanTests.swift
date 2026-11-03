// MARK: - Tests: direct filesystem scan used by the Files index

import XCTest
@testable import AnvilKit

final class FileIndexScanTests: XCTestCase {
    private var root: URL!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("anvil-scan-\(UUID().uuidString)")
        let fm = FileManager.default
        try fm.createDirectory(at: root.appendingPathComponent("sub"), withIntermediateDirectories: true)
        try fm.createDirectory(at: root.appendingPathComponent("node_modules/pkg"), withIntermediateDirectories: true)
        try fm.createDirectory(at: root.appendingPathComponent(".git"), withIntermediateDirectories: true)
        try "a".write(to: root.appendingPathComponent("a.txt"), atomically: true, encoding: .utf8)
        try "b".write(to: root.appendingPathComponent("sub/b.swift"), atomically: true, encoding: .utf8)
        try "x".write(to: root.appendingPathComponent("node_modules/pkg/index.js"), atomically: true, encoding: .utf8)
        try "h".write(to: root.appendingPathComponent(".hidden.txt"), atomically: true, encoding: .utf8)
        try "g".write(to: root.appendingPathComponent(".git/config"), atomically: true, encoding: .utf8)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
    }

    func testScanReturnsRegularFilesAndSkipsDependencyAndHiddenFolders() {
        let names = FileIndexService.scan(roots: [root], limit: 100).map(\.name).sorted()

        XCTAssertEqual(names, ["a.txt", "b.swift"])
    }

    func testScanRecordsPathsAndContentTypes() {
        let files = FileIndexService.scan(roots: [root], limit: 100)

        let swift = files.first { $0.name == "b.swift" }
        // Paths may differ from the temp URL by /var vs /private/var, so check the file itself.
        XCTAssertNotNil(swift)
        XCTAssertTrue(FileManager.default.fileExists(atPath: swift?.path ?? ""))
        XCTAssertEqual(URL(fileURLWithPath: swift?.path ?? "").deletingLastPathComponent().lastPathComponent, "sub")
        XCTAssertNotNil(swift?.uti)
    }

    func testScanStopsAtTheLimit() {
        let files = FileIndexService.scan(roots: [root], limit: 1)

        XCTAssertEqual(files.count, 1)
    }

    func testScanOfMissingFolderReturnsNothing() {
        let missing = root.appendingPathComponent("does-not-exist")

        XCTAssertTrue(FileIndexService.scan(roots: [missing], limit: 100).isEmpty)
    }
}
