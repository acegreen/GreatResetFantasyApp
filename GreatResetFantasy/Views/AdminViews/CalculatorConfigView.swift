//
//  CalculatorConfigView.swift
//  GreatResetFantasy
//

import SwiftUI

struct CalculatorConfigView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(SupabaseSessionManager.self) private var session
    @Environment(CalculatorDataStore.self) private var calculatorStore

    @State private var globals: CalculatorGlobalsRow?
    @State private var brackets: [WealthBracketRow] = []
    @State private var scenarios: [ResetScenarioRow] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var saving = false
    @State private var showingGlobalsEditor = false
    @State private var showingBracketEditor: WealthBracketRow?
    @State private var showingScenarioEditor: ResetScenarioRow?
    @State private var showingAddScenario = false

    private var configService: CalculatorConfigService {
        CalculatorConfigService(client: session.client)
    }

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Loading config…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        if let errorMessage {
                            Section {
                                Text(errorMessage)
                                    .foregroundStyle(.red)
                            }
                        }

                        Section("Global constants") {
                            if let g = globals {
                                LabeledContent("Total wealth", value: NumberFormatting.large(g.totalWealth))
                                LabeledContent("World population", value: NumberFormatting.large(g.worldPopulation))
                                LabeledContent("Poverty line/person", value: NumberFormatting.compact(g.povertyLinePerPerson))
                            }
                            Button("Edit globals") {
                                showingGlobalsEditor = true
                            }
                        }

                        Section("Wealth brackets") {
                            ForEach(brackets) { row in
                                Button {
                                    showingBracketEditor = row
                                } label: {
                                    HStack {
                                        Text(row.bracket)
                                        Spacer()
                                        Text("\(Int(row.wealthShare))% wealth, \(Int(row.populationShare))% pop")
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }

                        Section("Reset scenarios") {
                            ForEach(scenarios) { row in
                                Button {
                                    showingScenarioEditor = row
                                } label: {
                                    HStack {
                                        Text(row.label)
                                        Spacer()
                                        Text("Zeros cut: \(row.zerosCut)")
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                            Button("Add scenario") {
                                showingAddScenario = true
                            }
                        }
                    }
                }
            }
            .navigationTitle("Calculator config")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                }
            }
            .task { await load() }
            .sheet(isPresented: $showingGlobalsEditor) {
                GlobalsEditorView(
                    totalWealth: globals?.totalWealth ?? 500_000_000_000_000,
                    worldPopulation: globals?.worldPopulation ?? 8_000_000_000,
                    povertyLinePerPerson: globals?.povertyLinePerPerson ?? 10_000
                ) { tw, wp, pl in
                    Task {
                        await saveGlobals(totalWealth: tw, worldPopulation: wp, povertyLinePerPerson: pl)
                        await load()
                        await calculatorStore.refresh()
                        await MainActor.run {
                            showingGlobalsEditor = false
                        }
                    }
                } onCancel: {
                    showingGlobalsEditor = false
                }
            }
            .sheet(item: $showingBracketEditor) { row in
                BracketEditorView(
                    bracket: row.bracket,
                    wealthShare: row.wealthShare,
                    populationShare: row.populationShare,
                    vulnerability: row.vulnerability
                ) { ws, ps, v in
                    Task {
                        await saveBracket(id: row.id, wealthShare: ws, populationShare: ps, vulnerability: v)
                        await load()
                        await calculatorStore.refresh()
                        await MainActor.run {
                            showingBracketEditor = nil
                        }
                    }
                } onCancel: {
                    showingBracketEditor = nil
                }
            }
            .sheet(item: $showingScenarioEditor) { row in
                ScenarioEditorView(
                    label: row.label,
                    zerosCut: row.zerosCut
                ) { label, zeros in
                    Task {
                        await saveScenario(id: row.id, label: label, zerosCut: zeros)
                        await load()
                        await calculatorStore.refresh()
                        await MainActor.run {
                            showingScenarioEditor = nil
                        }
                    }
                } onDelete: {
                    Task {
                        await deleteScenario(id: row.id)
                        await load()
                        await calculatorStore.refresh()
                        await MainActor.run {
                            showingScenarioEditor = nil
                        }
                    }
                } onCancel: {
                    showingScenarioEditor = nil
                }
            }
            .sheet(isPresented: $showingAddScenario) {
                AddScenarioView { label, zerosCut in
                    Task {
                        await addScenario(label: label, zerosCut: zerosCut)
                        await load()
                        await calculatorStore.refresh()
                        await MainActor.run {
                            showingAddScenario = false
                        }
                    }
                } onCancel: {
                    showingAddScenario = false
                }
            }
        }
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            async let g = configService.fetchGlobals()
            async let b = configService.fetchWealthBrackets()
            async let s = configService.fetchResetScenarios()
            let (globalsResult, bracketsResult, scenariosResult) = try await (g, b, s)
            await MainActor.run {
                self.globals = globalsResult
                self.brackets = bracketsResult
                self.scenarios = scenariosResult
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func saveGlobals(totalWealth: Double, worldPopulation: Double, povertyLinePerPerson: Double) async {
        saving = true
        defer { saving = false }
        try? await configService.updateGlobals(totalWealth: totalWealth, worldPopulation: worldPopulation, povertyLinePerPerson: povertyLinePerPerson)
    }

    private func saveBracket(id: UUID, wealthShare: Double, populationShare: Double, vulnerability: Double) async {
        try? await configService.updateWealthBracket(id: id, wealthShare: wealthShare, populationShare: populationShare, vulnerability: vulnerability)
    }

    private func saveScenario(id: UUID, label: String, zerosCut: Int) async {
        try? await configService.updateResetScenario(id: id, label: label, zerosCut: zerosCut)
    }

    private func deleteScenario(id: UUID) async {
        try? await configService.deleteResetScenario(id: id)
    }

    private func addScenario(label: String, zerosCut: Int) async {
        let order = (scenarios.map(\.sortOrder).max() ?? -1) + 1
        _ = try? await configService.insertResetScenario(label: label, zerosCut: zerosCut, sortOrder: order)
    }
}

