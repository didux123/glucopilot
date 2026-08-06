import AppIntents
import GlucoKit
import WidgetKit

struct GlucoseEntry: TimelineEntry {
    let date: Date
    let snapshot: GlucoSnapshot

    var state: GlucoseState? { snapshot.state(at: date) }
}

/// Le widget n'a rien à configurer, mais `AppIntentConfiguration` est la seule
/// voie entièrement `async` : `TimelineProvider` ne propose que des completion
/// handlers, incompatibles avec la concurrence stricte de Swift 6.
struct GlucoseWidgetIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Glycémie"
    static let description = IntentDescription("Votre glycémie et sa tendance.")
}

/// Le widget va chercher la glycémie lui-même : c'est ce qui le garde à jour
/// quand l'app n'a pas tourné depuis des heures.
///
/// WidgetKit accorde de l'ordre de 40 à 70 réveils par jour, soit une mesure
/// toutes les 20 à 30 min en pratique. D'où deux partis pris :
///
/// - l'âge de la mesure est **toujours** affiché, jamais masqué ;
/// - la frise contient plusieurs entrées espacées de 5 min, pour que cet âge
///   continue de vieillir à l'écran entre deux réveils au lieu de mentir.
struct GlucoseProvider: AppIntentTimelineProvider {
    /// Réveil demandé. WidgetKit fera ce qu'il peut avec son budget.
    private static let refreshInterval: TimeInterval = 10 * 60
    /// Amplitude de la frise : au-delà, l'âge affiché ne veut plus rien dire.
    private static let timelineSpan: TimeInterval = 30 * 60
    private static let entryStep: TimeInterval = 5 * 60

    func placeholder(in context: Context) -> GlucoseEntry {
        GlucoseEntry(date: .now, snapshot: GlucoSnapshot())
    }

    /// Aperçu dans la galerie de widgets : on ressert le cache, sans appel
    /// réseau — l'utilisateur fait défiler, il n'a pas encore ajouté le widget.
    func snapshot(for configuration: GlucoseWidgetIntent, in context: Context) async -> GlucoseEntry {
        GlucoseEntry(date: .now, snapshot: await GlucoseRefresher.shared.cachedSnapshot())
    }

    func timeline(
        for configuration: GlucoseWidgetIntent,
        in context: Context
    ) async -> Timeline<GlucoseEntry> {
        let snapshot = await GlucoseRefresher.shared.refresh()
        let now = Date.now

        let entries = stride(from: 0, through: Self.timelineSpan, by: Self.entryStep).map {
            GlucoseEntry(date: now.addingTimeInterval($0), snapshot: snapshot)
        }

        return Timeline(
            entries: entries,
            policy: .after(now.addingTimeInterval(Self.refreshInterval))
        )
    }
}
