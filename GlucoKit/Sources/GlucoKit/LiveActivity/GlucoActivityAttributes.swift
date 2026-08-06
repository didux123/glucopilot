// `os(iOS)` et pas `canImport(ActivityKit)` : le module existe bien sur
// macOS, mais le protocole y est explicitement indisponible — la
// compilation des tests, qui tournent sur la machine, échouerait.
#if os(iOS)
import ActivityKit
import Foundation

/// Contenu de la Live Activity affichée pendant le trajet.
///
/// C'est la surface centrale du projet : depuis iOS 26, une Live Activity
/// apparaît d'elle-même sur le Dashboard CarPlay, et en bandeau si le Dashboard
/// n'est pas visible — sans entitlement CarPlay, sans app CarPlay.
///
/// Le type est ici plutôt que dans l'extension parce que les deux côtés en ont
/// besoin : l'app la démarre et la met à jour, l'extension la dessine.
/// `Sendable` explicite : un type public d'un autre module ne l'obtient pas
/// automatiquement, et sans lui `Activity` cesse d'être `Sendable` — ce qui
/// interdit toute mise à jour depuis le contrôleur de trajet.
public struct GlucoActivityAttributes: ActivityAttributes, Sendable {
    public struct ContentState: Codable, Hashable, Sendable {
        public var mgdl: Int
        public var trend: Trend
        public var date: Date
        public var delta: Int?
        public var state: GlucoseState

        public init(mgdl: Int, trend: Trend, date: Date, delta: Int?, state: GlucoseState) {
            self.mgdl = mgdl
            self.trend = trend
            self.date = date
            self.delta = delta
            self.state = state
        }

        public var formattedDelta: String? {
            delta.map { $0 > 0 ? "+\($0)" : "\($0)" }
        }

        public func formattedAge(at now: Date = .now) -> String {
            GlucoseReading(mgdl: mgdl, trend: trend, date: date).formattedAge(at: now)
        }
    }

    public init() {}
}

extension GlucoSnapshot {
    /// Convertit la photo courante en contenu de Live Activity.
    /// `nil` quand il n'y a rien à montrer — mieux vaut pas de Live Activity
    /// qu'une Live Activity vide sur le tableau de bord.
    public func activityState(at now: Date = .now) -> GlucoActivityAttributes.ContentState? {
        guard let latest, let state = state(at: now) else { return nil }
        return GlucoActivityAttributes.ContentState(
            mgdl: latest.mgdl,
            trend: latest.trend,
            date: latest.date,
            delta: delta,
            state: state
        )
    }
}
#endif
