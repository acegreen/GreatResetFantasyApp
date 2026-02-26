//
//  StreakService.swift
//  GreatResetFantasy
//

import Foundation
import Supabase

private struct VoteIdRow: Decodable {
    let id: UUID
}

struct StreakService {
    let client: SupabaseClient

    /// Returns the number of votes cast by this user (source of truth for poll streak).
    func fetchVoteCount(userId: UUID) async throws -> Int {
        let rows: [VoteIdRow] = try await client
            .from("votes")
            .select("id")
            .eq("user_id", value: userId)
            .execute()
            .value
        return rows.count
    }

    func fetch(userId: UUID) async throws -> UserAccountRow? {
        let rows: [UserAccountRow] = try await client
            .from("user_accounts")
            .select()
            .eq("user_id", value: userId)
            .limit(1)
            .execute()
            .value
        return rows.first
    }

    func upsert(_ payload: UserAccountStreaksUpsert) async throws {
        try await client
            .from("user_accounts")
            .upsert(payload, onConflict: "user_id")
            .execute()
    }
}
