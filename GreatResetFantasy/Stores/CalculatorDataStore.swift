//
//  CalculatorDataStore.swift
//  GreatResetFantasy
//

import Foundation
import SwiftUI

/// Fetches calculator config from Supabase and exposes a ResetCalculator. Falls back to default if fetch fails.
@Observable
final class CalculatorDataStore {
    private let configService: CalculatorConfigService
    private(set) var calculator: ResetCalculatorManager
    private(set) var isLoading = false
    private(set) var lastError: String?

    init(configService: CalculatorConfigService) {
        self.configService = configService
        self.calculator = ResetCalculatorManager()
    }

    /// Load config from Supabase and update calculator. Uses default if fetch fails.
    func refresh() async {
        isLoading = true
        lastError = nil
        defer { isLoading = false }

        do {
            async let globals = configService.fetchGlobals()
            async let brackets = configService.fetchWealthBrackets()
            async let scenarios = configService.fetchResetScenarios()
            let (g, b, s) = try await (globals, brackets, scenarios)
            if let calc = ResetCalculatorManager.from(globals: g, bracketRows: b, scenarioRows: s) {
                await MainActor.run { calculator = calc }
            }
        } catch {
            lastError = error.localizedDescription
            // Keep existing calculator (or default)
        }
    }
}
