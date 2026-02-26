import SwiftUI
import Foundation

enum Brackets: String, CaseIterable, Identifiable, Hashable {
    case top1
    case next9
    case middle40
    case bottom50

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .top1: return "Top 1%"
        case .next9: return "Next 9%"
        case .middle40: return "Middle 40%"
        case .bottom50: return "Bottom 50%"
        }
    }

    var color: Color {
        switch self {
        case .top1: return .orange
        case .next9: return .yellow
        case .middle40: return .blue
        case .bottom50: return .purple
        }
    }
}

struct WealthBracket: Identifiable, Hashable {
    let id: UUID
    let bracket: Brackets
    let wealthShare: Double
    let populationShare: Double
    /// Higher value = bracket loses more wealth as zeros increase (used in haircut).
    let vulnerability: Double

    var name: String { bracket.displayName }
    var color: Color { bracket.color }

    init(id: UUID = UUID(), bracket: Brackets, wealthShare: Double, populationShare: Double, vulnerability: Double = 0.5) {
        self.id = id
        self.bracket = bracket
        self.wealthShare = wealthShare
        self.populationShare = populationShare
        self.vulnerability = vulnerability
    }
}

struct WealthTrendPoint: Identifiable {
    let id = UUID()
    let scenarioLabel: String
    let bracketShares: [Brackets: Double] // Bracket -> wealth share
}

/// One point for per-capita wealth by scenario and bracket (for trend charts).
struct PerCapitaTrendPoint: Identifiable {
    let id = UUID()
    let scenarioLabel: String
    let bracket: Brackets
    let perCapitaWealth: Double
}

/// Shared calculator/model for reset scenarios used by both the simulator and trends views.
struct ResetCalculatorManager {
    let brackets: [WealthBracket]
    let totalWealth: Double
    let worldPopulation: Double
    let povertyLinePerPerson: Double
    /// Scenario labels and zeros cut (from DB or defaults).
    let scenarios: [(label: String, zerosCut: Int)]

    init() {
        let brackets: [WealthBracket] = [
            WealthBracket(bracket: .top1, wealthShare: 43, populationShare: 1, vulnerability: 0.2),
            WealthBracket(bracket: .next9, wealthShare: 52, populationShare: 9, vulnerability: 0.4),
            WealthBracket(bracket: .middle40, wealthShare: 14, populationShare: 40, vulnerability: 0.8),
            WealthBracket(bracket: .bottom50, wealthShare: 1, populationShare: 50, vulnerability: 1.2)
        ]
        self.init(
            brackets: brackets,
            totalWealth: 500_000_000_000_000.0,
            worldPopulation: 8_000_000_000.0,
            povertyLinePerPerson: 10_000.0,
            scenarios: [
                ("Before Reset", 0),
                ("Mild Reset", 3),
                ("Moderate Reset", 6),
                ("Severe Reset", 9)
            ]
        )
    }

    init(brackets: [WealthBracket], totalWealth: Double, worldPopulation: Double, povertyLinePerPerson: Double, scenarios: [(label: String, zerosCut: Int)]) {
        self.brackets = brackets
        self.totalWealth = totalWealth
        self.worldPopulation = worldPopulation
        self.povertyLinePerPerson = povertyLinePerPerson
        self.scenarios = scenarios
    }

    /// Build from Supabase rows; returns nil if data is missing or invalid (caller should use default init).
    static func from(
        globals: CalculatorGlobalsRow?,
        bracketRows: [WealthBracketRow]?,
        scenarioRows: [ResetScenarioRow]?
    ) -> ResetCalculatorManager? {
        guard let g = globals, let br = bracketRows, !br.isEmpty, let sr = scenarioRows, !sr.isEmpty else { return nil }
        let brackets: [WealthBracket] = br.compactMap { row in
            guard let b = Brackets(rawValue: row.bracket) else { return nil }
            return WealthBracket(
                id: row.id,
                bracket: b,
                wealthShare: row.wealthShare,
                populationShare: row.populationShare,
                vulnerability: row.vulnerability
            )
        }
        guard brackets.count == br.count else { return nil }
        let scenarios = sr.map { ($0.label, $0.zerosCut) }
        return ResetCalculatorManager(
            brackets: brackets,
            totalWealth: g.totalWealth,
            worldPopulation: g.worldPopulation,
            povertyLinePerPerson: g.povertyLinePerPerson,
            scenarios: scenarios
        )
    }

    // MARK: - Core calculations

    func wealthFor(_ bracket: WealthBracket) -> Double {
        totalWealth * (bracket.wealthShare / 100.0)
    }

