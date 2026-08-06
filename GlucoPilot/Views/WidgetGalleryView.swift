#if DEBUG
import GlucoKit
import SwiftUI

/// Galerie de contrôle, en Debug uniquement.
///
/// Elle montre le widget dans tous ses états, à la taille réelle de
/// `systemSmall`. C'est le seul moyen de juger ce qui s'affichera sur l'écran
/// de la voiture pendant une hypo sans attendre d'en faire une.
struct WidgetGalleryView: View {
    private static let side: CGFloat = 158

    private let states: [GlucoseState] = [
        .ok, .hyper, .hyperSevere, .hypo, .imminentHypo, .stale,
    ]

    var body: some View {
        ScrollView {
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: Self.side), spacing: 20)],
                spacing: 20
            ) {
                ForEach(states, id: \.self) { state in
                    VStack(spacing: 8) {
                        GlucoseSmallView(snapshot: .demo(state: state))
                            .padding(14)
                            .frame(width: Self.side, height: Self.side)
                            .background(.fill.tertiary, in: .rect(cornerRadius: 24))
                        Text(state.label)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(20)
        }
        .navigationTitle("Aperçu du widget")
        .navigationBarTitleDisplayMode(.inline)
    }
}
#endif
