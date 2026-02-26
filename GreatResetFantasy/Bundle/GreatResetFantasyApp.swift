//
//  GreatResetFantasyApp.swift
//  GreatResetFantasy
//
//  Created by AceGreen on 2026-02-26.
//

import SwiftUI
internal import Auth

@main
struct GreatResetFantasyApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @State private var supabaseSession = SupabaseSessionManager()
    @State private var streakStore = StreakStore()
    @State private var accountStore = AccountStore()
    /// Set when we leave .active (inactive/background); prevents counting multitasking or resume as a visit.
    @State private var leftActiveOnce = false

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(supabaseSession)
                .environment(streakStore)
                .environment(accountStore)
                .onAppear {
                    streakStore.setSession(supabaseSession)
                    accountStore.setSession(supabaseSession)
                    if scenePhase == .active, !leftActiveOnce {
                        leftActiveOnce = true
                        Task {
                            await streakStore.refresh()
                            await accountStore.refresh()
                            streakStore.recordVisit()
                        }
                    }
                }
                .onChange(of: scenePhase) { oldPhase, newPhase in
                    switch (oldPhase, newPhase) {
                    case (_, .active) where !leftActiveOnce:
                        streakStore.setSession(supabaseSession)
                        accountStore.setSession(supabaseSession)
                        leftActiveOnce = true
                        Task {
                            await streakStore.refresh()
                            await accountStore.refresh()
                            streakStore.recordVisit()
                        }
                    case (.active, .inactive), (.active, .background):
                        leftActiveOnce = true
                    default:
                        break
                    }
                }
                .onChange(of: supabaseSession.user?.id) { _, _ in
                    accountStore.clearForSignOut()
                    streakStore.clearForSignOut()
                    Task {
                        await streakStore.refresh()
                        await accountStore.refresh()
                    }
                }
                .onOpenURL { url in
                    // Handle greatresetfantasy:// deep links (e.g. from share)
                    guard url.scheme == AppConstants.appURLScheme else { return }
                    // App opened from scheme; could route to specific tab/path here if needed
                }
        }
    }
}
