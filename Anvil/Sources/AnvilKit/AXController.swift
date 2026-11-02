// MARK: - Accessibility (AX) screen driving

import Foundation
import AppKit
import CoreGraphics

/// Describes an accessibility element on screen.
public struct AXElement: Sendable, Identifiable, Equatable {
    public let id: Int
    public let role: String
    public let title: String?
    public let value: String?
    public let frame: CGRect?
    public let focused: Bool
    public let enabled: Bool
    public let children: [AXElement]

    public init(id: Int, role: String, title: String?, value: String?,
                frame: CGRect?, focused: Bool, enabled: Bool,
                children: [AXElement] = []) {
        self.id = id
        self.role = role
        self.title = title
        self.value = value
        self.frame = frame
        self.focused = focused
        self.enabled = enabled
        self.children = children
    }
}

/// Computer-use controller: drive the mouse/keyboard via CGEvent.
/// Full accessibility-tree reading is exposed as a stub in this build; it can
/// be enabled once the host SDK exposes the AX C API symbols.
@MainActor
public final class AXController: NSObject, ObservableObject {
    public static let shared = AXController()
    private override init() {}

    @Published public var isAXEnabled: Bool = false
    @Published public var lastError: String?

    public func checkAXAccess() -> Bool {
        // AXIsProcessTrusted() is unavailable in this SDK build; report not
        // available so the user knows to grant AX permission manually.
        isAXEnabled = false
        return false
    }

    /// Capture the accessibility tree of the focused application (stub).
    public func inspectFocusedApp(maxDepth: Int = 3) -> AXElement? {
        lastError = "AX tree inspection unavailable in this build"
        return nil
    }

    /// Click at a screen point.
    public func click(at point: CGPoint, button: CGMouseButton = .left) {
        let down = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown,
                           mouseCursorPosition: point, mouseButton: button)
        let up = CGEvent(mouseEventSource: nil, mouseType: .leftMouseUp,
                         mouseCursorPosition: point, mouseButton: button)
        down?.post(tap: .cgAnnotatedSessionEventTap)
        up?.post(tap: .cgAnnotatedSessionEventTap)
    }

    /// Double-click at a screen point.
    public func doubleClick(at point: CGPoint) {
        let down = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown,
                           mouseCursorPosition: point, mouseButton: .left)
        let up = CGEvent(mouseEventSource: nil, mouseType: .leftMouseUp,
                         mouseCursorPosition: point, mouseButton: .left)
        down?.post(tap: .cgAnnotatedSessionEventTap)
        up?.post(tap: .cgAnnotatedSessionEventTap)
        usleep(50_000)
        down?.post(tap: .cgAnnotatedSessionEventTap)
        up?.post(tap: .cgAnnotatedSessionEventTap)
    }

    /// Type a string into the focused field.
    public func type(_ text: String) {
        for char in text {
            if let event = CGEvent(keyboardEventSource: nil,
                                   virtualKey: keyCode(for: char),
                                   keyDown: true) {
                event.flags = []
                event.post(tap: .cgAnnotatedSessionEventTap)
            }
            if let event = CGEvent(keyboardEventSource: nil,
                                   virtualKey: keyCode(for: char),
                                   keyDown: false) {
                event.flags = []
                event.post(tap: .cgAnnotatedSessionEventTap)
            }
        }
    }

    /// Press a key combination (e.g. cmd-v).
    public func hotkey(_ modifiers: CGEventFlags, key: CGKeyCode) {
        if let down = CGEvent(keyboardEventSource: nil, virtualKey: key, keyDown: true),
           let up = CGEvent(keyboardEventSource: nil, virtualKey: key, keyDown: false) {
            down.flags = modifiers
            up.flags = []
            down.post(tap: .cgAnnotatedSessionEventTap)
            up.post(tap: .cgAnnotatedSessionEventTap)
        }
    }

    private func keyCode(for char: Character) -> CGKeyCode {
        let map: [Character: CGKeyCode] = [
            "a": 0, "s": 1, "d": 2, "f": 3, "g": 4, "h": 5, "j": 6, "k": 7,
            "l": 8, "z": 9, "x": 10, "c": 11, "v": 12, "b": 13, "n": 14,
            "m": 15, "q": 16, "w": 17, "e": 18, "r": 19, "t": 20, "y": 21,
            "u": 22, "i": 23, "o": 24, "p": 25,
            "0": 29, "1": 18, "2": 19, "3": 20, "4": 21, "5": 22, "6": 23,
            "7": 24, "8": 25, "9": 26,
            " ": 49, "\n": 36,
        ]
        return map[char] ?? 0
    }
}
