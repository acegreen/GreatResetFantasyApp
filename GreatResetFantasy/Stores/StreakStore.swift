//
//  StreakStore.swift
//  GreatResetFantasy
//

import Foundation
import SwiftUI
internal import Auth

/// Tracks visit, poll, and share streaks. Persists to Supabase when logged in, UserDefaults when anonymous.
/// UserDefaults keys are scoped by user ID so streaks don't leak between accounts.
@Observable
final class StreakStore {
    private weak var session: SupabaseSessionManager?
    private let defaults = UserDefaults.standard
    private let keyPrefix = "streak"
    private let visitKeySuffix = "visit_date"
    private let visitStreakKeySuffix = "visit_count"
    private let pollDateKeySuffix = "poll_date"
    private let pollStreakKeySuffix = "poll_count"
    private let shareDateKeySuffix = "share_date"
    private let shareStreakKeySuffix = "share_count"
    /// Legacy keys for migration; anonymous/local data uses "local" scope
    private let anonymousScope = "local"

    private(set) var visitStreak: Int
    private(set) var pollStreak: Int
    private(set) var shareStreak: Int

    private var lastVisitDate: Date?
    private var lastPollDate: Date?
    private var lastShareDate: Date?

    private var calendar: Calendar { .current }

    init(session: SupabaseSessionManager? = nil) {
        self.session = session
        self.visitStreak = 0
        self.pollStreak = 0
        self.shareStreak = 0
    }

    private func defaultsScope() -> String {
        session?.user?.id.uuidString ?? anonymousScope
    }

    private func key(_ suffix: String) -> String {
        "\(keyPrefix)_\(defaultsScope())_\(suffix)"
    }

    /// Inject session after init (App creates StreakStore before session is available to init).
    func setSession(_ session: SupabaseSessionManager?) {
        self.session = session
    }

    /// Call when user signs out. Clears in-memory state so new account doesn't see previous data.
    func clearForSignOut() {
        visitStreak = 0
        pollStreak = 0
        shareStreak = 0
        lastVisitDate = nil
        lastPollDate = nil
        lastShareDate = nil
    }

    /// Load streaks from Supabase when logged in. Always loads UserDefaults first, then merges
    /// with Supabase (takes max of each streak) so Supabase never overwrites with stale/lower data.
    /// When signed out, loads from "local" scope for anonymous usage.
    func refresh() async {
        guard let userId = session?.user?.id else {
            loadFromUserDefaults()
            return
        }
        loadFromUserDefaults()
        let service = StreakService(client: session!.client)
        do {
            if let row = try await service.fetch(userId: userId) {
                await MainActor.run {
                    visitStreak = max(visitStreak, row.visitStreak)
                    pollStreak = max(pollStreak, row.pollStreak)
                    shareStreak = max(shareStreak, row.shareStreak)
                    lastVisitDate = newerOf(lastVisitDate, row.lastVisitDate)
                    lastPollDate = newerOf(lastPollDate, row.lastPollDate)
                    lastShareDate = newerOf(lastShareDate, row.lastShareDate)
                }
            }
        } catch {
            // Keep UserDefaults values from loadFromUserDefaults
        }
        do {
            let voteCount = try await service.fetchVoteCount(userId: userId)
            await MainActor.run {
                pollStreak = voteCount
                lastPollDate = calendar.startOfDay(for: Date())
                defaults.set(pollStreak, forKey: key(pollStreakKeySuffix))
                defaults.set(lastPollDate, forKey: key(pollDateKeySuffix))
                Task { await saveToSupabase() }
            }
        } catch {
            // Keep existing pollStreak
        }
    }

    private func newerOf(_ a: Date?, _ b: Date?) -> Date? {
        switch (a, b) {
        case let (a?, b?): return max(a, b)
        case (let a?, nil): return a
        case (nil, let b?): return b
        case (nil, nil): return nil
        }
    }

    private func loadFromUserDefaults() {
        visitStreak = defaults.integer(forKey: key(visitStreakKeySuffix))
        pollStreak = defaults.integer(forKey: key(pollStreakKeySuffix))
        shareStreak = defaults.integer(forKey: key(shareStreakKeySuffix))
        lastVisitDate = defaults.object(forKey: key(visitKeySuffix)) as? Date
        lastPollDate = defaults.object(forKey: key(pollDateKeySuffix)) as? Date
        lastShareDate = defaults.object(forKey: key(shareDateKeySuffix)) as? Date
    }

    /// Call when the app launches (once per launch). Increments on every launch.
    func recordVisit() {
        visitStreak += 1
        lastVisitDate = calendar.startOfDay(for: Date())
        persistVisit(streak: visitStreak, date: lastVisitDate!)
    }

    /// Sync poll streak to the actual number of polls the user has voted on (source of truth).
    func syncPollStreakFromVoteCount(_ count: Int) {
        pollStreak = count
        lastPollDate = calendar.startOfDay(for: Date())
        persistPoll(streak: pollStreak, date: lastPollDate!)
    }

    /// Call when the user initiates a share (tap on ShareLink). Increments on every share.
    func recordShare() {
        shareStreak += 1
        lastShareDate = calendar.startOfDay(for: Date())
        persistShare(streak: shareStreak, date: lastShareDate!)
    }

    // MARK: - Persistence

    private func persistVisit(streak: Int, date: Date) {
        defaults.set(date, forKey: key(visitKeySuffix))
        defaults.set(streak, forKey: key(visitStreakKeySuffix))
        Task { await saveToSupabase() }
    }

    private func persistPoll(streak: Int, date: Date) {
        defaults.set(date, forKey: key(pollDateKeySuffix))
        defaults.set(streak, forKey: key(pollStreakKeySuffix))
        Task { await saveToSupabase() }
    }

    private func persistShare(streak: Int, date: Date) {
        defaults.set(date, forKey: key(shareDateKeySuffix))
        defaults.set(streak, forKey: key(shareStreakKeySuffix))
        Task { await saveToSupabase() }
    }

    private func saveToSupabase() async {
        guard let userId = session?.user?.id else { return }
        let payload = UserAccountStreaksUpsert(
            userId: userId,
            visitStreak: visitStreak,
            pollStreak: pollStreak,
            shareStreak: shareStreak,
            lastVisitDate: lastVisitDate,
            lastPollDate: lastPollDate,
            lastShareDate: lastShareDate,
            updatedAt: Date()
        )
        do {
            let service = StreakService(client: session!.client)
            try await service.upsert(payload)
        } catch {
            // Silently fail; UserDefaults already has the data
        }
    }
}
