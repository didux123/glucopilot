import GlucoKit
import SwiftUI

struct DashboardView: View {
    @Environment(AppModel.self) private var model
    @State private var showsSettings = false

    /// Rafraîchi chaque seconde pour que l'âge de la mesure vieillisse à
    /// l'écran au lieu de rester figé sur la valeur d'il y a dix minutes.
    @State private var now = Date.now
    private let clock = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var snapshot: GlucoSnapshot { model.snapshot }
    private var state: GlucoseState? { snapshot.state(at: now) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    reading
                    chart
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .background(background)
            .refreshable { await model.refresh(force: true) }
            .navigationTitle("GlucoPilot")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Réglages", systemImage: "gearshape") { showsSettings = true }
                }
            }
            .sheet(isPresented: $showsSettings) { SettingsView() }
            .safeAreaInset(edge: .bottom) { statusBar }
        }
        .onReceive(clock) { now = $0 }
    }

    // MARK: - Mesure

    @ViewBuilder
    private var reading: some View {
        if let latest = snapshot.latest, let state {
            VStack(spacing: 12) {
                stateBadge(state)

                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text("\(latest.mgdl)")
                        .font(.system(size: 96, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                    Text(latest.trend.arrow)
                        .font(.system(size: 52, weight: .semibold, design: .rounded))
                }
                // Le chiffre reste neutre en temps normal — c'est la pastille
                // qui qualifie. Il ne prend la couleur que quand il y a
                // vraiment quelque chose à signaler.
                .foregroundStyle(
                    state.isAlerting || state == .stale ? AnyShapeStyle(state.tint)
                                                        : AnyShapeStyle(.primary)
                )
                .animation(.snappy, value: latest.mgdl)

                Text("mg/dL")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    if let delta = snapshot.formattedDelta {
                        Text(delta).monospacedDigit()
                        Text("·").foregroundStyle(.tertiary)
                    }
                    Text(latest.formattedAge(at: now))
                }
                .font(.callout.weight(.medium))
                .foregroundStyle(.secondary)
            }
            .padding(.top, 16)
        } else {
            ContentUnavailableView(
                "Aucune mesure",
                systemImage: "drop.halffull",
                description: Text(
                    snapshot.failure?.label ?? "En attente de la première mesure Dexcom."
                )
            )
            .padding(.top, 40)
        }
    }

    private func stateBadge(_ state: GlucoseState) -> some View {
        Label {
            Text(state.label)
        } icon: {
            if let symbol = state.symbolName { Image(systemName: symbol) }
        }
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(state.tint)
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .background(state.tint.opacity(0.15), in: .capsule)
    }

    // MARK: - Courbe

    @ViewBuilder
    private var chart: some View {
        if snapshot.readings.count >= 2 {
            VStack(alignment: .leading, spacing: 10) {
                Text("3 dernières heures")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                GlucoseChartView(readings: snapshot.readings, settings: snapshot.settings)
                    .frame(height: 190)
            }
            .padding(16)
            .background(.background.secondary, in: .rect(cornerRadius: 20))
        }
    }

    // MARK: - Habillage

    private var background: some View {
        LinearGradient(
            colors: [(state?.tint ?? .gray).opacity(0.16), .clear],
            startPoint: .top,
            endPoint: .center
        )
        .ignoresSafeArea()
    }

    @ViewBuilder
    private var statusBar: some View {
        if let failure = snapshot.failure {
            Label(failure.label, systemImage: "wifi.exclamationmark")
                .font(.footnote.weight(.medium))
                .foregroundStyle(failure == .credentialsRejected ? .red : .secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(.bar)
        }
    }
}