// MARK: - Globals editor

private struct GlobalsEditorView: View {
    @State var totalWealth: Double
    @State var worldPopulation: Double
    @State var povertyLinePerPerson: Double
    let onSave: (Double, Double, Double) -> Void
    let onCancel: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Global constants") {
                    TextField("Total wealth", value: $totalWealth, format: .number)
                        .keyboardType(.decimalPad)
                    TextField("World population", value: $worldPopulation, format: .number)
                        .keyboardType(.decimalPad)
                    TextField("Poverty line per person", value: $povertyLinePerPerson, format: .number)
                        .keyboardType(.decimalPad)
                }
            }
            .navigationTitle("Edit globals")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onCancel() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(totalWealth, worldPopulation, povertyLinePerPerson)
                    }
                }
            }
        }
    }
}

// MARK: - Bracket editor

private struct BracketEditorView: View {
    let bracket: String
    @State var wealthShare: Double
    @State var populationShare: Double
    @State var vulnerability: Double
    let onSave: (Double, Double, Double) -> Void
    let onCancel: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section(bracket) {
                    TextField("Wealth share %", value: $wealthShare, format: .number)
                    TextField("Population share %", value: $populationShare, format: .number)
                    TextField("Vulnerability", value: $vulnerability, format: .number)
                }
            }
            .navigationTitle("Edit bracket")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onCancel() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(wealthShare, populationShare, vulnerability)
                    }
                }
            }
        }
    }
}

// MARK: - Scenario editor

private struct ScenarioEditorView: View {
    @State var label: String
    @State var zerosCut: Int
    let onSave: (String, Int) -> Void
    let onDelete: () -> Void
    let onCancel: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Scenario") {
                    TextField("Label", text: $label)
                    TextField("Zeros cut", value: $zerosCut, format: .number)
                        .keyboardType(.numberPad)
                }
                Section {
                    Button("Delete scenario", role: .destructive) {
                        onDelete()
                    }
                }
            }
            .navigationTitle("Edit scenario")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onCancel() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(label, zerosCut)
                    }
                }
            }
        }
    }
}

// MARK: - Add scenario

private struct AddScenarioView: View {
    @State private var label = ""
    @State private var zerosCut = 0
    let onAdd: (String, Int) -> Void
    let onCancel: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("New scenario") {
                    TextField("Label", text: $label)
                    TextField("Zeros cut", value: $zerosCut, format: .number)
                        .keyboardType(.numberPad)
                }
            }
            .navigationTitle("Add scenario")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onCancel() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        onAdd(label, zerosCut)
                    }
                    .disabled(label.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}
