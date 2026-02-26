//
//  CalculatorConfigService.swift
//  GreatResetFantasy
//

import Foundation
import Supabase

struct CalculatorConfigService {
    let client: SupabaseClient

    /// Fetch global constants (single row).
    func fetchGlobals() async throws -> CalculatorGlobalsRow? {
        let rows: [CalculatorGlobalsRow] = try await client
            .from("calculator_globals")
            .select()
            .limit(1)
            .execute()
            .value
        return rows.first
    }

    /// Update global constants.
    func updateGlobals(totalWealth: Double, worldPopulation: Double, povertyLinePerPerson: Double) async throws {
        let payload = CalculatorGlobalsUpdate(
            totalWealth: totalWealth,
            worldPopulation: worldPopulation,
            povertyLinePerPerson: povertyLinePerPerson,
            updatedAt: ISO8601DateFormatter().string(from: Date())
        )
        try await client
            .from("calculator_globals")
            .update(payload)
            .eq("id", value: 1)
            .execute()
    }

    /// Fetch all wealth brackets ordered by sort_order.
    func fetchWealthBrackets() async throws -> [WealthBracketRow] {
        try await client
            .from("wealth_brackets")
            .select()
            .order("sort_order")
            .execute()
            .value
    }

    /// Update a single wealth bracket.
    func updateWealthBracket(id: UUID, wealthShare: Double, populationShare: Double, vulnerability: Double) async throws {
        let payload = WealthBracketUpdate(
            wealthShare: wealthShare,
            populationShare: populationShare,
            vulnerability: vulnerability
        )
        try await client
            .from("wealth_brackets")
            .update(payload)
            .eq("id", value: id)
            .execute()
    }

    /// Fetch all reset scenarios ordered by sort_order.
    func fetchResetScenarios() async throws -> [ResetScenarioRow] {
        try await client
            .from("reset_scenarios")
            .select()
            .order("sort_order")
            .execute()
            .value
    }

    /// Update a single reset scenario.
    func updateResetScenario(id: UUID, label: String, zerosCut: Int) async throws {
        let payload = ResetScenarioUpdate(label: label, zerosCut: zerosCut)
        try await client
            .from("reset_scenarios")
            .update(payload)
            .eq("id", value: id)
            .execute()
    }

    /// Insert a new reset scenario.
    func insertResetScenario(label: String, zerosCut: Int, sortOrder: Int) async throws -> ResetScenarioRow {
        let insert = ResetScenarioInsert(label: label, zerosCut: zerosCut, sortOrder: sortOrder)
        return try await client
            .from("reset_scenarios")
            .insert(insert)
            .select()
            .single()
            .execute()
            .value
    }

    /// Delete a reset scenario.
    func deleteResetScenario(id: UUID) async throws {
        try await client
            .from("reset_scenarios")
            .delete()
            .eq("id", value: id)
            .execute()
    }
}
