import Foundation

/// Pourquoi la dernière tentative de récupération a échoué.
public enum SnapshotFailure: String, Sendable, Codable, Equatable {
    /// Identifiants absents ou refusés par Dexcom. Arrêt total jusqu'à
    /// correction manuelle : c'est la règle anti-verrouillage du compte.
    case credentialsRejected
    /// Pas de réseau, ou Dexcom injoignable. Réessayable.
    case unreachable
    /// Aucun identifiant enregistré : l'app n'a jamais été configurée.
    case notConfigured

    public var label: String {
        switch self {
        case .credentialsRejected: "Identifiants Dexcom refusés"
        case .unreachable: "Dexcom injoignable"
        case .notConfigured: "Compte Dexcom à configurer"
        }
    }
}

/// Tout ce qu'il faut pour afficher l'app, le widget ou la Live Activity.
/// C'est l'unité d'échange entre l'app et son extension, via l'App Group.
public struct GlucoSnapshot: Sendable, Codable, Equatable {
    /// Mesures des 3 dernières heures, **la plus récente en premier** — c'est
    /// l'ordre que renvoie `ReadPublisherLatestGlucoseValues`.
    public var readings: [GlucoseReading]
    public var settings: GlucoSettings
    /// Quand cette photo a été prise (à distinguer de l'âge de la mesure).
    public var fetchedAt: Date
    /// Échec de la dernière tentative, le cas échéant. Les mesures précédentes
    /// sont conservées pour pouvoir les afficher grisées avec leur âge.
    public var failure: SnapshotFailure?

    public init(
        readings: [GlucoseReading] = [],
        settings: GlucoSettings = .default,
        fetchedAt: Date = .now,
        failure: SnapshotFailure? = nil
    ) {
        self.readings = readings
        self.settings = settings
        self.fetchedAt = fetchedAt
        self.failure = failure
    }

    public var latest: GlucoseReading? { readings.first }

    public var delta: Int? { readings.delta }

    public var formattedDelta: String? { readings.formattedDelta }

    /// État courant, ou `nil` s'il n'y a aucune mesure à qualifier.
    public func state(at now: Date = .now) -> GlucoseState? {
        latest.map { GlucoseState.evaluate($0, settings: settings, at: now) }
    }

    /// Phrase parlée par Siri : « 142, stable, il y a 3 minutes ».
    public func spokenSummary(at now: Date = .now) -> String {
        if let failure { return failure.label }
        guard let latest else { return "Aucune mesure disponible" }
        return "\(latest.mgdl), \(latest.trend.spokenLabel), \(latest.spokenAge(at: now))"
    }
}
