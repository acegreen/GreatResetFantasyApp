//
//  AdminService.swift
//  GreatResetFantasy
//

import Foundation
import Supabase

/// Admin with optional display name from user_accounts.
struct AdminWithProfile: Identifiable, Sendable {
    let id: UUID
    let userId: UUID
    let displayName: String?

    var displayLabel: String {
        if let name = displayName?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty {
            return name
        }
        return userId.uuidString
    }
}

struct AdminService {
    let client: SupabaseClient

    /// Fetch all admins with display names from user_accounts.
    func fetchAdminsWithProfiles() async throws -> [AdminWithProfile] {
        let admins: [AdminUserRow] = try await client
            .from("admin_users")
            .select()
            .execute()
            .value

        guard !admins.isEmpty else { return [] }

        let userIds = admins.map(\.userId)
        let accounts: [UserAccountRow] = try await client
            .from("user_accounts")
            .select()
            .in("user_id", values: userIds)
            .execute()
            .value

        let nameByUserId = Dictionary(uniqueKeysWithValues: accounts.map { ($0.userId, $0.displayName) })

        return admins.map { admin in
            AdminWithProfile(
                id: admin.userId,
                userId: admin.userId,
                displayName: nameByUserId[admin.userId] ?? nil
            )
        }
    }

    /// Add an admin by user ID. Requires caller to already be an admin (RLS).
    func addAdmin(userId: UUID) async throws {
        let payload = AdminUserInsert(userId: userId)
        try await client
            .from("admin_users")
            .insert(payload)
            .execute()
    }

    /// Remove an admin by user ID. Requires caller to already be an admin (RLS).
    func removeAdmin(userId: UUID) async throws {
        try await client
            .from("admin_users")
            .delete()
            .eq("user_id", value: userId)
            .execute()
    }

    /// Search user_accounts by display name (case-insensitive, partial match).
    func searchUsers(byDisplayName searchTerm: String) async throws -> [UserAccountRow] {
        let trimmed = searchTerm.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else { return [] }

        let results: [UserAccountRow] = try await client
            .from("user_accounts")
            .select()
            .ilike("display_name", pattern: "%\(trimmed)%")
            .limit(20)
            .execute()
            .value

        #if DEBUG
        for row in results {
            print("[Admin] user_id: \(row.userId.uuidString), display_name: \(row.displayName ?? "(nil)")")
        }
        #endif

        return results
    }
}