    func adjustedWealth(for bracket: WealthBracket, zerosCut: Int) -> Double {
        let before = wealthFor(bracket)
        let multiplier = haircutMultiplier(for: bracket, zerosCut: zerosCut)
        return before * multiplier
    }

    /// Applies currency re-denomination by dividing balances by 10^N when N zeros are cut.
    /// This is used for display only; core calculations stay in base units so charts and
    /// ratios don't collapse toward zero when you change denominations.
    func denominatedWealth(_ wealth: Double, zerosCut: Int) -> Double {
        guard zerosCut > 0 else { return wealth }
        return wealth / pow(10.0, Double(zerosCut))
    }

    private func haircutMultiplier(for bracket: WealthBracket, zerosCut: Int) -> Double {
        let intensity = Double(zerosCut) / 9.0 // 0 (no reset) → 1 (max reset)
        let raw = 1.0 - bracket.vulnerability * intensity
        return max(raw, 0.02)
    }

    func wealthShareAfterReset(for bracket: WealthBracket, zerosCut: Int) -> Double {
        let totalAdjusted = brackets
            .map { adjustedWealth(for: $0, zerosCut: zerosCut) }
            .reduce(0, +)

        guard totalAdjusted > 0 else { return 0 }

        return adjustedWealth(for: bracket, zerosCut: zerosCut) / totalAdjusted * 100.0
    }

    func perCapitaWealthAfterReset(for bracket: WealthBracket, zerosCut: Int) -> Double {
        let bracketWealth = adjustedWealth(for: bracket, zerosCut: zerosCut)
        let bracketPopulation = worldPopulation * (bracket.populationShare / 100.0)
        return bracketPopulation == 0 ? 0 : bracketWealth / bracketPopulation
    }

    func estimatedPeopleInPoverty(zerosCut: Int) -> Double {
        brackets.reduce(0) { sum, bracket in
            let perCapita = perCapitaWealthAfterReset(for: bracket, zerosCut: zerosCut)
            let bracketPopulation = worldPopulation * (bracket.populationShare / 100.0)
            let fractionInPoverty = povertyFraction(for: bracket, perCapita: perCapita)
            return sum + bracketPopulation * fractionInPoverty
        }
    }

    /// Smoothly estimates what fraction of each bracket falls below the poverty line.
    /// Uses a continuous curve so the total count changes gradually as zeros are cut,
    /// instead of all-or-nothing jumps when a bracket crosses the threshold.
    private func povertyFraction(for bracket: WealthBracket, perCapita: Double) -> Double {
        guard perCapita > 0 else { return 1.0 }

        // Ratio > 1 → per-capita wealth below the poverty line (more people at risk).
        // Ratio < 1 → per-capita wealth above the poverty line (fewer people at risk).
        let ratio = povertyLinePerPerson / perCapita

        // More "vulnerable" brackets transition into poverty faster as wealth falls.
        let sensitivity = 0.6 + bracket.vulnerability // ~0.8–1.8 with current defaults
        let rawValue = pow(ratio, sensitivity)

        // Clamp into [0, 1] to get a valid fraction of the bracket's population.
        return max(0.0, min(1.0, rawValue))
    }

    // MARK: - Trend data

    /// People in poverty (count) per scenario for charts.
    var povertyTrendData: [(scenarioLabel: String, peopleInPoverty: Double)] {
        scenarios.map { scenario in
            (scenario.label, estimatedPeopleInPoverty(zerosCut: scenario.zerosCut))
        }
    }

    /// Per-capita wealth by scenario and bracket for charts.
    var perCapitaTrendData: [PerCapitaTrendPoint] {
        var result: [PerCapitaTrendPoint] = []
        for scenario in scenarios {
            for bracket in brackets {
                let perCapita = perCapitaWealthAfterReset(for: bracket, zerosCut: scenario.zerosCut)
                result.append(PerCapitaTrendPoint(
                    scenarioLabel: scenario.label,
                    bracket: bracket.bracket,
                    perCapitaWealth: perCapita
                ))
            }
        }
        return result
    }

    /// Wealth share by scenario (uses real formulas) for stacked/line charts.
    var wealthShareTrendData: [WealthTrendPoint] {
        scenarios.map { scenario in
            let shares = Dictionary(uniqueKeysWithValues: brackets.map { bracket in
                (bracket.bracket, wealthShareAfterReset(for: bracket, zerosCut: scenario.zerosCut))
            })
            return WealthTrendPoint(scenarioLabel: scenario.label, bracketShares: shares)
        }
    }

}

