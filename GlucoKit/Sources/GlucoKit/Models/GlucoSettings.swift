import Foundation

/// Réglages de l'utilisateur. Les valeurs par défaut sont celles validées en
/// production sur la veilleuse Dexcom (main.cpp:251-253).
public struct GlucoSettings: Sendable, Codable, Equatable {
    /// Sous ce seuil : hypo. Défaut 70 mg/dL.
    public var hypo: Int
    /// Au-dessus : hyper. Défaut 180 mg/dL.
    public var hyper: Int
    /// Au-dessus : hyper sévère. Défaut 300 mg/dL.
    public var hyperSevere: Int
    /// Au-delà de cet âge, la mesure est considérée périmée. Défaut 15 min.
    public var staleMinutes: Int
    /// Signaler une hypo qui arrive, avant que le seuil ne soit franchi.
    public var imminentHypoEnabled: Bool
    /// Seuil de l'hypo imminente, combiné à une flèche descendante. Défaut 110.
    public var imminentHypoThreshold: Int
    /// Région du compte Dexcom. La veilleuse tourne en `outsideUS`.
    public var region: ShareRegion

    public static let `default` = GlucoSettings(
        hypo: 70,
        hyper: 180,
        hyperSevere: 300,
        staleMinutes: 15,
        imminentHypoEnabled: true,
        imminentHypoThreshold: 110,
        region: .outsideUS
    )

    public init(
        hypo: Int = 70,
        hyper: Int = 180,
        hyperSevere: Int = 300,
        staleMinutes: Int = 15,
        imminentHypoEnabled: Bool = true,
        imminentHypoThreshold: Int = 110,
        region: ShareRegion = .outsideUS
    ) {
        self.hypo = hypo
        self.hyper = hyper
        self.hyperSevere = hyperSevere
        self.staleMinutes = staleMinutes
        self.imminentHypoEnabled = imminentHypoEnabled
        self.imminentHypoThreshold = imminentHypoThreshold
        self.region = region
    }

    /// Ramène des seuils incohérents aux valeurs par défaut, comme le fait le
    /// firmware au chargement de sa config (main.cpp:274).
    public var sanitized: GlucoSettings {
        var copy = self
        if !(hypo < hyper && hyper < hyperSevere) {
            copy.hypo = 70
            copy.hyper = 180
            copy.hyperSevere = 300
        }
        copy.staleMinutes = max(5, min(60, staleMinutes))
        copy.imminentHypoThreshold = max(copy.hypo, min(copy.hyper, imminentHypoThreshold))
        return copy
    }
}
