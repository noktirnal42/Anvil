// MARK: - Tests (System5 lesson: unit tests for core logic, not just resource layout)

import XCTest
@testable import AnvilKit

@MainActor
final class AnvilTests: XCTestCase {
    func testDefaultProviderIsOpenCode() {
        let registry = ProviderRegistry.shared
        XCTAssertEqual(registry.default.id, "opencode")
    }

    func testThemeDefaultsToWarmMinimal() {
        let manager = ThemeManager.shared
        XCTAssertEqual(manager.theme.id, "warm-minimal")
    }

    func testAllThemesHaveUniqueIDs() {
        let ids = AnvilTheme.all.map { $0.id }
        XCTAssertEqual(Set(ids).count, AnvilTheme.all.count)
    }

    func testProviderDescriptorHashable() {
        let a = ProviderDescriptor(id: "x", name: "X")
        let b = ProviderDescriptor(id: "x", name: "Y")
        let a2 = ProviderDescriptor(id: "x", name: "X")
        XCTAssertEqual(a, a2)      // same content -> equal
        XCTAssertNotEqual(a, b)    // different name -> not equal
        XCTAssertEqual(Set([a, b, a2]).count, 2) // hashable & dedupes identical values
    }

    func testMatrixThemeHasAmbientGlyphAndScanlines() {
        let matrix = AnvilTheme.matrixTechy
        XCTAssertNotNil(matrix.ambientGlyph)
        XCTAssertTrue(matrix.scanline)
        XCTAssertTrue(matrix.glow)
    }

    func testWarmThemeHasNoAmbientGlyph() {
        XCTAssertNil(AnvilTheme.warmMinimal.ambientGlyph)
        XCTAssertFalse(AnvilTheme.warmMinimal.scanline)
    }
}
