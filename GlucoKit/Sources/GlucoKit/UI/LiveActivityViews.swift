#if os(iOS)
import SwiftUI

/// Vue `small` — celle qu'affiche le Dashboard CarPlay.
///
/// Très peu de place, et un lecteur qui conduit : une seule information domine,
/// le chiffre. Le reste doit pouvoir être ignoré sans rien perdre d'essentiel.
public struct LiveActivitySmallView: View {
    let state: GlucoActivityAttributes.ContentState
    let now: Date

    public init(state: GlucoActivityAttributes.ContentState, now: Date = .now) {
        self.state = state
        self.now = now
    }

    public var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: -2) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(state.mgdl)")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)
                    Text(state.trend.arrow)
                        .font(.system(size: 22, weight: .semibold, design: .rounded))
                }
                .foregroundStyle(
                    state.state.isAlerting ? AnyShapeStyle(state.state.tint)
                                           : AnyShapeStyle(.primary)
                )

                Text(detail(state, at: now))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            Spacer(minLength: 0)
            if let symbol = state.state.symbolName {
                Image(systemName: symbol)
                    .font(.title3)
                    .foregroundStyle(state.state.tint)
            }
        }
        .padding(.horizontal, 4)
    }
}

/// Vue `medium` — écran verrouillé de l'iPhone, où la place ne manque pas.
public struct LiveActivityMediumView: View {
    let state: GlucoActivityAttributes.ContentState
    let now: Date

    public init(state: GlucoActivityAttributes.ContentState, now: Date = .now) {
        self.state = state
        self.now = now
    }

    public var body: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Glycémie")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("\(state.mgdl)")
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .monospacedDigit()
                    Text(state.trend.arrow)
                        .font(.system(size: 26, weight: .semibold, design: .rounded))
                }
                .foregroundStyle(
                    state.state.isAlerting ? AnyShapeStyle(state.state.tint)
                                           : AnyShapeStyle(.primary)
                )
                Text(detail(state, at: now)).font(.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            VStack(spacing: 6) {
                if let symbol = state.state.symbolName {
                    Image(systemName: symbol).font(.title).foregroundStyle(state.state.tint)
                }
                Text(state.state.label)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(state.state.tint)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.vertical, 4)
    }
}

/// Delta et âge : ce sont eux qui disent si le chiffre est encore vrai.
private func detail(_ state: GlucoActivityAttributes.ContentState, at now: Date) -> String {
    [state.formattedDelta, state.formattedAge(at: now)]
        .compactMap { $0 }
        .joined(separator: " · ")
}
#endif
