import Foundation
import GlucoKit
import Observation

/// Issue d'une tentative de connexion. Le cas « indéterminé » est distinct du
/// refus : afficher « mot de passe incorrect » sur une coupure réseau
/// pousserait à retaper, donc à verrouiller le compte Dexcom.
enum SignInOutcome: Equatable {
    case success
    case rejected
    case undetermined
}

@MainActor
@Observable
final class AppModel {
    private let refresher: GlucoseRefresher
    private let credentialStore: CredentialStore
    private let store: SharedStore

    private(set) var snapshot = GlucoSnapshot()
    private(set) var isRefreshing = false
    private(set) var isSignedIn = false
    private(set) var accountName: String?
    var settings: GlucoSettings

    /// Cadence de rafraîchissement au premier plan. Dexcom produit une mesure
    /// toutes les 5 min ; on sonde plus souvent uniquement pour rattraper vite
    /// une mesure qui vient de tomber.
    private static let foregroundInterval: Duration = .seconds(60)

    init(
        refresher: GlucoseRefresher = .shared,
        credentialStore: CredentialStore = .shared,
        store: SharedStore = .shared
    ) {
        self.refresher = refresher
        self.credentialStore = credentialStore
        self.store = store
        self.settings = store.loadSettings()
    }

    /// Affiche immédiatement la dernière photo connue, puis va chercher du frais.
    func start() async {
        #if DEBUG
        // `-demo hypo` au lancement : affiche un état synthétique sans toucher
        // à Dexcom. Sert à vérifier le rendu des états qu'on ne peut pas
        // provoquer à la demande.
        if let demoState = Self.demoState {
            isSignedIn = true
            accountName = "démonstration"
            snapshot = .demo(state: demoState, settings: settings)
            return
        }
        #endif
        reloadIdentity()
        snapshot = await refresher.cachedSnapshot()
        settings = store.loadSettings()
        guard isSignedIn else { return }
        await refresh()
    }

    /// Boucle de premier plan. Annulée dès que la vue disparaît.
    func runForegroundLoop() async {
        while !Task.isCancelled {
            try? await Task.sleep(for: Self.foregroundInterval)
            guard !Task.isCancelled, isSignedIn else { continue }
            await refresh()
        }
    }

    func refresh(force: Bool = false) async {
        #if DEBUG
        if Self.demoState != nil { return }
        #endif
        guard isSignedIn, !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        snapshot = await refresher.refresh(force: force)
    }

    func signIn(accountName: String, password: String, region: ShareRegion) async -> SignInOutcome {
        let credentials = ShareCredentials(
            accountName: accountName.trimmingCharacters(in: .whitespacesAndNewlines),
            password: password
        )
        do {
            guard try await refresher.signIn(credentials: credentials, region: region) else {
                return .rejected
            }
        } catch {
            return .undetermined
        }
        reloadIdentity()
        settings = store.loadSettings()
        await refresh(force: true)
        return .success
    }

    func signOut() async {
        await refresher.signOut()
        reloadIdentity()
        snapshot = GlucoSnapshot(settings: settings)
    }

    func save(settings newSettings: GlucoSettings) async {
        settings = newSettings.sanitized
        // Les seuils changent la lecture de la mesure courante : on réévalue
        // sans attendre le prochain cycle.
        snapshot = await refresher.update(settings: settings)
    }

    #if DEBUG
    /// `-demo <état>` sur la ligne de commande de lancement, par exemple
    /// `-demo hypo`. Absent en production : tout ce bloc est compilé en Debug
    /// uniquement.
    static var demoState: GlucoseState? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "-demo"),
              index + 1 < arguments.count
        else { return nil }
        return GlucoseState(rawValue: arguments[index + 1])
    }
    #endif

    private func reloadIdentity() {
        let credentials = credentialStore.load()
        isSignedIn = credentials != nil
        accountName = credentials?.accountName
    }
}
