import Foundation
import Testing
@testable import GlucoKit

/// Dexcom renvoie la tendance sous trois formes selon les endpoints et les
/// versions. Le firmware en gérait deux ; ce décodage doit couvrir les trois.
@Suite("Décodage des tendances")
struct TrendTests {
    private func decode(_ json: String) throws -> Trend {
        try JSONDecoder().decode(Trend.self, from: Data(json.utf8))
    }

    @Test("Le nom textuel est reconnu")
    func decodesName() throws {
        #expect(try decode("\"Flat\"") == .flat)
        #expect(try decode("\"DoubleDown\"") == .doubleDown)
        #expect(try decode("\"FortyFiveUp\"") == .fortyFiveUp)
    }

    @Test("L'index numérique est reconnu")
    func decodesIndex() throws {
        #expect(try decode("4") == .flat)
        #expect(try decode("7") == .doubleDown)
        #expect(try decode("0") == .none)
    }

    @Test("Un index encodé en chaîne reste un index")
    func decodesStringifiedIndex() throws {
        #expect(try decode("\"4\"") == .flat)
        #expect(try decode("\"6\"") == .singleDown)
    }

    @Test("Une valeur inconnue retombe sur .none plutôt que d'échouer")
    func decodesUnknownAsNone() throws {
        #expect(try decode("\"Wat\"") == .none)
        #expect(try decode("42") == .none)
        #expect(try decode("null") == .none)
    }

    @Test("Les flèches correspondent à celles de la veilleuse")
    func arrows() {
        #expect(Trend.doubleUp.arrow == "↑↑")
        #expect(Trend.fortyFiveUp.arrow == "↗")
        #expect(Trend.flat.arrow == "→")
        #expect(Trend.doubleDown.arrow == "↓↓")
        // Les états non exploitables n'affichent rien, surtout pas une flèche
        // trompeuse.
        #expect(Trend.notComputable.arrow.isEmpty)
        #expect(Trend.rateOutOfRange.arrow.isEmpty)
        #expect(Trend.none.arrow.isEmpty)
    }

    @Test("Seules les vraies descentes déclenchent l'hypo imminente")
    func fallingFast() {
        #expect(Trend.singleDown.isFallingFast)
        #expect(Trend.doubleDown.isFallingFast)
        #expect(!Trend.fortyFiveDown.isFallingFast)
        #expect(!Trend.flat.isFallingFast)
    }

    @Test("L'encodage puis le décodage conservent la valeur")
    func roundTrip() throws {
        for trend in Trend.allCases {
            let data = try JSONEncoder().encode(trend)
            #expect(try JSONDecoder().decode(Trend.self, from: data) == trend)
        }
    }
}
