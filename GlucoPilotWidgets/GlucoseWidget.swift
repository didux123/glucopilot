import GlucoKit
import SwiftUI
import WidgetKit

/// Le widget qui s'affiche sur la page de widgets de CarPlay — à gauche du
/// Dashboard — et, sans changement, sur l'écran d'accueil et l'écran
/// verrouillé de l'iPhone.
///
/// La famille `systemSmall` est la seule condition pour apparaître dans
/// CarPlay : aucun entitlement, aucune app CarPlay. On ne met donc surtout pas
/// `disfavoredLocations([.carPlay])` ici — c'est exactement là qu'on le veut.
struct GlucoseWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: "GlucoseWidget",
            intent: GlucoseWidgetIntent.self,
            provider: GlucoseProvider()
        ) { entry in
            GlucoseWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Glycémie")
        .description("Votre glycémie, sa tendance et l'âge de la mesure.")
        .supportedFamilies([.systemSmall, .accessoryRectangular, .accessoryCircular])
    }
}

struct GlucoseWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: GlucoseEntry

    var body: some View {
        switch family {
        case .accessoryCircular:
            GlucoseCircularView(snapshot: entry.snapshot)
        case .accessoryRectangular:
            GlucoseRectangularView(snapshot: entry.snapshot, now: entry.date)
        default:
            GlucoseSmallView(snapshot: entry.snapshot, now: entry.date)
        }
    }
}

#if DEBUG
#Preview("Dans la plage", as: .systemSmall) {
    GlucoseWidget()
} timeline: {
    GlucoseEntry(date: .now, snapshot: .demo(state: .ok))
}

#Preview("Hypo", as: .systemSmall) {
    GlucoseWidget()
} timeline: {
    GlucoseEntry(date: .now, snapshot: .demo(state: .hypo))
}
#endif
