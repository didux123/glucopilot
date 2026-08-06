import Foundation

/// Stockage partagé entre l'app et son extension (widget + Live Activity), via
/// l'App Group.
///
/// Tout ce qui transite ici est petit : la dernière photo de l'état, les
/// réglages, l'état de session. Les identifiants, eux, ne passent **jamais**
/// par là — ils vivent dans le Trousseau (`CredentialStore`).
public final class SharedStore: SessionStateStore, @unchecked Sendable {
    public static let appGroupID = "group.com.didux.glucopilot"

    private enum Key {
        static let snapshot = "snapshot"
        static let settings = "settings"
        static let session = "sessionState"
    }

    private let defaults: UserDefaults

    /// - Parameter suiteName: l'App Group en production. Les tests passent une
    ///   suite jetable pour ne pas polluer les réglages réels.
    public init(suiteName: String = SharedStore.appGroupID) {
        // Si l'App Group n'est pas encore configuré dans les entitlements,
        // `UserDefaults(suiteName:)` renvoie nil : on retombe sur les réglages
        // standard plutôt que de planter, mais l'extension ne verra rien.
        defaults = UserDefaults(suiteName: suiteName) ?? .standard
    }

    public static let shared = SharedStore()

    // MARK: - Photo de l'état

    public func loadSnapshot() -> GlucoSnapshot? {
        decode(GlucoSnapshot.self, forKey: Key.snapshot)
    }

    public func save(snapshot: GlucoSnapshot) {
        encode(snapshot, forKey: Key.snapshot)
    }

    // MARK: - Réglages

    public func loadSettings() -> GlucoSettings {
        (decode(GlucoSettings.self, forKey: Key.settings) ?? .default).sanitized
    }

    public func save(settings: GlucoSettings) {
        encode(settings.sanitized, forKey: Key.settings)
    }

    // MARK: - Session Dexcom

    public func loadSessionState() -> SessionState {
        decode(SessionState.self, forKey: Key.session) ?? .empty
    }

    public func saveSessionState(_ state: SessionState) {
        encode(state, forKey: Key.session)
    }

    // MARK: - Codage

    private func decode<T: Decodable>(_ type: T.Type, forKey key: String) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    private func encode(_ value: some Encodable, forKey key: String) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        defaults.set(data, forKey: key)
    }

    /// Utilisé par les tests pour repartir propre.
    public func removeAll() {
        [Key.snapshot, Key.settings, Key.session].forEach(defaults.removeObject(forKey:))
    }
}
