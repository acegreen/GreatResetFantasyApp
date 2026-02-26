//
//  AccountBannerView.swift
//  GreatResetFantasy
//

import SwiftUI

/// Reusable avatar view (image or initials). Use in banners and pickers.
struct AvatarView: View {
    let avatarLabel: String
    var avatarImageURL: String?

    var body: some View {
        Group {
            if let urlString = avatarImageURL, let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    case .failure, .empty:
                        initialsView
                    @unknown default:
                        initialsView
                    }
                }
                .id(urlString)
            } else {
                initialsView
            }
        }
        .frame(width: 72, height: 72)
        .clipShape(Circle())
    }

    private var initialsView: some View {
        Circle()
            .fill(Color.blue)
            .overlay(
                Text(avatarLabel)
                    .font(.title3.bold())
                    .foregroundStyle(.white)
            )
    }
}

/// Displays avatar + username for a poll author (admin uses GR + Great Reset Fantasy).
struct AccountBannerView<Trailing: View>: View {
    let displayName: String
    let avatarLabel: String
    var avatarImageURL: String?
    var createdAt: Date?
    @ViewBuilder var trailing: () -> Trailing

    init(
        displayName: String,
        avatarLabel: String,
        avatarImageURL: String? = nil,
        createdAt: Date? = nil,
        @ViewBuilder trailing: @escaping () -> Trailing
    ) {
        self.displayName = displayName
        self.avatarLabel = avatarLabel
        self.avatarImageURL = avatarImageURL
        self.createdAt = createdAt
        self.trailing = trailing
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            avatarView

            VStack(alignment: .leading, spacing: 4) {
                Text(displayName)
                    .font(.body.bold())
                if let createdAt {
                    Text(createdAt, style: .date)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 8)

            trailing()
        }
    }

    private var avatarView: some View {
        AvatarView(avatarLabel: avatarLabel, avatarImageURL: avatarImageURL)
    }
}

// MARK: - Convenience init without trailing
extension AccountBannerView where Trailing == EmptyView {
    init(displayName: String, avatarLabel: String, avatarImageURL: String? = nil, createdAt: Date? = nil) {
        self.displayName = displayName
        self.avatarLabel = avatarLabel
        self.avatarImageURL = avatarImageURL
        self.createdAt = createdAt
        self.trailing = { EmptyView() }
    }
}
