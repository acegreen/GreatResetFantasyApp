import SwiftUI
// import Inject
import UIKit
internal import Auth

struct PollsView: View {
    // @ObserveInjection var inject
    
    @Environment(SupabaseSessionManager.self) private var supabaseSession
    @Environment(StreakStore.self) private var streakStore

    @State private var pollRows: [PollWithOptions] = []
    @State private var myVotes: [Vote] = []
    @State private var loading = false
    @State private var errorMessage: String?
    @State private var showSignInToVoteAlert = false

    private var pollService: PollService { PollService(client: supabaseSession.client) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    if let errorMessage {
                        Text(errorMessage)
                            .font(.body)
                            .foregroundStyle(.red)
                            .padding()
                    }

                    if loading && pollRows.isEmpty {
                        ProgressView("Loading polls…")
                    } else if pollRows.isEmpty {
                        Text("No polls yet.")
                            .font(.body)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(pollRows) { row in
                            pollSection(row: row)
                        }
                        explainSection
                    }
                }
                .padding()
            }
            .navigationTitle("Polls")
            .navigationBarTitleDisplayMode(.large)
        }
        .alert("Sign in to vote", isPresented: $showSignInToVoteAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Sign in or create an account to vote on polls.")
        }
        .task { await loadPolls() }
        .refreshable { await loadPolls() }
        // .enableInjection()
    }
    
    // MARK: - Sections
    
    private func pollSectionContent(row: PollWithOptions, includeShareButton: Bool = true) -> some View {
        let total = totalVotes(for: row)
        let userVote = myVotes.first { $0.pollId == row.id }
        return VStack(alignment: .leading, spacing: 12) {
            AccountBannerView(
                displayName: AppConstants.appName,
                avatarLabel: AppConstants.adminAvatarLabel,
                createdAt: row.createdAt,
                trailing: {
                    Group {
                        if includeShareButton,
                           let uiImage = pollShareImage(for: row) {
                            let sharedImage = SharedImage(image: uiImage)
                            ShareLink(
                                item: sharedImage,
                                preview: SharePreview(
                                    AppConstants.sharePreviewTitle,
                                    image: Image(uiImage: sharedImage.image)
                                )
                            ) {
                                Image(systemName: "square.and.arrow.up")
                                    .font(.title3.weight(.semibold))
                            }
                            .simultaneousGesture(TapGesture().onEnded { streakStore.recordShare() })
                            .accessibilityLabel("Share this poll")
                        }
                    }
                }
            )
            
            Text(row.question)
                .font(.headline)
            
            VStack(spacing: 8) {
                ForEach(row.options) { option in
                    pollOptionRow(
                        row: row,
                        option: option,
                        totalVotes: total,
                        color: .blue,
                        userVoteOptionId: userVote?.optionId
                    )
                }
            }
            
            Text(totalVotesText(total: total))
                .font(.body)
                .foregroundStyle(.secondary)
        }
    }
    
    private func pollSection(row: PollWithOptions) -> some View {
        CardView {
            pollSectionContent(row: row, includeShareButton: true)
        }
    }
    
    private var explainSection: some View {
        ExplanationSection(
            title: "How to Use This",
            body: "Use this view to capture how people feel about a possible reset. Let users cast a quick vote, then use the trend bars to see how different groups are voting and why expectations vary."
        )
    }
    
    // MARK: - Logic
    
    private func loadPolls() async {
        loading = true
        errorMessage = nil
        defer { loading = false }
        
        do {
            // Global polls (no owner filter), votes are per‑user
            pollRows = try await pollService.fetchPolls()
            
            // Only fetch per-user votes when logged in; otherwise show generic polls
            if let user = supabaseSession.user {
                myVotes = try await pollService.fetchMyVotes(userId: user.id)
                streakStore.syncPollStreakFromVoteCount(myVotes.count)
            } else {
                myVotes = []
            }
        } catch {
            
            // Don’t show harmless cancellation errors
            guard !isCancellationError(error) else { return }
            errorMessage = (error as NSError).localizedDescription
        }
    }
    
    private func isCancellationError(_ error: Error) -> Bool {
        error.localizedDescription.lowercased().contains("cancelled")
    }

    private func totalVotes(for row: PollWithOptions) -> Int {
        max(row.options.reduce(0) { $0 + $1.votesCount }, 0)
    }
    
    private func totalVotesText(total: Int) -> String {
        total == 1 ? "1 vote" : "\(total) votes"
    }
    
    private func registerVote(row: PollWithOptions, option: PollOption) {
        guard supabaseSession.isLoggedIn, let user = supabaseSession.user else {
            showSignInToVoteAlert = true
            return
        }
        let alreadyVoted = myVotes.contains { $0.pollId == row.id }
        guard !alreadyVoted else { return }

        Task {
            do {
                try await pollService.castVote(userId: user.id, pollId: row.id, optionId: option.id)
                await loadPolls()
            } catch {
                guard !isCancellationError(error) else { return }
                errorMessage = (error as NSError).localizedDescription
            }
        }
    }

    private func sharePercentage(for count: Int, total: Int) -> Int {
        guard total > 0 else { return 0 }
        return Int((Double(count) / Double(total) * 100).rounded())
    }
    
    private func pollShareImage(for row: PollWithOptions) -> UIImage? {
        let card = CardView {
            pollSectionContent(row: row, includeShareButton: false)
        }
        .padding()
        .background(Color(.systemBackground))
        
        let renderer = ImageRenderer(content: card)
        renderer.scale = UIScreen.main.scale
        return renderer.uiImage
    }
    
    // MARK: - Poll option row
    
    private func pollOptionRow(
        row: PollWithOptions,
        option: PollOption,
        totalVotes: Int,
        color: Color,
        userVoteOptionId: UUID?
    ) -> some View {
        let count = option.votesCount
        let share = totalVotes > 0 ? Double(count) / Double(totalVotes) : 0
        let percentageText = totalVotes > 0 ? "\(sharePercentage(for: count, total: totalVotes))%" : "Vote"
        let alreadyVoted = userVoteOptionId != nil
        let isMyVote = userVoteOptionId == option.id
        
        return Button {
            registerVote(row: row, option: option)
        } label: {
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.secondary.opacity(0.15))
                    
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(color.gradient)
                        .frame(width: proxy.size.width * share)
                    
                    HStack {
                        Text(option.text)
                            .font(.subheadline)
                            .fontWeight(isMyVote ? .bold : .regular)
                            .foregroundStyle(.primary)
                        Spacer()
                        Text(percentageText)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                    }
                    .padding(.horizontal, 12)
                }
            }
            .frame(height: 44)
        }
        .buttonStyle(.plain)
        .disabled(alreadyVoted)
    }
}

//#Preview {
//    PollsView()
//        .environment(SupabaseSession())
//}
