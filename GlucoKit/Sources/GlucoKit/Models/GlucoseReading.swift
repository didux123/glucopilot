import Foundation

/// Une mesure de glycémie, en mg/dL.
public struct GlucoseReading: Sendable, Codable, Equatable, Identifiable {
    /// Valeur en mg/dL.
    public let mgdl: Int
    /// Tendance associée.
    public let trend: Trend
    /// Horodatage Dexcom de la mesure (champ `WT`, en UTC).
    public let date: Date

    public var id: Date { date }

    public init(mgdl: Int, trend: Trend, date: Date) {
        self.mgdl = mgdl
        self.trend = trend
        self.date = date
    }

    /// Âge de la mesure. Une mesure Dexcom arrive toutes les 5 min ; au-delà du
    /// seuil `stale` des réglages, la valeur ne doit plus être affichée comme
    /// courante.
    public func age(at now: Date = .now) -> TimeInterval {
        now.timeIntervalSince(date)
    }

    /// Âge en clair, à l'écran : « à l'instant », « il y a 3 min »,
    /// « il y a 1 h 05 ».
    public func formattedAge(at now: Date = .now) -> String {
        let minutes = ageInMinutes(at: now)
        guard minutes >= 1 else { return "à l'instant" }
        guard minutes >= 60 else { return "il y a \(minutes) min" }
        return "il y a \(minutes / 60) h \(String(format: "%02d", minutes % 60))"
    }

    /// Même chose, mais écrit en toutes lettres pour Siri — « min » se
    /// prononce mal.
    public func spokenAge(at now: Date = .now) -> String {
        let minutes = ageInMinutes(at: now)
        guard minutes >= 1 else { return "à l'instant" }
        guard minutes >= 60 else {
            return "il y a \(minutes) minute\(minutes > 1 ? "s" : "")"
        }
        let hours = minutes / 60
        return "il y a \(hours) heure\(hours > 1 ? "s" : "")"
    }

    private func ageInMinutes(at now: Date) -> Int {
        max(0, Int(age(at: now).rounded()) / 60)
    }
}

extension Array where Element == GlucoseReading {
    /// Écart avec la mesure précédente, en mg/dL. `nil` s'il n'y a qu'une mesure.
    ///
    /// Le tableau est supposé trié du plus récent au plus ancien, comme le
    /// renvoie `ReadPublisherLatestGlucoseValues`.
    public var delta: Int? {
        guard count >= 2 else { return nil }
        return self[0].mgdl - self[1].mgdl
    }

    /// Delta mis en forme avec son signe : `+5`, `-12`, `0`.
    public var formattedDelta: String? {
        delta.map { $0 > 0 ? "+\($0)" : "\($0)" }
    }
}
