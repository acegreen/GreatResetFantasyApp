//
//  SupabaseSession.swift
//  GreatResetFantasy
//

import Foundation
import SwiftUI
import Supabase

/// Shared Supabase client and auth state. Credentials from Secrets.generated.swift (built from Supabase/Secrets.xcconfig).
/// See docs/Supabase_credentials_setup.xcconfig for setup — copy to Supabase/Secrets.xcconfig and add your Supabase URL/key.
@Observable
final class SupabaseSessionManager {
    private(set) var session: Session?

    let client: SupabaseClient

    var user: User? { session?.user }
    var isLoggedIn: Bool { session != nil }

    init(
        supabaseURL: URL? = nil,
        supabaseKey: String? = nil
    ) {
        let url: URL
        let key: String
        if let u = supabaseURL, let k = supabaseKey {
            url = u
            key = k
        } else {
            guard let parsedURL = URL(string: Secrets.supabaseURL) else {
                fatalError("Invalid SUPABASE_URL in Supabase/Secrets.xcconfig")
            }
            url = parsedURL
            key = Secrets.supabaseKey
        }
        client = SupabaseClient(supabaseURL: url, supabaseKey: key)
        session = nil
        Task { await listenAuth() }
    }

    init(client: SupabaseClient) {
        self.client = client
        session = nil
        Task { await listenAuth() }
    }

    private func listenAuth() async {
        for await (_, session) in client.auth.authStateChanges {
            await MainActor.run { self.session = session }
        }
    }

    func register(email: String, password: String) async throws {
        _ = try await client.auth.signUp(email: email, password: password)
        try await login(email: email, password: password)
    }

    func login(email: String, password: String) async throws {
        _ = try await client.auth.signIn(email: email, password: password)
        session = try await client.auth.session
    }

    func logout() async {
        try? await client.auth.signOut()
        await MainActor.run { session = nil }
    }
}
