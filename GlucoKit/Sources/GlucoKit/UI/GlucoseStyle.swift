import SwiftUI

/// Couleurs des états, partagées par l'app, le widget et la Live Activity.
///
/// Elles sont pensées pour un écran de voiture en plein soleil : franches,
/// contrastées, et distinguables entre elles même du coin de l'œil. La
/// progression suit celle de la veilleuse — vert, orange, rouge — pour que les
/// deux objets racontent la même chose.
extension GlucoseState {
    public var tint: Color {
        switch self {
        case .ok: Color(red: 0.18, green: 0.75, blue: 0.44)
        case .hyper: Color(red: 0.95, green: 0.64, blue: 0.24)
        case .hyperSevere: Color(red: 0.91, green: 0.38, blue: 0.16)
        case .hypo: Color(red: 0.90, green: 0.28, blue: 0.30)
        case .imminentHypo: Color(red: 0.95, green: 0.41, blue: 0.24)
        case .stale: Color(red: 0.54, green: 0.56, blue: 0.60)
        }
    }

    /// Symbole SF qui accompagne l'état. Muet pour l'état normal : au volant,
    /// une icône qui ne signale rien est du bruit.
    public var symbolName: String? {
        switch self {
        case .ok: nil
        case .hyper, .hyperSevere: "arrow.up.circle.fill"
        case .hypo, .imminentHypo: "exclamationmark.triangle.fill"
        case .stale: "clock.badge.questionmark"
        }
    }
}
