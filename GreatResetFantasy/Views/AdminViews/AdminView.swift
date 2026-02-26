import SwiftUI
// import Inject

struct AdminView: View {
    // @ObserveInjection var inject

    @Environment(\.dismiss) private var dismiss
    @Environment(SupabaseSessionManager.self) private var supabaseSession
    @State private var showingPollAdmin = false
    @State private var showingCalculatorConfig = false

    @State private var admins: [AdminWithProfile] = []
    @State private var adminsLoading = true
    @State private var adminsError: String?
    @State private var newAdminUserIdText = ""
    @State private var addAdminInProgress = false
    @State private var addAdminError: String?
    @State private var nameSearchTerm = ""
    @State private var nameSearchResults: [UserAccountRow] = []
    @State private var nameSearchTask: Task<Void, Never>?

    private var adminService: AdminService {
        AdminService(client: supabaseSession.client)
    }

    var body: some View {
        NavigationStack {
            List {
                pollsSection
                simulatorSection
                adminUsersSection
            }
            .navigationTitle("Admin")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
            .task {
                await loadAdmins()
            }
            .refreshable {
                await loadAdmins()
            }
        }
        .sheet(isPresented: $showingPollAdmin) {
            PollCreationView()
        }
        .sheet(isPresented: $showingCalculatorConfig) {
            CalculatorConfigView()
        }
        // .enableInjection()
    }

    @ViewBuilder
    private var adminUsersSection: some View {
        Section {
            if adminsLoading {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
            } else if let error = adminsError {
                Text(error)
                    .foregroundStyle(.red)
            } else {
                ForEach(admins) { admin in
                    HStack {
                        Text(admin.displayLabel)
                            .lineLimit(1)
                        Spacer()
                        Button(role: .destructive) {
                            Task { await removeAdmin(admin.userId) }
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .foregroundStyle(.red)
                        }
                        .buttonStyle(.borderless)
                    }
                }

                HStack {
                    TextField("User ID (UUID)", text: $newAdminUserIdText)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Button("Add") {
                        Task { await addAdmin() }
                    }
                    .disabled(newAdminUserIdText.trimmingCharacters(in: .whitespaces).isEmpty || addAdminInProgress)
                }

                HStack {
                    TextField("Or search by display name", text: $nameSearchTerm)
                        .textInputAutocapitalization(.words)
                        .onChange(of: nameSearchTerm) { _, newValue in
                            runNameSearch(term: newValue)
                        }
                }

                if !nameSearchResults.isEmpty {
                    ForEach(nameSearchResults, id: \.userId) { account in
                        let label = account.displayName?.trimmingCharacters(in: .whitespaces).isEmpty == false
                            ? (account.displayName ?? "")
                            : account.userId.uuidString
                        Button {
                            Task { await addAdminByUserId(account.userId) }
                        } label: {
                            HStack {
                                Text(label)
                                    .lineLimit(1)
                                Spacer()
                                Text(account.userId.uuidString)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                        }
                        .disabled(addAdminInProgress)
                    }
                }

                if let addError = addAdminError {
                    Text(addError)
                        .foregroundStyle(.red)
                        .font(.caption)
                }
            }
        } header: {
            Text("Admin Users")
        } footer: {
            Text("User IDs from Supabase Dashboard → Authentication → Users")
        }
    }

    private var pollsSection: some View {
        Section("Polls") {
            Button {
                showingPollAdmin = true
            } label: {
                Label("Create poll", systemImage: "checklist")
            }
        }
    }

    private var simulatorSection: some View {
        Section("Simulator") {
            Button {
                showingCalculatorConfig = true
            } label: {
                Label("Edit calculator data", systemImage: "chart.bar.doc.horizontal")
            }
        }
    }

    private func loadAdmins() async {
        adminsLoading = true
        adminsError = nil
        defer { adminsLoading = false }

        do {
            admins = try await adminService.fetchAdminsWithProfiles()
        } catch {
            adminsError = (error as NSError).localizedDescription
        }
    }

    private func runNameSearch(term: String) {
        nameSearchTask?.cancel()
        let trimmed = term.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else {
            nameSearchResults = []
            return
        }
        nameSearchTask = Task {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            do {
                let results = try await adminService.searchUsers(byDisplayName: trimmed)
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    nameSearchResults = results
                }
            } catch {
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    nameSearchResults = []
                }
            }
        }
    }

    private func addAdmin() async {
        guard let userId = UUID(uuidString: newAdminUserIdText.trimmingCharacters(in: .whitespaces)) else {
            await MainActor.run {
                addAdminError = "Invalid UUID"
            }
            return
        }
        await addAdminByUserId(userId)
    }

    private func addAdminByUserId(_ userId: UUID) async {
        addAdminInProgress = true
        addAdminError = nil
        defer { addAdminInProgress = false }

        do {
            try await adminService.addAdmin(userId: userId)
            await MainActor.run {
                newAdminUserIdText = ""
                nameSearchTerm = ""
                nameSearchResults = []
            }
            await loadAdmins()
        } catch {
            await MainActor.run {
                addAdminError = (error as NSError).localizedDescription
            }
        }
    }

    private func removeAdmin(_ userId: UUID) async {
        do {
            try await adminService.removeAdmin(userId: userId)
            await loadAdmins()
        } catch {
            await MainActor.run {
                adminsError = (error as NSError).localizedDescription
            }
        }
    }
}

#Preview {
    AdminView()
}

