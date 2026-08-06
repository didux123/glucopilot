import Foundation
import Testing
@testable import GlucoKit

/// Bornes exactes de la machine à états, reprises du firmware (main.cpp:598).
/// Un décalage d'une unité ici, c'est une hypo qui s'affiche en vert.
@Suite("Machine à états")
struct GlucoseStateTests {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)
    private let settings = GlucoSettings.default

    private func state(_ mgdl: Int, _ trend: Trend = .flat, ageMinutes: Double = 2) -> GlucoseState {
        let reading = GlucoseReading(
            mgdl: mgdl, trend: trend, date: now.addingTimeInterval(-ageMinutes * 60)
        )
        return GlucoseState.evaluate(reading, settings: settings, at: now)
    }

    @Test("Borne hypo : strictement en dessous de 70")
    func hypoBoundary() {
        #expect(state(69) == .hypo)
        #expect(state(70) != .hypo)
    }

    @Test("Borne hyper : strictement au-dessus de 180")
    func hyperBoundary() {
        #expect(state(180) == .ok)
        #expect(state(181) == .hyper)
    }

    @Test("Borne hyper sévère : strictement au-dessus de 300")
    func hyperSevereBoundary() {
        #expect(state(300) == .hyper)
        #expect(state(301) == .hyperSevere)
    }

    @Test("Dans la plage")
    func inRange() {
        #expect(state(70) == .ok)
        #expect(state(120) == .ok)
        #expect(state(180) == .ok)
    }

    @Test("Le périmé prime sur tout le reste")
    func staleWins() {
        // Une valeur parfaite mais vieille de 16 min ne doit jamais s'afficher
        // en vert : c'est le pire des mensonges au volant.
        #expect(state(120, ageMinutes: 16) == .stale)
        #expect(state(45, ageMinutes: 16) == .stale)
        #expect(state(400, ageMinutes: 16) == .stale)
        // Pile sur la borne, la mesure reste valable.
        #expect(state(120, ageMinutes: 15) == .ok)
    }

    @Test("Hypo imminente : valeur basse ET descente franche")
    func imminentHypo() {
        #expect(state(100, .singleDown) == .imminentHypo)
        #expect(state(100, .doubleDown) == .imminentHypo)
        // Basse mais stable : pas d'alerte.
        #expect(state(100, .flat) == .ok)
        // Descente douce : pas d'alerte non plus.
        #expect(state(100, .fortyFiveDown) == .ok)
        // Au-dessus du seuil d'imminence, même en chute.
        #expect(state(150, .doubleDown) == .ok)
    }

    @Test("L'hypo avérée prime sur l'hypo imminente")
    func realHypoWinsOverImminent() {
        #expect(state(60, .doubleDown) == .hypo)
    }

    @Test("L'hypo imminente peut être désactivée")
    func imminentHypoDisabled() {
        var settings = GlucoSettings.default
        settings.imminentHypoEnabled = false
        let reading = GlucoseReading(
            mgdl: 100, trend: .doubleDown, date: now.addingTimeInterval(-120)
        )
        #expect(GlucoseState.evaluate(reading, settings: settings, at: now) == .ok)
    }

    @Test("Les états qui doivent alerter le conducteur")
    func alerting() {
        #expect(GlucoseState.hypo.isAlerting)
        #expect(GlucoseState.imminentHypo.isAlerting)
        #expect(GlucoseState.hyperSevere.isAlerting)
        #expect(!GlucoseState.ok.isAlerting)
        #expect(!GlucoseState.hyper.isAlerting)
        #expect(!GlucoseState.stale.isAlerting)
    }

    @Test("Des seuils incohérents retombent sur les valeurs de la veilleuse")
    func sanitizesInconsistentThresholds() {
        let broken = GlucoSettings(hypo: 200, hyper: 100, hyperSevere: 50).sanitized
        #expect(broken.hypo == 70)
        #expect(broken.hyper == 180)
        #expect(broken.hyperSevere == 300)
    }
}

@Suite("Photo de l'état")
struct GlucoSnapshotTests {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func snapshot(_ values: [Int]) -> GlucoSnapshot {
        let readings = values.enumerated().map { index, mgdl in
            GlucoseReading(
                mgdl: mgdl, trend: .flat, date: now.addingTimeInterval(-Double(index) * 300)
            )
        }
        return GlucoSnapshot(readings: readings, fetchedAt: now)
    }

    @Test("Le delta se calcule sur les deux mesures les plus récentes")
    func delta() {
        #expect(snapshot([142, 137, 130]).delta == 5)
        #expect(snapshot([130, 142]).delta == -12)
        #expect(snapshot([142]).delta == nil)
        #expect(snapshot([]).delta == nil)
    }

    @Test("Le delta affiché porte son signe")
    func formattedDelta() {
        #expect(snapshot([142, 137]).formattedDelta == "+5")
        #expect(snapshot([130, 142]).formattedDelta == "-12")
        #expect(snapshot([142, 142]).formattedDelta == "0")
    }

    @Test("L'âge est écrit différemment à l'écran et pour Siri")
    func ageFormatting() {
        let reading = GlucoseReading(mgdl: 142, trend: .flat, date: now.addingTimeInterval(-180))
        #expect(reading.formattedAge(at: now) == "il y a 3 min")
        #expect(reading.spokenAge(at: now) == "il y a 3 minutes")

        let fresh = GlucoseReading(mgdl: 142, trend: .flat, date: now.addingTimeInterval(-20))
        #expect(fresh.formattedAge(at: now) == "à l'instant")

        let oneMinute = GlucoseReading(mgdl: 142, trend: .flat, date: now.addingTimeInterval(-60))
        #expect(oneMinute.spokenAge(at: now) == "il y a 1 minute")

        let old = GlucoseReading(mgdl: 142, trend: .flat, date: now.addingTimeInterval(-3900))
        #expect(old.formattedAge(at: now) == "il y a 1 h 05")
    }

    @Test("La phrase de Siri se lit correctement")
    func spokenSummary() {
        var snap = snapshot([142])
        #expect(snap.spokenSummary(at: now) == "142, stable, à l'instant")

        // Un échec doit être annoncé, jamais masqué par une vieille valeur.
        snap.failure = .credentialsRejected
        #expect(snap.spokenSummary(at: now) == "Identifiants Dexcom refusés")

        let empty = GlucoSnapshot(fetchedAt: now)
        #expect(empty.spokenSummary(at: now) == "Aucune mesure disponible")
    }

    @Test("La photo survit à un aller-retour JSON")
    func codableRoundTrip() throws {
        let original = snapshot([142, 137])
        let data = try JSONEncoder().encode(original)
        #expect(try JSONDecoder().decode(GlucoSnapshot.self, from: data) == original)
    }
}
