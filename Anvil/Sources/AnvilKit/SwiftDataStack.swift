// MARK: - SwiftData stack (single container, actor-bound context)

import Foundation
import SwiftData

/// Holds the shared ModelContainer and exposes a main-actor context.
/// All SwiftData access goes through SessionStore, which is @MainActor.
@MainActor
public final class SwiftDataStack {
    public static let shared = SwiftDataStack()
    public let container: ModelContainer
    public var mainContext: ModelContext { container.mainContext }

    private init() {
        do {
            container = try ModelContainer(for: Session.self, Message.self)
        } catch {
            fatalError("Failed to create SwiftData ModelContainer: \(error)")
        }
    }
}
