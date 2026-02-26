// import Inject
import SwiftUI
import PhotosUI
internal import Auth
import Supabase

/// A single external resource (article, official page, fact-check) for learning about the Great Reset.
struct ResourceLink: Identifiable {
    let id = UUID()
    let title: String
    let urlString: String
    let summary: String?
    let type: ResourceType

    enum ResourceType: String, CaseIterable {
        case overview
        case official
        case factCheck
        case other
    }
}

private let resources: [ResourceLink] = [
    ResourceLink(
        title: "Wikipedia: The Great Reset",
        urlString: "https://en.wikipedia.org/wiki/Great_Reset",
        summary: "Overview of the WEF initiative and related discourse.",
        type: .overview
    ),
    ResourceLink(
        title: "World Economic Forum: The Great Reset",
        urlString: "https://www.weforum.org/great-reset/",
        summary: "Official WEF page on rebuilding sustainably after COVID-19.",
        type: .official
    ),
    ResourceLink(
        title: "Reuters Fact Check: The Great Reset",
        urlString: "https://www.reuters.com/article/factcheck-wef-reset-idUSL1N2ZS0WD/",
        summary: "Fact-checking fabricated WEF memos and Great Reset claims.",
        type: .factCheck
    ),
    ResourceLink(
        title: "UBS Global Wealth Report",
        urlString: "https://www.ubs.com/us/en/wealth-management/insights/global-wealth-report.html",
        summary: "Source for global total wealth and distribution data; app defaults (e.g. ~500T, bracket shares) are in this ballpark.",
        type: .other
    ),
    ResourceLink(
        title: "WTF Happened in 1971?",
        urlString: "https://wtfhappenedin1971.com/",
        summary: "Charts on wages, productivity, inequality, and inflation since the end of the gold standard.",
        type: .other
    )
]

struct SettingsView: View {
    // @ObserveInjection var inject

