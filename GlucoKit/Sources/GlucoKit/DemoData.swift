#if DEBUG
import Foundation

/// Données synthétiques, uniquement en Debug.
///
/// Même intention que le `DEMO_MODE` de la veilleuse : pouvoir regarder à quoi
/// ressemble une hypo à l'écran sans attendre d'en faire une. Indispensable
/// pour vérifier le widget et la Live Activity, dont on ne peut pas provoquer
/// les états à la demande.
extension GlucoSnapshot {
    public static func demo(
        state: GlucoseState = .ok,
        settings: GlucoSettings = .default,
        now: Date = .now
    ) -> GlucoSnapshot {
        let (target, trend): (Int, Trend) = switch state {
        case .ok: (128, .flat)
        case .hyper: (214, .fortyFiveUp)
        case .hyperSevere: (327, .singleUp)
        case .hypo: (58, .singleDown)
        case .imminentHypo: (96, .doubleDown)
        case .stale: (142, .flat)
        }

        // 36 mesures sur 3 h, une toutes les 5 min, qui convergent vers la
        // valeur visée avec une ondulation crédible.
        let readings = (0..<36).map { step -> GlucoseReading in
            let age = Double(step) * 300
            let drift = Double(step) * (state == .hypo || state == .imminentHypo ? 2.2 : -1.4)
            let wave = sin(Double(step) / 2.6) * 11
            let mgdl = max(40, min(400, Int((Double(target) + drift + wave).rounded())))
            return GlucoseReading(
                mgdl: step == 0 ? target : mgdl,
                trend: step == 0 ? trend : .flat,
                date: now.addingTimeInterval(-age - (state == .stale ? 22 * 60 : 0))
            )
        }

        return GlucoSnapshot(readings: readings, settings: settings, fetchedAt: now)
    }
}
#endif
