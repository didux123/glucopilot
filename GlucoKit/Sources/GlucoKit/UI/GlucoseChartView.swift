import Charts
import SwiftUI

/// Courbe des 3 dernières heures, avec les seuils en repères.
///
/// C'est cette vue qui part aussi dans le widget : on y lit la direction d'un
/// coup d'œil, ce qu'un simple chiffre ne dit pas.
public struct GlucoseChartView: View {
    let readings: [GlucoseReading]
    let settings: GlucoSettings
    let showsAxes: Bool

    public init(readings: [GlucoseReading], settings: GlucoSettings, showsAxes: Bool = true) {
        self.readings = readings
        self.settings = settings
        self.showsAxes = showsAxes
    }

    private var yDomain: ClosedRange<Int> {
        let values = readings.map(\.mgdl)
        let low = min(settings.hypo - 20, values.min() ?? 60)
        let high = max(settings.hyper + 40, values.max() ?? 200)
        return max(0, low - 10)...(high + 10)
    }

    private var xDomain: ClosedRange<Date> {
        let last = readings.map(\.date).max() ?? .now
        let start = readings.map(\.date).min() ?? last.addingTimeInterval(-3 * 3600)
        // Un peu d'air à droite : sans ça le dernier repère horaire touche le
        // bord et se fait tronquer en « 1… ».
        let end = last.addingTimeInterval(600)
        // Toujours au moins une heure d'amplitude, sinon deux points collés
        // donnent une courbe illisible.
        return min(start, end.addingTimeInterval(-3600))...end
    }

    public var body: some View {
        Chart {
            RuleMark(y: .value("Seuil hyper", settings.hyper))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                .foregroundStyle(GlucoseState.hyper.tint.opacity(0.5))

            RuleMark(y: .value("Seuil hypo", settings.hypo))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                .foregroundStyle(GlucoseState.hypo.tint.opacity(0.5))

            ForEach(readings) { reading in
                LineMark(
                    x: .value("Heure", reading.date),
                    y: .value("mg/dL", reading.mgdl)
                )
                .interpolationMethod(.monotone)
                .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
                .foregroundStyle(.primary)
            }

            if let latest = readings.max(by: { $0.date < $1.date }) {
                PointMark(
                    x: .value("Heure", latest.date),
                    y: .value("mg/dL", latest.mgdl)
                )
                .symbolSize(80)
                .foregroundStyle(
                    GlucoseState.evaluate(latest, settings: settings).tint
                )
            }
        }
        .chartYScale(domain: yDomain)
        .chartXScale(domain: xDomain)
        .chartYAxis {
            AxisMarks(values: [settings.hypo, settings.hyper]) {
                AxisValueLabel()
            }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .hour)) {
                AxisGridLine()
                AxisValueLabel(format: .dateTime.hour().minute())
            }
        }
        // Dans le widget, la courbe se lit sans repères : la place manque, et
        // les chiffres seraient illisibles au volant.
        .chartYAxis(showsAxes ? .automatic : .hidden)
        .chartXAxis(showsAxes ? .automatic : .hidden)
    }
}