    @Environment(SupabaseSessionManager.self) private var supabaseSession
    @Environment(StreakStore.self) private var streakStore
    @Environment(AccountStore.self) private var accountStore
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var showingAdminSheet: Bool = false
    @State private var showingShareSheet: Bool = false
    @State private var isCreatingAccount: Bool = false
    @State private var authError: String?
    @State private var isAdmin: Bool = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var avatarUploadError: String?

    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case email
        case password
    }

    private var isLoggedIn: Bool {
        supabaseSession.isLoggedIn
    }


    var body: some View {
        NavigationStack {
            Form {
                if isLoggedIn {
                    streaksSection
                }
                accountSection
                resourcesSection
                appMetadataSection
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                if isAdmin {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Admin") {
                            showingAdminSheet = true
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showingAdminSheet) {
            AdminView()
        }
        .sheet(isPresented: $showingShareSheet) {
            if let url = URL(string: "\(AppConstants.appURLScheme)://") {
                ActivityView(
                    activityItems: ["Check out \(AppConstants.appName)", "\(url.absoluteString)"],
                    onComplete: { completed in
                        if completed { streakStore.recordShare() }
                    }
                )
            }
        }
        .task(id: supabaseSession.user?.id) {
            await refreshAdminStatus()
        }
        // .enableInjection()
    }

    private var streaksSection: some View {
        Section {
            HStack(alignment: .center, spacing: 12) {
                StreakRow(icon: "app.badge.fill", label: "Visit", value: streakStore.visitStreak)
                StreakRow(icon: "list.bullet.rectangle.fill", label: "Poll", value: streakStore.pollStreak)
                StreakRow(icon: "square.and.arrow.up.fill", label: "Share", value: streakStore.shareStreak)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .listRowInsets(EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8))
        } header: {
            HStack(spacing: 6) {
                Image(systemName: "flame.fill")
                    .foregroundStyle(.orange)
                Text("Streaks")
            }
        }
    }

    private var accountSection: some View {
        Section {
            if isLoggedIn {
                HStack(alignment: .center, spacing: 12) {
                    PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                        AvatarView(
                            avatarLabel: accountStore.avatarInitials,
                            avatarImageURL: accountStore.avatarUrl
                        )
                    }
                    .buttonStyle(.plain)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(accountStore.effectiveDisplayName)
                            .font(.body.bold())
                        Text(supabaseSession.user?.email ?? "Signed in")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                }
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                .onChange(of: selectedPhotoItem) { _, newItem in
                    guard let item = newItem else { return }
                    Task { await handlePhotoSelected(item) }
                }
                if let avatarUploadError {
                    Text(avatarUploadError)
                        .font(.body)
                        .foregroundStyle(.red)
                }

                Button("Sign Out") {
                    accountStore.clearForSignOut()
                    streakStore.clearForSignOut()
                    Task {
                        await supabaseSession.logout()
                        email = ""
                        password = ""
                        focusedField = .email
                    }
                }
                .foregroundStyle(.red)
            } else {
                TextField("Email", text: $email)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .textContentType(.emailAddress)
                    .submitLabel(.next)
                    .focused($focusedField, equals: .email)

                SecureField("Password", text: $password)
                    .textContentType(.password)
                    .submitLabel(.go)
                    .focused($focusedField, equals: .password)

                if let authError {
                    Text(authError)
                        .font(.body)
                        .foregroundStyle(.red)
                }

                Button(isCreatingAccount ? "Create Account" : "Sign In") {
                    Task {
                        await handleAuthAction()
                    }
                }
                .disabled(email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || password.isEmpty)

                Button(isCreatingAccount ? "Already have an account? Sign In" : "Need an account? Create one") {
                    isCreatingAccount.toggle()
                    authError = nil
                }
                .font(.footnote)
                .padding(.top, 4)
            }
        } header: {
            Text("Account")
        } footer: {
            if isLoggedIn {
                Text("Your username is derived from your sign-up email. Admin polls use the generic Great Reset Fantasy branding.")
            }
        }
    }

    private var resourcesSection: some View {
        Section {
            ForEach(resources) { resource in
                if let url = URL(string: resource.urlString) {
                    Link(destination: url) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(resource.title)
                                .font(.subheadline.bold())
                                .foregroundStyle(.primary.opacity(0.8))
                            if let summary = resource.summary {
                                Text(summary)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        } header: {
            Text("Resources")
        } footer: {
            Text("Great Reset links explain the WEF initiative and fact-checks. The UBS report is the kind of source for the simulator’s global constants (total wealth, bracket shares). Defaults are illustrative; admins can change them in Admin.")
        }
    }

    private var appMetadataSection: some View {
        Section {
            Button {
                showingShareSheet = true
            } label: {
                HStack {
                    Text("Share App")
                    Spacer()
                    Image(systemName: "square.and.arrow.up")
                        .font(.title3.weight(.semibold))
                }
            }
            HStack {
                Text("Version")
                Spacer()
                Text(appVersionWithBuild)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("App")
        }
    }

    private var appVersionWithBuild: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String
        guard let build else { return version }
        return "\(version) (\(build))"
    }

    @MainActor
    private func handleAuthAction() async {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !password.isEmpty else { return }

        do {
            if isCreatingAccount {
                try await supabaseSession.register(email: trimmed, password: password)
            } else {
                try await supabaseSession.login(email: trimmed, password: password)
            }

            email = ""
            password = ""
            authError = nil
            isCreatingAccount = false
        } catch {
            authError = (error as NSError).localizedDescription
        }
    }

    @MainActor
    private func handlePhotoSelected(_ item: PhotosPickerItem) async {
        avatarUploadError = nil
        selectedPhotoItem = nil

        guard let data = try? await item.loadTransferable(type: Data.self), !data.isEmpty else {
            avatarUploadError = "Could not load image"
            return
        }

        do {
            try await accountStore.uploadAvatar(data)
        } catch {
            avatarUploadError = (error as NSError).localizedDescription
        }
    }

    private func refreshAdminStatus() async {
        guard let userId = supabaseSession.user?.id else {
            await MainActor.run {
                isAdmin = false
            }
            return
        }

        do {
            let rows: [AdminUserRow] = try await supabaseSession.client
                .from("admin_users")
                .select()
                .eq("user_id", value: userId)
                .limit(1)
                .execute()
                .value

            await MainActor.run {
                isAdmin = !rows.isEmpty
            }
        } catch {
            await MainActor.run {
                isAdmin = false
            }
        }
    }
}

// MARK: - Streak Row

private struct StreakRow: View {
    let icon: String
    let label: String
    let value: Int

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.orange)
                .frame(width: 36, height: 36)
                .background(Color.orange.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            Text("\(value)")
                .font(.title.bold())
                .foregroundStyle(.orange)
                .contentTransition(.numericText())
                .animation(.spring(response: 0.4, dampingFraction: 0.75), value: value)

            Text(label)
                .font(.body)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
    }
}

//#Preview {
//    SettingsView()
//        .environment(SupabaseSession())
//}
