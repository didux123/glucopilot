import Foundation

/// Identifiants du compte Dexcom.
public struct ShareCredentials: Sendable, Equatable {
    public let accountName: String
    public let password: String

    public init(accountName: String, password: String) {
        self.accountName = accountName
        self.password = password
    }
}

/// État de session Dexcom, partagé entre l'app et son extension via l'App
/// Group. Le partager évite que chaque processus ne se ré-authentifie de son
/// côté — ce qui multiplierait les tentatives sur le compte.
public struct SessionState: Sendable, Codable, Equatable {
    public var accountName: String?
    public var accountID: String?
    public var sessionID: String?
    /// Dexcom a refusé les identifiants. Tant que ce drapeau est levé, plus
    /// aucune requête n'est émise, par aucun processus.
    public var credentialsRejected: Bool

    public init(
        accountName: String? = nil,
        accountID: String? = nil,
        sessionID: String? = nil,
        credentialsRejected: Bool = false
    ) {
        self.accountName = accountName
        self.accountID = accountID
        self.sessionID = sessionID
        self.credentialsRejected = credentialsRejected
    }

    public static let empty = SessionState()
}

public protocol SessionStateStore: Sendable {
    func loadSessionState() -> SessionState
    func saveSessionState(_ state: SessionState)
}

/// Store en mémoire, pour les tests et les aperçus SwiftUI.
public final class InMemorySessionStore: SessionStateStore, @unchecked Sendable {
    private let lock = NSLock()
    private var state: SessionState

    public init(_ state: SessionState = .empty) { self.state = state }

    public func loadSessionState() -> SessionState {
        lock.withLock { state }
    }

    public func saveSessionState(_ state: SessionState) {
        lock.withLock { self.state = state }
    }
}

/// Session Dexcom Share, avec la règle anti-verrouillage du compte.
///
/// Porté de `dexUpdate` (main.cpp:543). Deux invariants à ne jamais assouplir :
///
/// 1. **Un seul re-login par cycle**, jamais de boucle de retry.
/// 2. **Identifiants refusés = arrêt total**, jusqu'à ce que l'utilisateur les
///    corrige lui-même.
///
/// Un compte Dexcom se verrouille au bout de quelques tentatives ratées, et
/// l'utilisateur perdrait alors l'accès à sa glycémie sur l'app officielle.
/// C'est le risque le plus concret de tout le projet.
public actor ShareSession {
    private let client: ShareClient
    private let store: any SessionStateStore

    public init(
        region: ShareRegion,
        transport: any HTTPTransport = URLSession.dexcomShare,
        store: any SessionStateStore = InMemorySessionStore()
    ) {
        self.client = ShareClient(region: region, transport: transport)
        self.store = store
    }

    /// Un cycle complet : session valide → lecture ; sinon (re)connexion **une**
    /// fois.
    public func fetch(
        credentials: ShareCredentials,
        minutes: Int = 180,
        maxCount: Int = 36
    ) async throws -> [GlucoseReading] {
        var state = store.loadSessionState()

        // Changement de compte : on repart de zéro, y compris sur le refus.
        if state.accountName != credentials.accountName {
            state = SessionState(accountName: credentials.accountName)
            store.saveSessionState(state)
        }

        guard !state.credentialsRejected else { throw ShareError.credentialsRejected }

        do {
            if state.accountID == nil {
                state.accountID = try await client.authenticate(
                    accountName: credentials.accountName,
                    password: credentials.password
                )
                store.saveSessionState(state)
            }
            guard let accountID = state.accountID else { throw ShareError.malformedResponse }

            if state.sessionID == nil {
                state.sessionID = try await client.login(
                    accountID: accountID,
                    password: credentials.password
                )
                store.saveSessionState(state)
            }
            guard let sessionID = state.sessionID else { throw ShareError.malformedResponse }

            do {
                return try await client.readGlucose(
                    sessionID: sessionID, minutes: minutes, maxCount: maxCount
                )
            } catch ShareError.sessionExpired {
                // Session expirée : UN seul re-login. Si la lecture qui suit
                // échoue encore, l'erreur remonte — on ne boucle jamais.
                state.sessionID = nil
                store.saveSessionState(state)

                let renewed = try await client.login(
                    accountID: accountID,
                    password: credentials.password
                )
                state.sessionID = renewed
                store.saveSessionState(state)

                return try await client.readGlucose(
                    sessionID: renewed, minutes: minutes, maxCount: maxCount
                )
            }
        } catch let error as ShareError where error.isFatal {
            state.credentialsRejected = true
            state.accountID = nil
            state.sessionID = nil
            store.saveSessionState(state)
            throw error
        }
    }

    /// Valide un couple e-mail / mot de passe sans toucher à la session
    /// courante — pour répondre à l'utilisateur pendant qu'il est encore sur
    /// l'écran de connexion.
    ///
    /// **Une seule tentative par appel**, comme `dexProbe` (main.cpp:528) : la
    /// première étape de l'API suffit à rejeter un mauvais mot de passe.
    public func validate(credentials: ShareCredentials) async throws -> Bool {
        do {
            _ = try await client.authenticate(
                accountName: credentials.accountName,
                password: credentials.password
            )
            return true
        } catch ShareError.credentialsRejected {
            return false
        }
        // Toute autre erreur (réseau, HTTP) remonte : « indéterminé » n'est pas
        // « refusé », et afficher « mot de passe incorrect » sur une coupure
        // réseau pousserait l'utilisateur à retaper — donc à verrouiller.
    }

    /// À appeler quand l'utilisateur corrige ses identifiants : lève le drapeau
    /// fatal et repart sur une session neuve.
    public func reset() {
        store.saveSessionState(.empty)
    }

    public var isBlocked: Bool {
        store.loadSessionState().credentialsRejected
    }
}
