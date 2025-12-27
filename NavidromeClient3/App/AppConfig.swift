import Foundation
import Observation

@MainActor
@Observable
final class AppConfig {
    static let shared = AppConfig()
    
    private let credentialStore = CredentialStore()
    // Private state is fine; changes to it trigger updates if exposed via computed properties
    // or if we decide to expose 'credentials' publicly later.
    private var credentials: ServerCredentials?

    private init() {
        loadCredentials()
        AppLogger.general.info("[AppConfig] Initialized")
    }
    
    // ... rest of the implementation is identical ...
    // Note: ObservableObject is removed.
}
