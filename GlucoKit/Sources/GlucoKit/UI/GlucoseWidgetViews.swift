import SwiftUI

/// Les vues du widget vivent ici, et pas dans l'extension, pour deux raisons :
/// l'app peut les afficher telles quelles dans sa galerie de contrôle (en
/// Debug), et la Live Activity réutilise les mêmes briques. Ce qui est montré
/// au volant est ainsi vérifiable ailleurs qu'au volant.

/// Format `systemSmall` — celui de la page de widgets CarPlay.
public struct GlucoseSmallView: View {
    let snapshot: GlucoSnapshot
    let now: Date

    public init(snapshot: GlucoSnapshot, now: Date = .now) {
        self.snapshot = snapshot
        self.now = now
    }

    public var body: some View {
        if let latest = snapshot.latest, let state = snapshot.state(at: now) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 5) {
                    Circle()
                        .fill(state.tint)
                        .frame(width: 8, height: 8)
                    Text(latest.formattedAge(at: now))
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }

                Spacer(minLength: 2)

                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text("\(latest.mgdl)")
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                    Text(latest.trend.arrow)
                        .font(.system(size: 26, weight: .semibold, design: .rounded))
                    Spacer(minLength: 0)
                    if let delta = snapshot.formattedDelta {
                        Text(delta)
                            .font(.caption.weight(.semibold))
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                }
                .foregroundStyle(
                    state.isAlerting || state == .stale ? AnyShapeStyle(state.tint)
                                                        : AnyShapeStyle(.primary)
                )

                Spacer(minLength: 4)

                // Sans repères : à cette taille, et au volant, les chiffres
                // d'axe seraient du bruit. Seule la direction compte.
                GlucoseChartView(
                    readings: snapshot.readings,
                    settings: snapshot.settings,
                    showsAxes: false
                )
                .frame(height: 38)
            }
        } else {
            GlucoseUnavailableView(snapshot: snapshot)
        }
    }
}

/// Format `accessoryRectangular` — écran verrouillé de l'iPhone.
public struct GlucoseRectangularView: View {
    let snapshot: GlucoSnapshot
    let now: Date

    public init(snapshot: GlucoSnapshot, now: Date = .now) {
        self.snapshot = snapshot
        self.now = now
    }

    public var body: some View {
        if let latest = snapshot.latest {
            VStack(alignment: .leading, spacing: 1) {
                Text("Glycémie").font(.caption2).foregroundStyle(.secondary)
                HStack(spacing: 4) {
                    Text("\(latest.mgdl)").font(.title3.bold()).monospacedDigit()
                    Text(latest.trend.arrow).font(.body.weight(.semibold))
                    if let delta = snapshot.formattedDelta {
                        Text(delta).font(.caption).monospacedDigit()
                    }
                }
                Text(latest.formattedAge(at: now))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        } else {
            GlucoseUnavailableView(snapshot: snapshot)
        }
    }
}

/// Format `accessoryCircular`.
public struct GlucoseCircularView: View {
    let snapshot: GlucoSnapshot

    public init(snapshot: GlucoSnapshot) {
        self.snapshot = snapshot
    }

    public var body: some View {
        if let latest = snapshot.latest {
            VStack(spacing: -2) {
                Text("\(latest.mgdl)")
                    .font(.headline)
                    .monospacedDigit()
                    .minimumScaleFactor(0.7)
                Text(latest.trend.arrow).font(.caption2)
            }
        } else {
            Image(systemName: "drop.halffull")
        }
    }
}

/// Ni mesure ni raison de l'être : on dit laquelle des deux.
public struct GlucoseUnavailableView: View {
    let snapshot: GlucoSnapshot

    public init(snapshot: GlucoSnapshot) {
        self.snapshot = snapshot
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Image(systemName: "drop.halffull").foregroundStyle(.secondary)
            Text(snapshot.failure?.label ?? "Aucune mesure")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(3)
        }
    }
}
