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

        // Pente impliquée par la flèche, en mg/dL par pas de 5 min. Sans elle,
        // l'ondulation dominerait et le delta afficherait « -3 » sous une
        // flèche montante — exactement le genre d'incohérence qui décrédibilise
        // un aperçu.
        let slope: Double = switch trend {
        case .doubleUp: 12
        case .singleUp: 8
        case .fortyFiveUp: 4
        case .fortyFiveDown: -4
        case .singleDown: -8
        case .doubleDown: -12
        default: 0
        }

        // 36 mesures sur 3 h, une toutes les 5 min. L'ondulation s'annule au
        // pas 0 pour que la valeur courante soit exactement celle visée.
        let readings = (0..<36).map { step -> GlucoseReading in
            let wave = (cos(Double(step) / 2.6) - 1) * 6
            let mgdl = Double(target) - slope * Double(step) + wave
            return GlucoseReading(
                mgdl: max(40, min(400, Int(mgdl.rounded()))),
                trend: step == 0 ? trend : .flat,
                date: now.addingTimeInterval(
                    -Double(step) * 300 - (state == .stale ? 22 * 60 : 0)
                )
            )
        }

        return GlucoSnapshot(readings: readings, settings: settings, fetchedAt: now)
    }
}
#endif
