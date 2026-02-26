//
//  RootView.swift
//  GreatResetFantasy
//

import SwiftUI
internal import Auth

/// Creates CalculatorDataStore from session client and provides it to the tab content.
struct RootView: View {
    @Environment(SupabaseSessionManager.self) private var supabaseSession
    @State private var calculatorStore: CalculatorDataStore?

    var body: some View {
        Group {
            if let calculatorStore {
                TabView {
                    SimulatorView()
                        .tabItem {
                            Label("Simulator", systemImage: "slider.horizontal.2.square")
                        }

                    TrendsView()
                        .tabItem {
                            Label("Trends", systemImage: "chart.line.downtrend.xyaxis")
                        }

                    PollsView()
                        .tabItem {
                            Label("Polls", systemImage: "list.bullet.rectangle")
                        }

                    SettingsView()
                        .tabItem {
                            Label("Settings", systemImage: "gearshape")
                        }
                }
                .environment(supabaseSession)
                .environment(calculatorStore)
            } else {
                ProgressView("Loading…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task {
            guard calculatorStore == nil else { return }
            let configService = CalculatorConfigService(client: supabaseSession.client)
            let store = CalculatorDataStore(configService: configService)
            await store.refresh()
            calculatorStore = store
        }
    }
}
