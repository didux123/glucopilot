#if DEBUG
import GlucoKit
import SwiftUI

/// Galerie de contrôle, en Debug uniquement.
///
/// Elle montre les deux surfaces CarPlay dans tous leurs états, aux tailles
/// réelles. C'est le seul moyen de juger ce qui s'affichera sur l'écran de la
/// voiture pendant une hypo sans attendre d'en faire une.
struct WidgetGalleryView: View {
    private static let widgetSide: CGFloat = 158
    private static let activitySize = CGSize(width: 172, height: 64)

    private let states: [GlucoseState] = [
        .ok, .hyper, .hyperSevere, .hypo, .imminentHypo, .stale,
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                section("Live Activity — Dashboard CarPlay") { state in
                    Group {
                        if let content = GlucoSnapshot.demo(state: state).activityState() {
                            LiveActivitySmallView(state: content)
                        }
                    }
                    .padding(.horizontal, 12)
                    .frame(width: Self.activitySize.width, height: Self.activitySize.height)
                    .background(.fill.tertiary, in: .rect(cornerRadius: 18))
                }

                section("Widget — page de widgets CarPlay") { state in
                    GlucoseSmallView(snapshot: .demo(state: state))
                        .padding(14)
                        .frame(width: Self.widgetSide, height: Self.widgetSide)
                        .background(.fill.tertiary, in: .rect(cornerRadius: 24))
                }
            }
            .padding(20)
        }
        .navigationTitle("Aperçu CarPlay")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func section(
        _ title: String,
        @ViewBuilder content: @escaping (GlucoseState) -> some View
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 158), spacing: 18)],
                spacing: 18
            ) {
                ForEach(states, id: \.self) { state in
                    VStack(spacing: 8) {
                        content(state)
                        Text(state.label)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        }
    }
}
#endif
