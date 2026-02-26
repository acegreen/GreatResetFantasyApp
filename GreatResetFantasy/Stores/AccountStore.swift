//
//  AccountStore.swift
//  GreatResetFantasy
//

import Foundation
import SwiftUI
import UIKit
internal import Auth

/// Holds current user's account data (display name, avatar) synced with Supabase.
@Observable
final class AccountStore {
    private weak var session: SupabaseSessionManager?

    var displayName: String = ""
    var avatarLabel: String = AppConstants.adminAvatarLabel
    var avatarUrl: String?

    private var saveTask: Task<Void, Never>?

    init(session: SupabaseSessionManager? = nil) {
        self.session = session
    }

    func setSession(_ session: SupabaseSessionManager?) {
        self.session = session
    }

    /// Display name for UI: DB value, or email prefix, or fallback. Use this instead of raw displayName.
    var effectiveDisplayName: String {
        if !displayName.isEmpty { return displayName }
        if let email = session?.user?.email, let prefix = email.split(separator: "@").first {
            return String(prefix)
        }
        return "Your account"
    }

    /// Initials derived from effectiveDisplayName (e.g. "John Doe" → "JD").
    var avatarInitials: String {
        let name = effectiveDisplayName
        let parts = name.split(whereSeparator: { ". _-".contains($0) })
        if parts.count >= 2 {
            return String(parts.prefix(2).compactMap(\.first)).uppercased()
        }
        return String(name.prefix(2)).uppercased()
    }

    /// Call when user signs out or switches account. Clears immediately so UI doesn't show stale avatar/name.
    func clearForSignOut() {
        displayName = ""
        avatarLabel = AppConstants.adminAvatarLabel
        avatarUrl = nil
    }

    /// Fetch account from Supabase. Call when user logs in or app becomes active.
    /// If display_name is empty, backfills from email prefix and upserts.
    func refresh() async {
        guard let userId = session?.user?.id else {
            await MainActor.run {
                displayName = ""
                avatarLabel = AppConstants.adminAvatarLabel
                avatarUrl = nil
            }
            return
        }

        let service = AccountService(client: session!.client)
        let emailPrefix = session?.user?.email.flatMap { email in
            email.split(separator: "@").first.map { String($0) }
        } ?? ""

        do {
            if let row = try await service.fetch(userId: userId) {
                let fetchedName = row.displayName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                await MainActor.run {
                    displayName = fetchedName.isEmpty ? emailPrefix : fetchedName
                    avatarLabel = (row.avatarLabel?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { $0.isEmpty ? nil : $0 } ?? AppConstants.adminAvatarLabel
                    avatarUrl = row.avatarUrl
                }
                if fetchedName.isEmpty, !emailPrefix.isEmpty {
                    let label = (row.avatarLabel?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { $0.isEmpty ? nil : $0 } ?? AppConstants.adminAvatarLabel
                    try? await service.upsert(UserAccountUpsert(
                        userId: userId,
                        displayName: emailPrefix,
                        avatarLabel: label,
                        avatarUrl: row.avatarUrl,
                        updatedAt: Date()
                    ))
                }
            } else {
                let nameToUse = emailPrefix
                await MainActor.run {
                    displayName = nameToUse
                    avatarLabel = AppConstants.adminAvatarLabel
                    avatarUrl = nil
                }
                if !nameToUse.isEmpty {
                    try? await service.upsert(UserAccountUpsert(
                        userId: userId,
                        displayName: nameToUse,
                        avatarLabel: AppConstants.adminAvatarLabel,
                        avatarUrl: nil,
                        updatedAt: Date()
                    ))
                }
            }
        } catch {
            await MainActor.run {
                displayName = emailPrefix
                avatarLabel = AppConstants.adminAvatarLabel
                avatarUrl = nil
            }
        }
    }

    /// Upload avatar image and persist URL to Supabase.
    func uploadAvatar(_ imageData: Data) async throws {
        guard let userId = session?.user?.id else {
            throw NSError(domain: "AccountStore", code: -1, userInfo: [NSLocalizedDescriptionKey: "Not signed in"])
        }

        let jpegData: Data
        if let image = UIImage(data: imageData),
           let data = image.jpegData(compressionQuality: 0.8) {
            jpegData = data
        } else {
            jpegData = imageData
        }

        let service = AccountService(client: session!.client)
        let baseUrl = try await service.uploadAvatar(userId: userId, data: jpegData)
        let cacheBuster = Int(Date().timeIntervalSince1970)
        let urlString = "\(baseUrl)?v=\(cacheBuster)"

        await MainActor.run { avatarUrl = urlString }

        let payload = UserAccountUpsert(
            userId: userId,
            displayName: displayName.isEmpty ? "" : displayName,
            avatarLabel: avatarLabel,
            avatarUrl: urlString,
            updatedAt: Date()
        )
        try await service.upsert(payload)
    }

    /// Binding for display name field; saves to Supabase with debounce.
    func displayNameBinding() -> Binding<String> {
        Binding(
            get: { self.displayName },
            set: { [weak self] newValue in
                guard let self else { return }
                let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                self.displayName = trimmed
                self.saveTask?.cancel()
                self.saveTask = Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                    guard !Task.isCancelled else { return }
                    try? await self.update(displayName: trimmed)
                }
            }
        )
    }

    /// Update account and persist to Supabase.
    func update(displayName: String) async throws {
        guard let userId = session?.user?.id else { return }

        let trimmed = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        await MainActor.run { self.displayName = trimmed }

        let payload = UserAccountUpsert(
            userId: userId,
            displayName: trimmed.isEmpty ? "" : trimmed,
            avatarLabel: avatarLabel,
            avatarUrl: avatarUrl,
            updatedAt: Date()
        )
        try await AccountService(client: session!.client).upsert(payload)
    }
}
