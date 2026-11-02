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

    func testCreateSessionPersists() {
        let store = SessionStore.shared
        let before = store.sessions.count
        let s = store.createSession(title: "Test Session", provider: "openai", model: "gpt-5")
        XCTAssertEqual(store.sessions.count, before + 1)
        XCTAssertEqual(store.selectedSession?.id, s.id)
        XCTAssertEqual(s.title, "Test Session")
        XCTAssertEqual(s.provider, "openai")
        XCTAssertEqual(s.model, "gpt-5")
    }

    func testAppendMessage() {
        let store = SessionStore.shared
        let s = store.createSession(title: "Msg Test")
        store.appendMessage(to: s, role: "user", content: "hello", isComplete: true)
        store.appendMessage(to: s, role: "assistant", content: "hi", isComplete: true)
        XCTAssertEqual(s.messages.count, 2)
        XCTAssertTrue(s.messages.contains { $0.role == "user" && $0.content == "hello" })
        XCTAssertTrue(s.messages.contains { $0.role == "assistant" && $0.content == "hi" })
        XCTAssertTrue(s.messages.allSatisfy { !$0.isStreaming })
    }

    func testUpdateLastMessage() {
        let store = SessionStore.shared
        let s = store.createSession(title: "Update Test")
        store.appendMessage(to: s, role: "assistant", content: "partial", isStreaming: true, isComplete: false)
        store.updateLastMessage(in: s, content: "partial + more", isStreaming: false, isComplete: true)
        XCTAssertTrue(s.messages.contains { $0.content == "partial + more" })
        XCTAssertTrue(s.messages.allSatisfy { !$0.isStreaming })
        XCTAssertTrue(s.messages.allSatisfy { $0.isComplete })
    }

    func testDeleteSession() {
        let store = SessionStore.shared
        let s = store.createSession(title: "To Delete")
        store.deleteSession(s)
        XCTAssertFalse(store.sessions.contains { $0.id == s.id })
    }
}
