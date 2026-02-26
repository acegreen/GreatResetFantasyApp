//
//  AccountService.swift
//  GreatResetFantasy
//

import Foundation
import Supabase

private let avatarsBucket = "avatars"

struct AccountService {
    let client: SupabaseClient

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

    func upsert(_ payload: UserAccountUpsert) async throws {
        try await client
            .from("user_accounts")
            .upsert(payload, onConflict: "user_id")
            .execute()
    }

    /// Upload avatar image and return public URL.
    func uploadAvatar(userId: UUID, data: Data) async throws -> String {
        let path = "\(userId.uuidString).jpg"
        _ = try await client.storage
            .from(avatarsBucket)
            .upload(path, data: data, options: FileOptions(contentType: "image/jpeg", upsert: true))
        return try client.storage
            .from(avatarsBucket)
            .getPublicURL(path: path)
            .absoluteString
    }
}
