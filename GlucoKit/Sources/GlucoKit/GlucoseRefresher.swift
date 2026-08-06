import Foundation

/// Point d'entrée unique pour récupérer la glycémie : l'app, le widget, la Live
/// Activity et Siri passent tous par ici.
///
/// Ne lève jamais d'erreur — renvoie toujours une photo affichable, avec le
/// champ `failure` renseigné en cas d'échec. Une interface qui ne sait pas
/// afficher son propre échec est plus dangereuse qu'utile quand on conduit.
public actor GlucoseRefresher {
    public static let shared = GlucoseRefresher()

    /// En dessous de cet intervalle, on ressert la photo en cache. Dexcom
    /// produit une mesure toutes les 5 min : interroger plus souvent ne
    /// rapporte rien et multiplie les requêtes sur le compte.
    private static let minimumInterval: TimeInterval = 55

    private let store: SharedStore
    private let credentialStore: CredentialStore
    private let transport: any HTTPTransport

    private var session: ShareSession?
    private var sessionRegion: ShareRegion?

    public init(
        store: SharedStore = .shared,
        credentialStore: CredentialStore = .shared,
        transport: any HTTPTransport = URLSession.dexcomShare
    ) {
        self.store = store
        self.credentialStore = credentialStore
        self.transport = transport
    }

    /// Récupère la glycémie et met à jour la photo partagée.
    ///
    /// - Parameter force: ignore l'intervalle minimum. À réserver aux actions
    ///   explicites de l'utilisateur (tirer pour rafraîchir).
    @discardableResult
    public func refresh(force: Bool = false, now: Date = .now) async -> GlucoSnapshot {
        let settings = store.loadSettings()
        let cached = store.loadSnapshot()

        if !force,
           let cached,
           cached.failure == nil,
           now.timeIntervalSince(cached.fetchedAt) < Self.minimumInterval {
            return cached
        }

        guard let credentials = credentialStore.load() else {
            return persist(
                GlucoSnapshot(
                    readings: cached?.readings ?? [],
                    settings: settings,
                    fetchedAt: now,
                    failure: .notConfigured
                )
            )
        }

        let session = session(for: settings.region)
        do {
            let readings = try await session.fetch(credentials: credentials)
            return persist(
                GlucoSnapshot(readings: readings, settings: settings, fetchedAt: now)
            )
        } catch {
            let failure: SnapshotFailure = (error as? ShareError)?.isFatal == true
                ? .credentialsRejected
                : .unreachable
            // On garde les mesures précédentes : affichées avec leur âge, elles
            // valent mieux qu'un écran vide.
            return persist(
                GlucoSnapshot(
                    readings: cached?.readings ?? [],
                    settings: settings,
                    fetchedAt: now,
                    failure: failure
                )
            )
        }
    }

    /// Dernière photo connue, sans aucun appel réseau.
    public func cachedSnapshot() -> GlucoSnapshot {
        store.loadSnapshot() ?? GlucoSnapshot(settings: store.loadSettings())
    }

    /// Valide des identifiants et, s'ils sont bons, les enregistre et repart sur
    /// une session neuve. Une seule tentative, comme partout ailleurs.
    ///
    /// - Returns: `true` si Dexcom les accepte, `false` s'il les refuse.
    /// - Throws: en cas d'erreur réseau — « indéterminé » n'est pas « refusé ».
    public func signIn(credentials: ShareCredentials, region: ShareRegion) async throws -> Bool {
        var settings = store.loadSettings()
        settings.region = region
        store.save(settings: settings)

        let session = session(for: region)
        await session.reset()

        guard try await session.validate(credentials: credentials) else { return false }

        credentialStore.save(credentials)
        await session.reset()
        return true
    }

    public func signOut() {
        credentialStore.delete()
        store.saveSessionState(.empty)
        session = nil
        sessionRegion = nil
    }

    @discardableResult
    public func update(settings: GlucoSettings) -> GlucoSnapshot {
        let sanitized = settings.sanitized
        store.save(settings: sanitized)
        if sanitized.region != sessionRegion {
            session = nil
            sessionRegion = nil
        }
        // La photo en cache embarque les seuils : sans cette réécriture, le
        // widget continuerait d'évaluer la mesure courante avec les anciens.
        var snapshot = cachedSnapshot()
        snapshot.settings = sanitized
        return persist(snapshot)
    }

    // MARK: - Interne

    private func session(for region: ShareRegion) -> ShareSession {
        if let session, sessionRegion == region { return session }
        let created = ShareSession(region: region, transport: transport, store: store)
        session = created
        sessionRegion = region
        return created
    }

    @discardableResult
    private func persist(_ snapshot: GlucoSnapshot) -> GlucoSnapshot {
        store.save(snapshot: snapshot)
        return snapshot
    }
}
