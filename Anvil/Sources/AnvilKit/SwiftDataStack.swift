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
        // Tests share SessionStore.shared; keep their data out of the user's real store.
        let inMemory = NSClassFromString("XCTestCase") != nil
        do {
            let configuration = ModelConfiguration(isStoredInMemoryOnly: inMemory)
            container = try ModelContainer(for: Session.self, Message.self,
                                           Artifact.self, ArtifactVersion.self,
                                           FileRecord.self, IndexedFolder.self,
                                           configurations: configuration)
        } catch {
            fatalError("Failed to create SwiftData ModelContainer: \(error)")
        }
    }
}
