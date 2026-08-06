import ActivityKit
import AVFAudio
import CoreLocation
import GlucoKit
import Observation

/// Pilote la Live Activity sur la durée d'un trajet, sans serveur.
///
/// Le problème à résoudre : une app iOS suspendue ne peut plus rien
/// rafraîchir, et sans backend il n'y a pas d'APNs pour la réveiller. La
/// réponse tient en trois temps :
///
/// 1. **Au repos**, `startMonitoringSignificantLocationChanges()` tourne en
///    permanence. C'est quasi gratuit en batterie, et surtout ça relance l'app
///    en tâche de fond *même après terminaison* dès qu'on se déplace de
///    ~500 m — autrement dit : « il roule ».
/// 2. **Au réveil**, on regarde si CarPlay est branché, via le port audio
///    `carAudio`. Aucun entitlement requis, contrairement aux API CarPlay.
/// 3. **Pendant le trajet**, on passe en localisation continue, volontairement
///    imprécise (3 km) : on ne veut pas la position, seulement rester vivant
///    pour interroger Dexcom toutes les 60 s et mettre la Live Activity à jour
///    localement.
///
/// Conséquence assumée : si l'app était suspendue au moment où vous branchez
/// le téléphone, la Live Activity n'apparaît qu'après les premières centaines
/// de mètres. C'est le prix du zéro-serveur.
@MainActor
@Observable
final class TripController: NSObject {
    static let shared = TripController()

    /// Cadence d'interrogation pendant le trajet.
    private static let pollInterval: Duration = .seconds(60)
    /// ActivityKit coupe une Live Activity à 8 h. On la relance avant, pour que
    /// la coupure ne tombe jamais en pleine route.
    private static let activityMaxDuration: TimeInterval = 7 * 3600 + 45 * 60

    private let manager = CLLocationManager()
    private let credentialStore: CredentialStore
    private let store: SharedStore
    private var pollTask: Task<Void, Never>?
    private var isMonitoring = false

    private(set) var isTripActive = false

    init(credentialStore: CredentialStore = .shared, store: SharedStore = .shared) {
        self.credentialStore = credentialStore
        self.store = store
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyThreeKilometers
        manager.pausesLocationUpdatesAutomatically = false
    }

    // MARK: - Cycle de vie

    /// À appeler au démarrage de l'app, y compris quand iOS la relance en
    /// tâche de fond après un déplacement.
    func startIfConfigured() {
        #if DEBUG
        // `-trip` : entre en mode trajet sans attendre CarPlay. Indispensable
        // pour le simulateur CarPlay, qui n'est qu'un second écran et ne
        // fournit aucune route audio `carAudio` — la détection réelle ne peut
        // donc pas s'y déclencher.
        if Self.forcesTrip {
            beginTrip()
            return
        }
        #endif
        guard credentialStore.load() != nil else { return }
        beginMonitoring()
        evaluateCarPlay()
    }

    #if DEBUG
    static var forcesTrip: Bool {
        ProcessInfo.processInfo.arguments.contains("-trip")
    }
    #endif

    /// À appeler après une connexion réussie : demande l'autorisation puis
    /// enclenche la surveillance.
    func enable() {
        if manager.authorizationStatus == .notDetermined {
            manager.requestAlwaysAuthorization()
        }
        startIfConfigured()
    }

    func disable() {
        endTrip()
        manager.stopMonitoringSignificantLocationChanges()
        isMonitoring = false
        NotificationCenter.default.removeObserver(self)
    }

    private func beginMonitoring() {
        guard !isMonitoring else { return }
        isMonitoring = true

        // Configurer la session suffit à recevoir les changements de route ;
        // `.mixWithOthers` garantit qu'on ne coupe jamais la musique.
        try? AVAudioSession.sharedInstance().setCategory(.playback, options: [.mixWithOthers])

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(audioRouteChanged),
            name: AVAudioSession.routeChangeNotification,
            object: nil
        )

