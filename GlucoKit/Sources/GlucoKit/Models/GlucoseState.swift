import Foundation

/// État d'une mesure au regard des seuils. Porté de la machine à états du
/// firmware (main.cpp:598-601), avec l'ajout de l'hypo imminente.
public enum GlucoseState: String, Sendable, Codable, Equatable, CaseIterable {
    /// Dans la plage.
    case ok
    /// Au-dessus du seuil hyper.
    case hyper
    /// Au-dessus du seuil hyper sévère.
    case hyperSevere
    /// Sous le seuil hypo.
    case hypo
    /// Pas encore en hypo, mais la valeur est basse et descend franchement.
    case imminentHypo
    /// Mesure trop vieille pour être affichée comme courante.
    case stale

    /// Vrai pour les états qui doivent alerter le conducteur.
    public var isAlerting: Bool {
        self == .hypo || self == .imminentHypo || self == .hyperSevere
    }

    public var label: String {
        switch self {
        case .ok: "Dans la plage"
        case .hyper: "Au-dessus du seuil"
        case .hyperSevere: "Hyper sévère"
        case .hypo: "Hypo"
        case .imminentHypo: "Hypo imminente"
        case .stale: "Données périmées"
        }
    }

    /// Détermine l'état d'une mesure.
    ///
    /// L'ordre des tests reproduit exactement celui du firmware : le périmé
    /// prime sur tout — une vieille valeur dans la plage ne doit jamais
    /// s'afficher en vert.
    public static func evaluate(
        _ reading: GlucoseReading,
        settings: GlucoSettings,
        at now: Date = .now
    ) -> GlucoseState {
        if reading.age(at: now) > Double(settings.staleMinutes) * 60 { return .stale }
        if reading.mgdl < settings.hypo { return .hypo }
        if settings.imminentHypoEnabled,
           reading.mgdl < settings.imminentHypoThreshold,
           reading.trend.isFallingFast {
            return .imminentHypo
        }
        if reading.mgdl > settings.hyperSevere { return .hyperSevere }
        if reading.mgdl > settings.hyper { return .hyper }
        return .ok
    }
}
