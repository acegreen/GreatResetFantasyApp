//
//  SupabaseModels.swift
//  GreatResetFantasy
//

import Foundation

// MARK: - Poll & options

struct PollOption: Codable, Identifiable, Sendable {
    let id: UUID
    var pollId: UUID?
    var text: String
    var votesCount: Int

    enum CodingKeys: String, CodingKey {
        case id
        case pollId = "poll_id"
        case text
        case votesCount = "votes_count"
    }
}

struct Poll: Codable, Identifiable, Sendable {
    let id: UUID
    var question: String
    var createdAt: Date
    var ownerId: UUID

    enum CodingKeys: String, CodingKey {
        case id
        case question
        case createdAt = "created_at"
        case ownerId = "owner_id"
    }
}

/// Poll with options embedded (from join or separate fetch)
struct PollWithOptions: Identifiable, Sendable {
    let poll: Poll
    var options: [PollOption]

    var id: UUID { poll.id }
    var question: String { poll.question }
    var createdAt: Date { poll.createdAt }
    var ownerId: UUID { poll.ownerId }
}

// MARK: - Vote

struct Vote: Codable, Identifiable, Sendable {
    let id: UUID
    var userId: UUID
    var pollId: UUID
    var optionId: UUID
    var createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case pollId = "poll_id"
        case optionId = "option_id"
        case createdAt = "created_at"
    }
}

// MARK: - Insert payloads

struct PollInsert: Encodable {
    var question: String
    var ownerId: UUID

    enum CodingKeys: String, CodingKey {
        case question
        case ownerId = "owner_id"
    }
}

struct PollOptionInsert: Encodable {
    var pollId: UUID
    var text: String

    enum CodingKeys: String, CodingKey {
        case pollId = "poll_id"
        case text
    }
}

struct VoteInsert: Encodable {
    var userId: UUID
    var pollId: UUID
    var optionId: UUID

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case pollId = "poll_id"
        case optionId = "option_id"
    }
}

// MARK: - Admin users

struct AdminUserRow: Codable, Identifiable, Sendable {
    var userId: UUID

    var id: UUID { userId }

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
    }
}

struct AdminUserInsert: Encodable {
    var userId: UUID

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
    }
}

// MARK: - Calculator config (Supabase-backed)

struct CalculatorGlobalsRow: Codable, Sendable {
    var id: Int
    var totalWealth: Double
    var worldPopulation: Double
    var povertyLinePerPerson: Double
    var updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case totalWealth = "total_wealth"
        case worldPopulation = "world_population"
        case povertyLinePerPerson = "poverty_line_per_person"
        case updatedAt = "updated_at"
    }
}

struct WealthBracketRow: Codable, Identifiable, Sendable {
    var id: UUID
    var bracket: String
    var wealthShare: Double
    var populationShare: Double
    var vulnerability: Double
    var sortOrder: Int

    enum CodingKeys: String, CodingKey {
        case id
        case bracket
        case wealthShare = "wealth_share"
        case populationShare = "population_share"
        case vulnerability
        case sortOrder = "sort_order"
    }
}

struct ResetScenarioRow: Codable, Identifiable, Sendable {
    var id: UUID
    var label: String
    var zerosCut: Int
    var sortOrder: Int

    enum CodingKeys: String, CodingKey {
        case id
        case label
        case zerosCut = "zeros_cut"
        case sortOrder = "sort_order"
    }
}

struct CalculatorGlobalsUpdate: Encodable {
    var totalWealth: Double
    var worldPopulation: Double
    var povertyLinePerPerson: Double
    var updatedAt: String

    enum CodingKeys: String, CodingKey {
        case totalWealth = "total_wealth"
        case worldPopulation = "world_population"
        case povertyLinePerPerson = "poverty_line_per_person"
        case updatedAt = "updated_at"
    }
}

struct WealthBracketUpdate: Encodable {
    var wealthShare: Double
    var populationShare: Double
    var vulnerability: Double

    enum CodingKeys: String, CodingKey {
        case wealthShare = "wealth_share"
        case populationShare = "population_share"
        case vulnerability
    }
}

struct ResetScenarioUpdate: Encodable {
    var label: String
    var zerosCut: Int

    enum CodingKeys: String, CodingKey {
        case label
        case zerosCut = "zeros_cut"
    }
}

struct ResetScenarioInsert: Encodable {
    var label: String
    var zerosCut: Int
    var sortOrder: Int

    enum CodingKeys: String, CodingKey {
        case label
        case zerosCut = "zeros_cut"
        case sortOrder = "sort_order"
    }
}

// MARK: - User accounts (display name, avatar, streaks — all account data in one table)

struct UserAccountRow: Codable, Sendable {
    var userId: UUID
    var displayName: String?
    var avatarLabel: String?
    var avatarUrl: String?
    var visitStreak: Int
    var pollStreak: Int
    var shareStreak: Int
    var lastVisitDate: Date?
    var lastPollDate: Date?
    var lastShareDate: Date?
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case displayName = "display_name"
        case avatarLabel = "avatar_label"
        case avatarUrl = "avatar_url"
        case visitStreak = "visit_streak"
        case pollStreak = "poll_streak"
        case shareStreak = "share_streak"
        case lastVisitDate = "last_visit_date"
        case lastPollDate = "last_poll_date"
        case lastShareDate = "last_share_date"
        case updatedAt = "updated_at"
    }
}

struct UserAccountStreaksUpsert: Encodable {
    var userId: UUID
    var visitStreak: Int
    var pollStreak: Int
    var shareStreak: Int
    var lastVisitDate: Date?
    var lastPollDate: Date?
    var lastShareDate: Date?
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case visitStreak = "visit_streak"
        case pollStreak = "poll_streak"
        case shareStreak = "share_streak"
        case lastVisitDate = "last_visit_date"
        case lastPollDate = "last_poll_date"
        case lastShareDate = "last_share_date"
        case updatedAt = "updated_at"
    }
}

struct UserAccountUpsert: Encodable {
    var userId: UUID
    var displayName: String?
    var avatarLabel: String?
    var avatarUrl: String?
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case displayName = "display_name"
        case avatarLabel = "avatar_label"
        case avatarUrl = "avatar_url"
        case updatedAt = "updated_at"
    }
}