        manager.startMonitoringSignificantLocationChanges()
    }

    // MARK: - Détection CarPlay

    /// CarPlay se reconnaît à son port de sortie audio. C'est la seule
    /// détection possible sans entitlement CarPlay.
    private var isCarPlayConnected: Bool {
        AVAudioSession.sharedInstance().currentRoute.outputs.contains { $0.portType == .carAudio }
    }

    @objc private nonisolated func audioRouteChanged(_ notification: Notification) {
        Task { @MainActor in self.evaluateCarPlay() }
    }

    private func evaluateCarPlay() {
        if isCarPlayConnected {
            beginTrip()
        } else {
            endTrip()
        }
    }

    // MARK: - Trajet

    private func beginTrip() {
        guard !isTripActive else { return }
        isTripActive = true

        // Localisation continue : c'est elle qui empêche iOS de nous suspendre
        // pendant le trajet. Inutile — et intrusive — quand le trajet est
        // forcé pour un essai.
        #if DEBUG
        let usesLocation = !Self.forcesTrip
        #else
        let usesLocation = true
        #endif
        if usesLocation {
            manager.allowsBackgroundLocationUpdates =
                manager.authorizationStatus == .authorizedAlways
            manager.startUpdatingLocation()
        }

        pollTask = Task { [weak self] in
            await self?.runTripLoop()
        }
    }

    private func endTrip() {
        guard isTripActive else { return }
        isTripActive = false

        pollTask?.cancel()
        pollTask = nil
        manager.stopUpdatingLocation()
        manager.allowsBackgroundLocationUpdates = false

        store.tripStartedAt = nil
        Task { await Self.endAllActivities() }
    }

    private func runTripLoop() async {
        while !Task.isCancelled {
            await publish(currentSnapshot())
            try? await Task.sleep(for: Self.pollInterval)
        }
    }

    private func currentSnapshot() async -> GlucoSnapshot {
        #if DEBUG
        if let demoState = AppModel.demoState { return .demo(state: demoState) }
        #endif
        return await GlucoseRefresher.shared.refresh()
    }

    // MARK: - Live Activity

    private func publish(_ snapshot: GlucoSnapshot) async {
        guard let state = snapshot.activityState() else { return }

        // Passé le plafond des 8 h, ActivityKit couperait de lui-même : on
        // reprend la main avant, pour que le relais soit invisible.
        if let startedAt = store.tripStartedAt,
           Date.now.timeIntervalSince(startedAt) > Self.activityMaxDuration {
            await Self.endAllActivities()
            store.tripStartedAt = nil
        }

        // `staleDate` fait griser le contenu tout seul quand la mesure a passé
        // le seuil de péremption : la Live Activity ne peut pas mentir, même si
        // on n'arrive plus du tout à la mettre à jour.
        let staleDate = state.date.addingTimeInterval(
            Double(snapshot.settings.staleMinutes) * 60
        )
        let content = ActivityContent(state: state, staleDate: staleDate)

        if await Self.updateExistingActivities(with: content) { return }

        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        Self.requestActivity(with: content)
        store.tripStartedAt = .now
    }

    // MARK: - Accès à ActivityKit
    //
    // `Activity` n'est pas `Sendable` : le garder dans une propriété isolée
    // main-actor interdirait de le mettre à jour. On le récupère donc à la
    // volée depuis `Activity.activities`, ce qui est de toute façon plus juste
    // — une Live Activity survit à un relancement de l'app en tâche de fond,
    // pas une référence en mémoire.

    private nonisolated static func updateExistingActivities(
        with content: ActivityContent<GlucoActivityAttributes.ContentState>
    ) async -> Bool {
        var found = false
        for activity in Activity<GlucoActivityAttributes>.activities {
            await activity.update(content)
            found = true
        }
        return found
    }

    private nonisolated static func requestActivity(
        with content: ActivityContent<GlucoActivityAttributes.ContentState>
    ) {
        _ = try? Activity.request(
            attributes: GlucoActivityAttributes(),
            content: content,
            pushType: nil
        )
    }

    private nonisolated static func endAllActivities() async {
        for activity in Activity<GlucoActivityAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }
}

extension TripController: CLLocationManagerDelegate {
    /// Réveil par déplacement significatif : c'est le signal « il roule ».
    nonisolated func locationManager(
        _ manager: CLLocationManager,
        didUpdateLocations locations: [CLLocation]
    ) {
        Task { @MainActor in self.evaluateCarPlay() }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in self.startIfConfigured() }
    }

    nonisolated func locationManager(
        _ manager: CLLocationManager,
        didFailWithError error: any Error
    ) {
        // Une erreur de localisation ne doit jamais interrompre le trajet : la
        // glycémie continue d'être interrogée tant que l'app est vivante.
    }
}
