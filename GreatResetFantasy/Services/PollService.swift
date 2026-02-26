//
//  PollService.swift
//  GreatResetFantasy
//

import Foundation
import Supabase

struct PollService {
    let client: SupabaseClient

    /// Fetch all polls for the current user (owner), with their options.
    func fetchPolls() async throws -> [PollWithOptions] {
        let polls: [Poll] = try await client
            .from("polls")
            .select()
            .order("created_at", ascending: false)
            .execute()
            .value

        guard !polls.isEmpty else { return [] }

        let pollIds = polls.map(\.id)
        let options: [PollOption] = try await client
            .from("poll_options")
            .select()
            .in("poll_id", values: pollIds)
            .execute()
            .value

        return polls.map { poll in
            PollWithOptions(
                poll: poll,
                options: options.filter { $0.pollId == poll.id }
            )
        }
    }

    /// Create a new poll with options. Returns the created poll (with id).
    func createPoll(question: String, optionTexts: [String], ownerId: UUID) async throws -> Poll {
        let pollInsert = PollInsert(question: question, ownerId: ownerId)
        let poll: Poll = try await client
            .from("polls")
            .insert(pollInsert)
            .select()
            .single()
            .execute()
            .value

        let optionInserts = optionTexts.map { PollOptionInsert(pollId: poll.id, text: $0) }
        _ = try await client
            .from("poll_options")
            .insert(optionInserts)
            .execute()

        return poll
    }

    /// Fetch options for a single poll (e.g. after creating or to refresh counts).
    func fetchOptions(pollId: UUID) async throws -> [PollOption] {
        try await client
            .from("poll_options")
            .select()
            .eq("poll_id", value: pollId)
            .execute()
            .value
    }

    /// Fetch current user's votes (e.g. for "you voted for" and duplicate check).
    func fetchMyVotes(userId: UUID) async throws -> [Vote] {
        try await client
            .from("votes")
            .select()
            .eq("user_id", value: userId)
            .execute()
            .value
    }

    /// Cast a vote. DB trigger increments the option's votes_count. Fails if user already voted in this poll (unique constraint).
    func castVote(userId: UUID, pollId: UUID, optionId: UUID) async throws {
        let insert = VoteInsert(userId: userId, pollId: pollId, optionId: optionId)
        try await client
            .from("votes")
            .insert(insert)
            .execute()
    }
}
