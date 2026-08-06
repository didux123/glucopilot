import Foundation

/// Tendance de la glycémie.
///
/// Dexcom Share renvoie ce champ tantôt sous forme de nom (`"Flat"`), tantôt
/// sous forme d'index (`4`), et parfois d'index encodé en chaîne (`"4"`).
/// Le firmware de la veilleuse gérait déjà les deux premières formes
/// (`trendArrow`, main.cpp:684) ; on couvre les trois ici.
public enum Trend: Int, Sendable, Codable, CaseIterable {
    case none = 0
    case doubleUp = 1
    case singleUp = 2
    case fortyFiveUp = 3
    case flat = 4
    case fortyFiveDown = 5
    case singleDown = 6
    case doubleDown = 7
    case notComputable = 8
    case rateOutOfRange = 9

    /// Nom tel que renvoyé par l'API Share.
    var apiName: String {
        switch self {
        case .none: "None"
        case .doubleUp: "DoubleUp"
        case .singleUp: "SingleUp"
        case .fortyFiveUp: "FortyFiveUp"
        case .flat: "Flat"
        case .fortyFiveDown: "FortyFiveDown"
        case .singleDown: "SingleDown"
        case .doubleDown: "DoubleDown"
        case .notComputable: "NotComputable"
        case .rateOutOfRange: "RateOutOfRange"
        }
    }

    /// Flèche affichée à l'écran. Vide quand la tendance n'est pas exploitable.
    public var arrow: String {
        switch self {
        case .doubleUp: "↑↑"
        case .singleUp: "↑"
        case .fortyFiveUp: "↗"
        case .flat: "→"
        case .fortyFiveDown: "↘"
        case .singleDown: "↓"
        case .doubleDown: "↓↓"
        case .none, .notComputable, .rateOutOfRange: ""
        }
    }

    /// Libellé parlé par Siri.
    public var spokenLabel: String {
        switch self {
        case .doubleUp: "en forte hausse"
        case .singleUp: "en hausse"
        case .fortyFiveUp: "en légère hausse"
        case .flat: "stable"
        case .fortyFiveDown: "en légère baisse"
        case .singleDown: "en baisse"
        case .doubleDown: "en forte baisse"
        case .none, .notComputable, .rateOutOfRange: "tendance inconnue"
        }
    }

    /// Vraie quand la glycémie descend franchement — sert à détecter une hypo
    /// imminente avant que le seuil ne soit atteint.
    public var isFallingFast: Bool {
        self == .singleDown || self == .doubleDown
    }

    init(apiName: String) {
        self = Trend.allCases.first { $0.apiName == apiName } ?? .none
    }

    init(index: Int) {
        self = Trend(rawValue: index) ?? .none
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let index = try? container.decode(Int.self) {
            self = Trend(index: index)
        } else if let raw = try? container.decode(String.self) {
            // Un index encodé en chaîne reste un index.
            self = Int(raw).map(Trend.init(index:)) ?? Trend(apiName: raw)
        } else {
            self = .none
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}
