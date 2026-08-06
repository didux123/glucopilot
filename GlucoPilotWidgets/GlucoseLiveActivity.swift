import ActivityKit
import GlucoKit
import SwiftUI
import WidgetKit

/// La Live Activity du trajet.
///
/// `supplementalActivityFamilies([.small])` est la clé : CarPlay affiche la
/// Live Activity dans cette taille (la même que le Smart Stack watchOS). Sans
/// elle, CarPlay retomberait sur les vues compactes de la Dynamic Island, bien
/// plus pauvres.
///
/// Non interactive dans la voiture — c'est voulu par iOS, et c'est très bien
/// ainsi quand on conduit.
struct GlucoseLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: GlucoActivityAttributes.self) { context in
            LiveActivityView(state: context.state)
                .activityBackgroundTint(nil)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Text("\(context.state.mgdl)")
                        .font(.title.bold())
                        .monospacedDigit()
                        .foregroundStyle(context.state.state.tint)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.state.trend.arrow).font(.title2)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text(context.state.formattedAge())
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } compactLeading: {
                Text("\(context.state.mgdl)")
                    .monospacedDigit()
                    .foregroundStyle(context.state.state.tint)
            } compactTrailing: {
                Text(context.state.trend.arrow)
            } minimal: {
                Text("\(context.state.mgdl)")
                    .monospacedDigit()
                    .foregroundStyle(context.state.state.tint)
            }
        }
        .supplementalActivityFamilies([.small])
    }
}

/// Deux tailles à servir : `small` sur le Dashboard CarPlay, `medium` sur
/// l'écran verrouillé de l'iPhone. Les vues elles-mêmes vivent dans GlucoKit,
/// pour que la galerie de contrôle de l'app puisse les afficher à l'identique.
struct LiveActivityView: View {
    @Environment(\.activityFamily) private var family
    let state: GlucoActivityAttributes.ContentState

    var body: some View {
        switch family {
        case .small: LiveActivitySmallView(state: state)
        default: LiveActivityMediumView(state: state)
        }
    }
}
